-- PB's Proc Set Timer
-- Author: PinkBanther
--
-- For every set you wear whose bonus text names a time -- "for 5 seconds", "once every 8
-- seconds" -- shows
--
--     * the moment the proc fires,
--     * that it is active, and for how long,
--     * the cooldown, counting down.
--
-- ---------------------------------------------------------------------------------------
-- WHAT IS NOT IN THIS ADD-ON
-- ---------------------------------------------------------------------------------------
--
-- The sets and their effects. Add-ons of this kind keep a table of set ids, ability ids,
-- durations and cooldowns, and need an update whenever a patch touches a set or a new one is
-- released. This one keeps nothing about any set: it looks at what you wear and reads the rest
-- from the game:
--
--     which sets, and how many pieces   GetItemLinkSetInfo on the worn items
--     durations, cooldown, delay        the set's own bonus text      (Parse.lua)
--     which events are the proc         ability names, see below
--     how long a debuff really has      endTime of EVENT_EFFECT_CHANGED
--
-- A set gets a row when one of its bonus lines has a cooldown or a duration in its text and
-- the worn pieces switch that line on. Of several such lines, the highest one that is on.
--
-- ---------------------------------------------------------------------------------------
-- HOW A PROC IS RECOGNISED
-- ---------------------------------------------------------------------------------------
--
-- Two events carry a proc, and which one depends on what the proc does:
--
--     EVENT_EFFECT_CHANGED   a buff or debuff appeared (a damage debuff, a self buff);
--                            beginTime/endTime are exact, and an effect that began just now
--                            is a new proc while one that began earlier is only the reticle
--                            moving to an enemy that already has it.
--     EVENT_COMBAT_EVENT     a hit (glass shards bursting). The client no longer reports effect
--                            gain/fade through it, so a pure buff never shows up here.
--
-- An event belongs to a worn set by its ability NAME (as the client localised it), in two tiers:
--
--     1. the name is the set's name, part of it, or contains it;
--     2. for an effect only: the name appears word for word in the proc bonus' text AND the
--        effect lasts as long as that text says. The second condition is what keeps a
--        standard buff named in many bonus texts ("Major Brutality") from being taken for a
--        proc every time one of your own skills applies it.
--
-- Names are only a heuristic and have not been measured on a console: /procset status lists
-- what was matched, /procset probe lists everything else, /procset bind pins an ability id to
-- a set by hand and /procset ignore removes one that was matched wrongly.
--
-- The cooldown starts when the proc fires and ignores further events until it is over, so a
-- burst that hits five enemies at once counts once.
--
-- Only while a set with a row is worn are the two events listened to at all.

if PBS_PROCSETTIMER then
	return
end

local addon = {
	name = "PBsProcSetTimer",
	title = "PB’s Proc Set Timer",
	author = "PinkBanther",
	version = "0.2.1", -- keep in step with ## Version in the manifest
}
PBS_PROCSETTIMER = addon

local em = EVENT_MANAGER
local wm = WINDOW_MANAGER

local MAX_ROWS = 8 -- more sets than this with a timer is beyond what is worn at once
local PREVIEW_ROWS = 3
local FRESH_SECONDS = 0.75 -- an effect that began this recently is a new proc
local MERGE_SECONDS = 0.25 -- one proc can report several events; they count once
local FLASH_SECONDS = 0.35
local MAX_DELAY_SECONDS = 5 -- a "delay" in the text longer than this is not a proc delay
local DURATION_TOLERANCE = 0.6 -- how far an effect's length may stray from the text's seconds
local MIN_NAME_BYTES = 6 -- shorter ability names are never matched on their own
local RESCAN_MS = 2000
-- A bar swap makes the game count the worn pieces again. A row whose bonus reads as off for
-- less than this stays (the reading may be a dip, not the bonus going away); an effect or a
-- cooldown that is still running keeps its row for as long as it runs, whatever the count says.
local GRACE_SECONDS = 2
local LOG_MAX = 40

-- Sizes of the gamepad fonts the client defines (ZoFontGamepad<size>).
addon.FONT_SIZES = { 18, 20, 22, 25, 27, 34, 42 }

-- Everything about where things are and how big they are lives here, so the settings panel
-- can offer all of it. Offsets of the three elements are from the left edge of their row and
-- from its vertical middle.
addon.DEFAULTS = {
	enabled = true,
	combatOnly = false,
	onlyDetected = false, -- rows only for sets whose proc has been seen this session
	soundReady = false,

	posX = -905, -- the block's top-left corner, from the screen centre
	posY = 100,
	scale = 100,
	rowHeight = 36,

	nameShow = true,
	nameX = 0,
	nameY = 0,
	nameWidth = 270,
	nameFont = 22,

	barShow = true,
	barX = 278,
	barY = 0,
	barWidth = 140,
	barHeight = 14,

	textShow = true,
	textX = 426,
	textY = 0,
	textWidth = 220,
	textFont = 22,

	bind = {}, -- [abilityId] = setId, pinned by hand with /procset bind
	ignore = {}, -- [abilityId] = true, never matched
	hidden = {}, -- [setId] = true, no row for this set
}

-- Direct hits. Damage-over-time and heal-over-time ticks are left out on purpose: a ticking
-- effect would look like a new proc every time its cooldown ran out.
local HIT_RESULTS = {}
for _, suffix in ipairs({
	"DAMAGE",
	"CRITICAL_DAMAGE",
	"PRECISE_DAMAGE",
	"WRECKING_DAMAGE",
	"BLOCKED_DAMAGE",
	"DAMAGE_SHIELDED",
	"HEAL",
	"CRITICAL_HEAL",
	"POWER_ENERGIZE",
}) do
	local value = _G["ACTION_RESULT_" .. suffix]
	if value then
		HIT_RESULTS[value] = true
	end
end

-- ---- state --------------------------------------------------------------------------
local recs = {} -- every set seen worn this session, in the order first seen
local recById = {}
local activeRecs = {} -- the recs with a bonus line on right now (and not hidden)
-- [abilityId] = rec | false, one table per kind of event; cleared whenever the sets change
local verdictEffect = {}
local verdictHit = {}

local state = {
	hudShown = false,
	inCombat = false,
	listening = false,
	probe = false,
	probeSeen = {},
	log = {}, -- the last LOG_MAX lines of what changed in the worn sets, for /procset log
}
addon.preview = false

local rows = {}
local ui = { shown = 0 }
local Relayout -- defined with the UI

local function Now()
	return GetFrameTimeSeconds()
end

local function Log(text, ...)
	local log = state.log
	log[#log + 1] = string.format("%.1f ", Now()) .. string.format(text, ...)
	if #log > LOG_MAX then
		table.remove(log, 1)
	end
end

local function NewRec(setId)
	return {
		setId = setId,
		name = nil, -- the game's own name for the set
		count = 0, -- worn pieces, Perfected ones included
		perfected = 0,
		info = nil, -- addon.ReadSetEffect result; false if the game has no such set
		bonus = nil, -- the bonus line this row follows, nil when there is no row
		live = false, -- the worn pieces switch that line on right now
		offSince = nil, -- since when the reading has said it is off
		cdUntil = 0,
		cdTotal = 0,
		wasOnCd = false,
		actEnd = 0, -- latest end of the effect on any unit
		actTotal = 0,
		units = {}, -- [unitId] = endTime of the effect on that unit
		flashUntil = 0,
		lastProc = -1000,
		procs = 0,
		foreign = 0, -- name matched but the effect was not ours
		seen = {}, -- [abilityId] = { name, kind, n } the events matched so far
	}
end

-- The game's own name for the set, in the player's language. Looked up on demand so a set
-- that is not worn is still labelled correctly.
local function SetDisplayName(rec)
	if not rec.name or rec.name == "" then
		local name = GetItemSetName(rec.setId)
		if name and name ~= "" then
			rec.name = name
		end
	end
	return rec.name or ("#" .. rec.setId)
end

local function ResetTimers(rec)
	rec.cdUntil = 0
	rec.cdTotal = 0
	rec.wasOnCd = false
	rec.actEnd = 0
	rec.actTotal = 0
	rec.units = {}
	rec.flashUntil = 0
	-- a new bonus line, a zone change: what fired before says nothing about the next proc
	rec.lastProc = -1000
end

local function ClearVerdicts()
	verdictEffect = {}
	verdictHit = {}
end

-- ---- matching events to sets --------------------------------------------------------
-- Tier 1: the name and the set's name are the same thing, or one holds the other.
local function NameOfSet(rec, name)
	local setName = rec.name
	-- an empty set name would be "contained" in every ability name
	return setName ~= nil
		and setName ~= ""
		and (name == setName or setName:find(name, 1, true) ~= nil or name:find(setName, 1, true) ~= nil)
end

-- Tier 2: the name is written in the bonus text, and the effect lasts as long as the text says.
local function NameInText(rec, name, length)
	local bonus = rec.bonus
	if not length or not bonus.duration or math.abs(length - bonus.duration) > DURATION_TOLERANCE then
		return false
	end
	return bonus.text:find(name, 1, true) ~= nil
end

-- The set an ability belongs to, or nil. Decided once per ability id and kind of event: this
-- runs for every combat event of the player, so the answer is cached until the worn sets
-- change. `length` is the effect's length in seconds, nil for a hit.
local function Match(cache, abilityId, name, length)
	local cached = cache[abilityId]
	if cached ~= nil then
		return cached or nil
	end

	local sv = addon.sv
	local hit = false
	local pinned = sv.bind[abilityId]
	if sv.ignore[abilityId] then
		hit = false
	elseif pinned then
		local rec = recById[pinned]
		hit = (rec and rec.bonus) and rec or false
	elseif name and #name >= MIN_NAME_BYTES then
		for _, rec in ipairs(activeRecs) do
			if NameOfSet(rec, name) then
				hit = rec
				break
			end
		end
		if not hit and length then
			for _, rec in ipairs(activeRecs) do
				if NameInText(rec, name, length) then
					hit = rec
					break
				end
			end
		end
	end
	cache[abilityId] = hit
	return hit or nil
end

local function Seen(rec, abilityId, name, kind)
	local entry = rec.seen[abilityId]
	if not entry then
		entry = { name = name, kind = kind, n = 0 }
		rec.seen[abilityId] = entry
		-- a row that was waiting for its first proc appears now
		if addon.sv.onlyDetected then
			Relayout()
		end
	end
	entry.n = entry.n + 1
end

local function Probe(kind, abilityId, name, detail)
	if not state.probe or state.probeSeen[abilityId] then
		return
	end
	state.probeSeen[abilityId] = true
	d(string.format("[ProcSet probe] %s %d %s %s", kind, abilityId or 0, name or "?", detail or ""))
end

-- ---- the timers ---------------------------------------------------------------------
-- Starts a proc at time t. False if it is still inside the cooldown of an earlier one, or the
-- same proc reporting again.
local function StartProc(rec, t, quiet)
	local bonus = rec.bonus
	if t < rec.cdUntil - 0.05 or t - rec.lastProc < MERGE_SECONDS then
		return false
	end
	rec.procs = rec.procs + 1
	rec.lastProc = t
	if bonus.cooldown then
		rec.cdUntil = t + bonus.cooldown
		rec.cdTotal = bonus.cooldown
	end
	if not quiet then
		rec.flashUntil = t + FLASH_SECONDS
	end
	return true
end

local function RecomputeActive(rec, now)
	local latest = 0
	for unitId, finish in pairs(rec.units) do
		if finish <= now then
			rec.units[unitId] = nil
		elseif finish > latest then
			latest = finish
		end
	end
	rec.actEnd = latest
end

local function OnEffectChanged(
	_,
	changeType,
	_,
	effectName,
	_,
	beginTime,
	endTime,
	_,
	_,
	_,
	_,
	_,
	_,
	_,
	unitId,
	abilityId,
	sourceType
)
	local now = Now()
	unitId = unitId or 0

	if changeType == EFFECT_RESULT_FADED then
		-- a fade carries the clock of the original effect, which says nothing about whether
		-- it was ours; only an effect already known to be a proc is followed
		local rec = verdictEffect[abilityId]
		if rec then
			rec.units[unitId] = nil
			RecomputeActive(rec, now)
		end
		return
	end

	local length = (beginTime > 0 and endTime > beginTime) and (endTime - beginTime) or nil
	local rec = Match(verdictEffect, abilityId, effectName, length)
	if not rec then
		if state.probe and sourceType == COMBAT_UNIT_TYPE_PLAYER then
			Probe("effect", abilityId, effectName, string.format("begin %.1f end %.1f", beginTime or 0, endTime or 0))
		end
		return
	end
	if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then
		rec.foreign = rec.foreign + 1
		return
	end
	Seen(rec, abilityId, effectName, "effect")

	local bonus = rec.bonus
	local fresh = beginTime <= 0 or now - beginTime <= FRESH_SECONDS
	local startedAt = beginTime > 0 and beginTime or now
	local finish = endTime > now and endTime or nil
	if not finish and fresh and bonus.duration then
		finish = now + bonus.duration
	end

	local wasActive = rec.actEnd > now
	if finish then
		rec.units[unitId] = finish
		rec.actTotal = finish - startedAt
		if finish > rec.actEnd then
			rec.actEnd = finish
		end
	end
	if fresh then
		-- an effect that refreshes with no cooldown (a debuff kept up by light attacks)
		-- flashes only when it first appears
		StartProc(rec, startedAt, not bonus.cooldown and wasActive)
	end
end

local function OnCombatEvent(_, result, isError, abilityName, _, slotType, _, _, _, _, _, _, _, _, _, _, abilityId)
	if isError or not HIT_RESULTS[result] then
		return
	end
	-- the text names Light Attacks; they must not be taken for the proc
	if slotType == ACTION_SLOT_TYPE_LIGHT_ATTACK or slotType == ACTION_SLOT_TYPE_HEAVY_ATTACK then
		return
	end
	local rec = Match(verdictHit, abilityId, abilityName, nil)
	if not rec then
		Probe("hit", abilityId, abilityName, "result " .. tostring(result))
		return
	end
	Seen(rec, abilityId, abilityName, "hit")

	-- The hit lands after the delay the text names (glass shards burst 1.3 s after the
	-- critical), while the cooldown began at the critical.
	local bonus = rec.bonus
	local shift = (bonus.delay and bonus.delay <= MAX_DELAY_SECONDS) and bonus.delay or 0
	StartProc(rec, Now() - shift)
end

local function RefreshEvents()
	local want = #activeRecs > 0 or state.probe
	if want == state.listening then
		return
	end
	state.listening = want
	local effectNs, hitNs = addon.name .. "Effect", addon.name .. "Hit"
	if want then
		em:RegisterForEvent(effectNs, EVENT_EFFECT_CHANGED, OnEffectChanged)
		em:RegisterForEvent(hitNs, EVENT_COMBAT_EVENT, OnCombatEvent)
		em:AddFilterForEvent(hitNs, EVENT_COMBAT_EVENT, REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE, COMBAT_UNIT_TYPE_PLAYER)
	else
		em:UnregisterForEvent(effectNs, EVENT_EFFECT_CHANGED)
		em:UnregisterForEvent(hitNs, EVENT_COMBAT_EVENT)
	end
end

-- ---- worn sets ----------------------------------------------------------------------
-- The bonus line a row follows: the highest one that has a time in its text and that the worn
-- pieces switch on. A Perfected bonus counts Perfected pieces only, as the item tooltip does.
local function SelectBonus(rec)
	local bonuses = rec.info and rec.info.bonuses
	if not bonuses then
		return nil
	end
	for index = #bonuses, 1, -1 do
		local bonus = bonuses[index]
		local relevant = bonus.perfected and rec.perfected or rec.count
		if bonus.timed and relevant >= bonus.required then
			return bonus
		end
	end
	return nil
end

-- Whether a row still has something to show: its bonus is on, or the reading that says it is off
-- is younger than GRACE_SECONDS, or an effect or a cooldown it started is still running (an
-- effect already on an enemy outlives the bar swap that switched the bonus off).
local function Showing(rec, now)
	if rec.live or (rec.offSince and now < rec.offSince + GRACE_SECONDS) then
		return true
	end
	return rec.cdUntil > now or rec.actEnd > now
end

-- Reads every worn piece with the call the item tooltip uses (numNormalEquipped already leaves
-- out the weapon bar that is not in hand) and works out which sets have a row.
local function Rescan()
	local sv = addon.sv
	local now = Now()
	local found = {}
	local order = {}
	for slot = 0, GetBagSize(BAG_WORN) - 1 do
		local link = GetItemLink(BAG_WORN, slot)
		if link ~= "" then
			local hasSet, setName, _, numNormal, maxEquipped, setId, numPerfected = GetItemLinkSetInfo(link, true)
			if hasSet and setId and not found[setId] then
				local total = (numNormal or 0) + (numPerfected or 0)
				if maxEquipped and maxEquipped > 0 then
					total = zo_min(total, maxEquipped)
				end
				found[setId] = { name = setName, total = total, perfected = numPerfected or 0 }
				order[#order + 1] = setId
			end
		end
	end

	for _, setId in ipairs(order) do
		if not recById[setId] then
			local rec = NewRec(setId)
			recById[setId] = rec
			recs[#recs + 1] = rec
		end
	end

	local changed = false
	local active = {}
	for _, rec in ipairs(recs) do
		local piece = found[rec.setId]
		local count, perfected = piece and piece.total or 0, piece and piece.perfected or 0
		if count ~= rec.count or perfected ~= rec.perfected then
			-- both counts side by side: the one read from a worn item and the one the game keeps for the set
			local _, _, _, bySet, bySetPerfected = GetItemSetInfo(rec.setId)
			Log("%s: %d -> %d piece(s), perfected %d -> %d; the game's count for the set: %s, perfected %s",
				SetDisplayName(rec), rec.count, count, rec.perfected, perfected, tostring(bySet), tostring(bySetPerfected))
		end
		rec.count = count
		rec.perfected = perfected
		if piece then
			if not rec.name or rec.name == "" then
				local name = GetItemSetName(rec.setId)
				rec.name = (name and name ~= "") and name or piece.name
			end
			if rec.info == nil then
				rec.info = addon.ReadSetEffect(rec.setId) or false
			end
		end

		local wanted = nil
		if piece and rec.info and not sv.hidden[rec.setId] then
			wanted = SelectBonus(rec)
		end
		if wanted then
			if wanted ~= rec.bonus then
				-- a different line (or the first one): what ran under the old line says nothing
				rec.bonus = wanted
				ResetTimers(rec)
				changed = true
			end
			if not rec.live then
				Log("%s: the %d-piece bonus is on", SetDisplayName(rec), wanted.required)
			end
			rec.live = true
			rec.offSince = nil
		else
			if rec.live then
				rec.live = false
				rec.offSince = now
				Log("%s: no bonus with a time is on (%d piece(s))", SetDisplayName(rec), count)
			end
			-- Off is not gone: the row stays while an effect or cooldown runs, or while the
			-- reading may still be a dip. The user's own "hide" is the exception.
			if rec.bonus and (sv.hidden[rec.setId] or not Showing(rec, now)) then
				Log("%s: row dropped", SetDisplayName(rec))
				rec.bonus = nil
				ResetTimers(rec)
				changed = true
			end
		end
		if rec.bonus then
			active[#active + 1] = rec
		end
	end

	if changed then
		activeRecs = active
		ClearVerdicts()
		RefreshEvents()
		Relayout()
	end
end

-- ---- UI -----------------------------------------------------------------------------
local COLORS = {
	active = { 0.35, 0.9, 0.4 },
	cooldown = { 1, 0.6, 0.2 },
	ready = { 0.4, 0.8, 1 },
	idle = { 0.55, 0.55, 0.55 },
	flash = { 1, 1, 1 },
}

local function Solid(name, parent, r, g, b, a)
	local tex = wm:CreateControl(name, parent, CT_TEXTURE)
	tex:SetColor(r, g, b, a)
	return tex
end

local function FontName(size)
	for _, known in ipairs(addon.FONT_SIZES) do
		if known == size then
			return "ZoFontGamepad" .. size
		end
	end
	return "ZoFontGamepad22"
end

-- How wide a row is: far enough to hold whichever elements are shown.
local function RowWidth()
	local sv = addon.sv
	local width = 1
	if sv.nameShow then
		width = zo_max(width, sv.nameX + sv.nameWidth)
	end
	if sv.barShow then
		width = zo_max(width, sv.barX + sv.barWidth)
	end
	if sv.textShow then
		width = zo_max(width, sv.textX + sv.textWidth)
	end
	return width
end

-- Puts the three elements of a row where the settings say. Everything is anchored to the row's
-- left edge and vertical middle, so no element depends on another.
local function LayoutRow(row)
	local sv = addon.sv
	local height = sv.rowHeight
	local control = row.control
	control:SetDimensions(RowWidth(), height)

	row.name:SetFont(FontName(sv.nameFont))
	row.name:SetDimensions(sv.nameWidth, height)
	row.name:ClearAnchors()
	row.name:SetAnchor(LEFT, control, LEFT, sv.nameX, sv.nameY)
	row.name:SetHidden(not sv.nameShow)

	row.barBg:SetDimensions(sv.barWidth, sv.barHeight)
	row.barBg:ClearAnchors()
	row.barBg:SetAnchor(LEFT, control, LEFT, sv.barX, sv.barY)
	row.barBg:SetHidden(not sv.barShow)

	row.text:SetFont(FontName(sv.textFont))
	row.text:SetDimensions(sv.textWidth, height)
	row.text:ClearAnchors()
	row.text:SetAnchor(LEFT, control, LEFT, sv.textX, sv.textY)
	row.text:SetHidden(not sv.textShow)

	-- what was painted no longer fits; paint it again
	row.lastText = nil
	row.lastColor = nil
	row.lastWidth = nil
end

local function BuildRow(index)
	local control = wm:CreateControl("$(parent)Row" .. index, ui.top, CT_CONTROL)
	control:SetHidden(true)

	local name = wm:CreateControl("$(parent)Name", control, CT_LABEL)
	name:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	name:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)

	local barBg = Solid("$(parent)BarBg", control, 0, 0, 0, 0.55)

	local fill = Solid("$(parent)Fill", barBg, 1, 1, 1, 0.9)
	fill:SetAnchor(TOPLEFT, barBg, TOPLEFT, 0, 0)
	fill:SetDrawLevel(2)

	local text = wm:CreateControl("$(parent)Text", control, CT_LABEL)
	text:SetVerticalAlignment(TEXT_ALIGN_CENTER)

	local row = { control = control, name = name, barBg = barBg, fill = fill, text = text, shown = false }
	rows[index] = row
	LayoutRow(row)
end

local function BuildUI()
	local top = wm:CreateTopLevelWindow("PBsProcSetTimerTop")
	top:SetMouseEnabled(false)
	top:SetMovable(false)
	top:SetHidden(true)
	ui.top = top
	for index = 1, MAX_ROWS do
		BuildRow(index)
	end
end

local function RefreshVisibility()
	local sv = addon.sv
	local want = sv.enabled
		and state.hudShown
		and ui.shown > 0
		and (addon.preview or not sv.combatOnly or state.inCombat)
	ui.top:SetHidden(not want)
end

-- Rows are packed from the top, so a set that is not worn leaves no gap.
function Relayout()
	local sv = addon.sv
	local shown = 0

	local function Place(row, label)
		shown = shown + 1
		row.shown = true
		row.control:SetHidden(false)
		row.control:ClearAnchors()
		row.control:SetAnchor(TOPLEFT, ui.top, TOPLEFT, 0, (shown - 1) * sv.rowHeight)
		row.name:SetText(label)
		row.lastText = nil
		row.lastColor = nil
		row.lastWidth = nil
	end

	for _, row in ipairs(rows) do
		row.rec = nil
		row.sample = nil
		row.shown = false
		row.control:SetHidden(true)
	end

	if addon.preview then
		for index = 1, PREVIEW_ROWS do
			local row = rows[index]
			Place(row, string.format(GetString(SI_PBSPST_SAMPLE_SET), index))
			row.sample = index
		end
	else
		for _, rec in ipairs(activeRecs) do
			local row = rows[shown + 1]
			if not row then
				break
			end
			local detected = next(rec.seen) ~= nil
			if not sv.onlyDetected or detected then
				Place(row, SetDisplayName(rec))
				row.rec = rec
			end
		end
	end

	local width = RowWidth()
	ui.top:SetDimensions(width, zo_max(shown * sv.rowHeight, 1))
	ui.shown = shown
	RefreshVisibility()
end

function addon:ApplyLayout()
	local sv = self.sv
	ui.top:ClearAnchors()
	ui.top:SetAnchor(TOPLEFT, GuiRoot, CENTER, sv.posX, sv.posY)
	ui.top:SetScale(sv.scale / 100)
	for _, row in ipairs(rows) do
		LayoutRow(row)
	end
	Relayout()
end

local function Paint(row, colorKey, width, text)
	if row.lastColor ~= colorKey then
		row.lastColor = colorKey
		local c = COLORS[colorKey]
		row.fill:SetColor(c[1], c[2], c[3], 0.9)
		row.text:SetColor(c[1], c[2], c[3], 1)
	end
	if row.lastWidth ~= width then
		row.lastWidth = width
		row.fill:SetDimensions(zo_max(1, width), addon.sv.barHeight)
	end
	if row.lastText ~= text then
		row.lastText = text
		row.text:SetText(text)
	end
end

-- Sample rows for placing the display: one of each state.
local function UpdateSample(row)
	local barWidth = addon.sv.barWidth
	if row.sample == 1 then
		Paint(row, "active", zo_floor(barWidth * 0.64), GetString(SI_PBSPST_PREVIEW_ROW))
	elseif row.sample == 2 then
		Paint(row, "cooldown", zo_floor(barWidth * 0.6), string.format(GetString(SI_PBSPST_COOLDOWN), 4.8))
	else
		Paint(row, "ready", barWidth, GetString(SI_PBSPST_READY))
	end
end

local function UpdateRow(row, now)
	if row.sample then
		UpdateSample(row)
		return
	end
	local rec = row.rec
	local bonus = rec.bonus
	local sv = addon.sv
	local barWidth = sv.barWidth

	if rec.actEnd <= now and next(rec.units) then
		RecomputeActive(rec, now)
	end
	local act = rec.actEnd - now
	local cd = rec.cdUntil - now

	if cd > 0 then
		rec.wasOnCd = true
	elseif rec.wasOnCd then
		rec.wasOnCd = false
		if sv.soundReady and SOUNDS and SOUNDS.COUNTDOWN_TICK then
			PlaySound(SOUNDS.COUNTDOWN_TICK)
		end
	end

	local colorKey, frac, text
	if act > 0 then
		colorKey = "active"
		frac = rec.actTotal > 0 and act / rec.actTotal or 1
		text = string.format(GetString(SI_PBSPST_ACTIVE), act)
		if cd > 0 then
			text = text .. "  " .. string.format(GetString(SI_PBSPST_COOLDOWN), cd)
		end
	elseif cd > 0 then
		colorKey = "cooldown"
		frac = rec.cdTotal > 0 and cd / rec.cdTotal or 1
		text = string.format(GetString(SI_PBSPST_COOLDOWN), cd)
	elseif bonus.cooldown then
		colorKey = "ready"
		frac = 1
		text = GetString(SI_PBSPST_READY)
	elseif not bonus.duration and rec.procs > 0 then
		-- the text gave no timing at all: at least say when it last fired
		colorKey = "idle"
		frac = 0
		text = string.format(GetString(SI_PBSPST_AGO), now - rec.lastProc)
	else
		colorKey = "idle"
		frac = 0
		text = GetString(SI_PBSPST_IDLE)
	end

	if now < rec.flashUntil then
		colorKey = "flash"
	end
	Paint(row, colorKey, zo_floor(barWidth * zo_min(1, frac)), text)
end

local function OnUpdate()
	local now = Now()
	local over = false
	for _, row in ipairs(rows) do
		if row.shown then
			UpdateRow(row, now)
			-- a row kept only by its timers goes the moment they end, not at the next poll
			if row.rec and not Showing(row.rec, now) then
				over = true
			end
		end
	end
	if over then
		Rescan()
	end
end

local function OnWornSlot(_, _, slotId)
	Log("worn slot %s updated", tostring(slotId))
	Rescan()
end

local function OnWeaponPair(_, pair, locked)
	Log("bar swap: weapon pair %s, locked %s", tostring(pair), tostring(locked))
	Rescan()
end

local function OnHudStateChange()
	state.hudShown = HUD_SCENE:IsShowing() or HUD_UI_SCENE:IsShowing()
	RefreshVisibility()
end

local function OnCombatState(_, inCombat)
	state.inCombat = inCombat
	RefreshVisibility()
end

-- ---- public -------------------------------------------------------------------------
-- Changing any setting re-lays the rows out; it is a few dozen calls, cheap next to the
-- slider drag that causes it.
function addon:Set(key, value)
	self.sv[key] = value
	self:ApplyLayout()
	Rescan() -- a hidden/shown change can add or remove a row
end

function addon:SetPreview(value)
	self.preview = value
	Relayout()
end

function addon:Reset()
	for key, value in pairs(self.DEFAULTS) do
		if type(value) ~= "table" then
			self.sv[key] = value
		end
	end
	self.sv.bind = {}
	self.sv.ignore = {}
	self.sv.hidden = {}
	ClearVerdicts()
	self:ApplyLayout()
	Rescan()
end

-- ---- slash command ------------------------------------------------------------------
local function Seconds(value)
	return value and string.format("%.1fs", value) or "?"
end

-- A worn set by id or by part of its name (the sets worn at some point this session).
local function FindRec(argument)
	local id = tonumber(argument)
	if id then
		return recById[id], id
	end
	argument = zo_strlower(argument or "")
	if argument == "" then
		return nil
	end
	for _, rec in ipairs(recs) do
		if zo_strlower(SetDisplayName(rec)):find(argument, 1, true) then
			return rec, rec.setId
		end
	end
	return nil
end

local function WhyNoRow(rec)
	if addon.sv.hidden[rec.setId] then
		return "hidden"
	elseif rec.info == false then
		return "the game has no such set"
	elseif rec.count == 0 then
		return "not worn"
	elseif not rec.info.timed then
		return "no time in any bonus text"
	end
	return "worn pieces switch on no bonus that has a time"
end

local function PrintSets()
	local worn = 0
	for _, rec in ipairs(recs) do
		if rec.count > 0 or rec.bonus or addon.sv.hidden[rec.setId] then
			worn = worn + 1
			local detail = rec.bonus and string.format("row: %d-piece bonus%s", rec.bonus.required, rec.live and "" or " (switched off, kept while its timers run)")
				or ("no row: " .. WhyNoRow(rec))
			d(string.format("%s (id %d): %d piece(s) -- %s", SetDisplayName(rec), rec.setId, rec.count, detail))
		end
	end
	if worn == 0 then
		d("No set worn.")
	end
end

local function PrintStatus()
	for _, rec in ipairs(recs) do
		local bonus = rec.bonus
		if rec.count > 0 or bonus then
			d(
				string.format(
					"%s (id %d): %d piece(s)%s",
					SetDisplayName(rec),
					rec.setId,
					rec.count,
					bonus and string.format(", following the %d-piece bonus%s", bonus.required, rec.live and "" or " (switched off, kept while its timers run)")
						or (", no row: " .. WhyNoRow(rec))
				)
			)
		end
		if bonus then
			d(
				string.format(
					"  read from the text: duration %s, cooldown %s, delay %s%s",
					Seconds(bonus.duration),
					Seconds(bonus.cooldown),
					Seconds(bonus.delay),
					bonus.inferred and " (a time was placed by its position, not by its wording)" or ""
				)
			)
			d(string.format("  procs %d, other players' events skipped %d", rec.procs, rec.foreign))
			for abilityId, entry in pairs(rec.seen) do
				d(string.format("  matched %s %d %s x%d", entry.kind, abilityId, entry.name or "?", entry.n))
			end
		end
	end
end

-- What the worn sets did lately: bar swaps, piece counts, bonuses switching on and off.
local function PrintLog()
	if #state.log == 0 then
		d("Nothing logged yet.")
		return
	end
	for _, line in ipairs(state.log) do
		d(line)
	end
end

local function PrintText(argument)
	local targets = {}
	if argument ~= "" then
		local rec, id = FindRec(argument)
		if not id then
			d(string.format(GetString(SI_PBSPST_SET_NOT_FOUND), argument))
			return
		end
		-- a set id the player never wore is still readable
		targets[1] = rec or { setId = id }
	else
		for _, rec in ipairs(recs) do
			if rec.count > 0 then
				targets[#targets + 1] = rec
			end
		end
	end
	for _, rec in ipairs(targets) do
		local info = rec.info or addon.ReadSetEffect(rec.setId)
		d(string.format("%s (id %d)", SetDisplayName(rec), rec.setId))
		if not info then
			d("  the game has no such set")
		else
			for index, bonus in ipairs(info.bonuses) do
				d(string.format("  [%d] %d pc%s: %s", index, bonus.required, bonus.perfected and " (perfected)" or "", bonus.text))
				for _, hit in ipairs(bonus.parsed.hits) do
					d(string.format("      %.1f s -> %s", hit.seconds, hit.class))
				end
			end
		end
	end
end

local function Bind(argument)
	if argument == "clear" then
		addon.sv.bind = {}
		ClearVerdicts()
		d(GetString(SI_PBSPST_BIND_CLEARED))
		return
	end
	local id, target = argument:match("^(%d+)%s+(.+)$")
	if not id then
		d(GetString(SI_PBSPST_BIND_USAGE))
		return
	end
	local rec = FindRec(target)
	if not rec then
		d(string.format(GetString(SI_PBSPST_SET_NOT_FOUND), target))
		return
	end
	addon.sv.bind[tonumber(id)] = rec.setId
	ClearVerdicts()
	d(string.format(GetString(SI_PBSPST_BIND_DONE), tonumber(id), SetDisplayName(rec)))
end

local function Ignore(argument)
	if argument == "clear" then
		addon.sv.ignore = {}
		ClearVerdicts()
		d(GetString(SI_PBSPST_IGNORE_CLEARED))
		return
	end
	local id = tonumber(argument)
	if not id then
		d(GetString(SI_PBSPST_IGNORE_USAGE))
		return
	end
	addon.sv.ignore[id] = true
	ClearVerdicts()
	d(string.format(GetString(SI_PBSPST_IGNORE_DONE), id))
end

local function HideShow(argument, hide)
	local rec, id = FindRec(argument)
	if not id then
		d(string.format(GetString(SI_PBSPST_SET_NOT_FOUND), argument))
		return
	end
	addon.sv.hidden[id] = hide or nil
	Rescan()
	local name = rec and SetDisplayName(rec) or ("#" .. id)
	d(string.format(GetString(hide and SI_PBSPST_HIDE_DONE or SI_PBSPST_SHOW_DONE), name, id, id))
end

local function OnSlash(argument)
	argument = zo_strtrim(argument or "")
	local command, rest = argument:match("^(%S*)%s*(.-)$")
	command = zo_strlower(command)
	if command == "on" or command == "off" then
		addon:Set("enabled", command == "on")
		d(GetString(command == "on" and SI_PBSPST_ON or SI_PBSPST_OFF))
	elseif command == "sets" then
		Rescan()
		PrintSets()
	elseif command == "status" then
		Rescan()
		PrintStatus()
	elseif command == "log" then
		PrintLog()
	elseif command == "text" then
		PrintText(rest)
	elseif command == "hide" then
		HideShow(rest, true)
	elseif command == "show" then
		HideShow(rest, false)
	elseif command == "probe" then
		state.probe = not state.probe
		state.probeSeen = {}
		RefreshEvents()
		d(GetString(state.probe and SI_PBSPST_PROBE_ON or SI_PBSPST_PROBE_OFF))
	elseif command == "bind" then
		Bind(rest)
	elseif command == "ignore" then
		Ignore(rest)
	elseif command == "preview" then
		addon:SetPreview(not addon.preview)
		d(GetString(addon.preview and SI_PBSPST_PREVIEW_ON or SI_PBSPST_PREVIEW_OFF))
	else
		d(GetString(SI_PBSPST_HELP))
	end
end

-- ---- load ---------------------------------------------------------------------------
local function OnPlayerActivated()
	-- chat is up by now; a line printed at EVENT_ADD_ON_LOADED is lost
	if not addon.bannerShown then
		addon.bannerShown = true
		d(string.format(GetString(SI_PBSPST_LOADED), addon.version))
	end
	-- a zone change or reload drops every effect
	for _, rec in ipairs(recs) do
		ResetTimers(rec)
	end
	Rescan()
end

local function OnAddOnLoaded(_, name)
	if name ~= addon.name then
		return
	end
	em:UnregisterForEvent(addon.name, EVENT_ADD_ON_LOADED)

	addon.sv = ZO_SavedVars:NewAccountWide("PBsProcSetTimer_Data", 2, nil, addon.DEFAULTS)

	BuildUI()
	addon:ApplyLayout()
	ui.top:SetHandler("OnUpdate", OnUpdate)

	state.inCombat = IsUnitInCombat("player")

	em:RegisterForEvent(addon.name .. "Activated", EVENT_PLAYER_ACTIVATED, OnPlayerActivated)
	em:RegisterForEvent(addon.name .. "Combat", EVENT_PLAYER_COMBAT_STATE, OnCombatState)
	em:RegisterForEvent(addon.name .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnWornSlot)
	em:AddFilterForEvent(addon.name .. "Slot", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, REGISTER_FILTER_BAG_ID, BAG_WORN)
	em:RegisterForEvent(addon.name .. "Weapons", EVENT_ACTIVE_WEAPON_PAIR_CHANGED, OnWeaponPair)
	-- the events above cover equipping; this is the net under them
	em:RegisterForUpdate(addon.name .. "Rescan", RESCAN_MS, Rescan)

	HUD_SCENE:RegisterCallback("StateChange", OnHudStateChange)
	HUD_UI_SCENE:RegisterCallback("StateChange", OnHudStateChange)
	OnHudStateChange()

	SLASH_COMMANDS["/procset"] = OnSlash

	Relayout()
	if addon.InitSettings then
		addon:InitSettings()
	end
end

em:RegisterForEvent(addon.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
