-- Offline checks for PBsProcSetTimer. Run from the test directory:
--
--     lua run.lua            (English UI strings)
--     lua run.lua jp         (Japanese UI strings, Japanese set text and ability names)
--     luajit run.lua         (5.1 semantics, the game's Lua)
--
-- The game is replaced by mock.lua; see there. What this proves is the add-on's own logic against
-- the event shapes the API documents. It does NOT prove that the real client names its proc
-- abilities the way the matching assumes -- that needs /procset status on a console.

local lang = arg and arg[1] or "en"
local M = dofile("mock.lua")
local T = dofile("texts.lua")
local ADDON = "../PBsProcSetTimer/"

local passed, failed = 0, 0
local function ok(cond, label)
	if cond then
		passed = passed + 1
	else
		failed = failed + 1
		print("  FAIL: " .. label)
	end
end
local function eq(actual, expected, label)
	ok(actual == expected, string.format("%s (got %s, wanted %s)", label, tostring(actual), tostring(expected)))
end
local function near(actual, expected, label)
	ok(actual ~= nil and math.abs(actual - expected) < 0.051, string.format("%s (got %s, wanted %s)", label, tostring(actual), tostring(expected)))
end
local function section(name)
	print("== " .. name)
end

-- ---- boot ---------------------------------------------------------------------------
local SET = {
	martial = { id = 147, en = "Way of Martial Knowledge", jp = "武術知識の道" },
	zen = { id = 455, en = "Z'en's Redress", jp = "ズェンの矯正" },
	nightmare = { id = 736, en = "Tarnished Nightmare", jp = "汚された悪夢" },
}
local function setName(key)
	return SET[key][lang == "jp" and "jp" or "en"]
end

-- Ability names as the client would report them, in the language of the set text.
local AB = lang == "jp" and { martial = "武術知識", zen = "ズェンの接触", nightmare = "汚された悪夢" }
	or { martial = "Martial Knowledge", zen = "Touch of Z'en", nightmare = "Tarnished Nightmare" }

local function bonusesFor(key)
	if lang ~= "jp" then
		return T.en[key]
	end
	local out = {}
	for i = 1, 3 do
		out[i] = { i + 1, "最大マジカ+1096" }
	end
	out[4] = { 5, T.variants[1][key] }
	return out
end

local function defineSets(texts)
	M.sets = {}
	M.worn = {}
	M.perfected = {}
	for key, def in pairs(SET) do
		M.sets[def.id] = { name = setName(key), bonuses = texts and texts[key] or bonusesFor(key) }
	end
	for id, def in pairs(T.extra) do
		M.sets[id] = { name = def.name, max = def.max, bonuses = def.bonuses }
	end
end

local function boot(texts)
	PBS_PROCSETTIMER = nil
	M.events, M.filters, M.updates, M.controls, M.chat, M.sounds = {}, {}, {}, {}, {}, {}
	M.time = 100
	HUD_SCENE.callbacks, HUD_UI_SCENE.callbacks = {}, {}
	SLASH_COMMANDS = {}
	GuiRoot = WINDOW_MANAGER:CreateTopLevelWindow("GuiRoot")
	dofile(ADDON .. "lang/strings.lua")
	if lang == "jp" then
		dofile(ADDON .. "lang/jp.lua")
	end
	defineSets(texts)
	dofile(ADDON .. "Main.lua")
	dofile(ADDON .. "Parse.lua")
	dofile(ADDON .. "Settings.lua")
	M.fire(EVENT_ADD_ON_LOADED, "PBsProcSetTimer")
	HUD_SCENE:Set(true)
	M.fire(EVENT_PLAYER_ACTIVATED)
	return PBS_PROCSETTIMER
end

local function top()
	return M.controls["PBsProcSetTimerTop"]
end
local function frame()
	local handler = top().handlers.OnUpdate
	if handler and not top().hidden then
		handler()
	end
end
local function rowAt(i)
	local base = "PBsProcSetTimerTopRow" .. i
	return {
		control = M.controls[base],
		name = M.controls[base .. "Name"],
		barBg = M.controls[base .. "BarBg"],
		fill = M.controls[base .. "BarBgFill"],
		text = M.controls[base .. "Text"],
	}
end
-- the visible rows, top to bottom
local function visibleRows()
	local list = {}
	for i = 1, 8 do
		local r = rowAt(i)
		if not r.control.hidden then
			list[#list + 1] = r
		end
	end
	return list
end
local function rowFor(label)
	for _, r in ipairs(visibleRows()) do
		if r.name.text == label then
			return r
		end
	end
	return { name = {}, text = {}, fill = { color = {} }, barBg = {}, control = { hidden = true, anchors = { {} } } }
end
local function rowOf(key)
	return rowFor(setName(key))
end
local function wearId(id, count)
	M.wear(id, count)
	M.fire(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, BAG_WORN, 0)
end
local function wear(key, count)
	wearId(SET[key].id, count)
end
local function slash(text)
	SLASH_COMMANDS["/procset"](text)
end

local function effect(change, name, id, unit, from, to, source)
	M.fire(
		EVENT_EFFECT_CHANGED,
		change,
		1,
		name,
		"reticleover",
		from,
		to,
		1,
		"icon",
		"",
		1,
		1,
		0,
		"enemy",
		unit,
		id,
		source or COMBAT_UNIT_TYPE_PLAYER
	)
end
local function hit(result, name, id, slot, source)
	M.fire(
		EVENT_COMBAT_EVENT,
		result,
		false,
		name,
		0,
		slot or ACTION_SLOT_TYPE_NOTHING,
		"me",
		source or COMBAT_UNIT_TYPE_PLAYER,
		"enemy",
		2,
		1234,
		1,
		1,
		true,
		1,
		2,
		id,
		0
	)
end
local function activeText(seconds)
	return string.format(GetString(SI_PBSPST_ACTIVE), seconds)
end
local function cdText(seconds)
	return string.format(GetString(SI_PBSPST_COOLDOWN), seconds)
end

-- ======================================================================================
section("parser: UESP wording of all three sets")
local addon = boot()
for key, expected in pairs(T.expected) do
	local bonus = T.en[key][4]
	local parsed = addon.ParseBonusText(bonus[2])
	eq(parsed.cooldown, expected[1], key .. " cooldown")
	eq(parsed.duration, expected[2], key .. " duration")
	eq(parsed.delay, expected[3], key .. " delay")
	ok(not parsed.inferred, key .. " read by wording, not by position")
	-- the stat lines must not read as anything
	local stat = addon.ParseBonusText(T.en[key][1][2])
	eq(#stat.hits, 0, key .. " 2-piece line has no times")
end

section("parser: other languages and wordings")
for _, variant in ipairs(T.variants) do
	local flagged = {}
	for key, expected in pairs(T.expected) do
		local parsed = addon.ParseBonusText(variant[key])
		eq(parsed.cooldown, expected[1], variant.label .. " " .. key .. " cooldown")
		eq(parsed.duration, expected[2], variant.label .. " " .. key .. " duration")
		eq(parsed.delay, expected[3], variant.label .. " " .. key .. " delay")
		if parsed.inferred then
			flagged[#flagged + 1] = key
		end
	end
	print(string.format("  %-58s placed by position: %s", variant.label, #flagged > 0 and table.concat(flagged, ",") or "-"))
end

section("parser: odd input")
eq(addon.ParseBonusText("").cooldown, nil, "empty text")
eq(#addon.ParseBonusText("Adds 8% damage. Level 5 required.").hits, 0, "percent and plain numbers are not times")
eq(addon.ParseBonusText("|cFFFFFF8 seconds|r |t16:16:x.dds|t").duration, 8, "colour codes and texture tags stripped")
eq(addon.ParseBonusText("for 1,5 seconds").duration, 1.5, "decimal comma")

section("reading a set through the item API")
local info = addon.ReadSetEffect(SET.martial.id)
eq(#info.bonuses, 4, "four bonus lines")
eq(info.timed, true, "the set has a timed bonus")
eq(info.bonuses[1].timed, false, "the 2-piece stat line is not timed")
eq(info.bonuses[4].required, 5, "martial proc bonus needs 5 pieces")
eq(info.bonuses[4].cooldown, 8, "martial cooldown through ReadSetEffect")
eq(info.bonuses[4].duration, 5, "martial duration through ReadSetEffect")
eq(info.bonuses[4].perfected, false, "not a Perfected bonus")
ok(info.bonuses[4].text:find(lang == "jp" and "軽攻撃" or "Light Attacks", 1, true) ~= nil, "bonus text kept for name matching")
eq(addon.ReadSetEffect(99999), nil, "unknown set id")
eq(addon.ReadSetEffect(9002).timed, false, "a stats-only set has no timed bonus")

-- ======================================================================================
section("nothing worn: nothing listens, nothing shows")
eq(M.listening(EVENT_EFFECT_CHANGED), 0, "no effect listener")
eq(M.listening(EVENT_COMBAT_EVENT), 0, "no combat listener")
ok(top().hidden, "window hidden")

section("Way of Martial Knowledge")
addon = boot()
wear("martial", 4)
eq(M.listening(EVENT_EFFECT_CHANGED), 0, "4 pieces: proc bonus not on, still not listening")
wear("martial", 5)
eq(M.listening(EVENT_EFFECT_CHANGED), 1, "5 pieces: effect listener on")
eq(M.listening(EVENT_COMBAT_EVENT), 1, "5 pieces: combat listener on")
eq(M.filters[addon.name .. "Hit:" .. EVENT_COMBAT_EVENT][2], COMBAT_UNIT_TYPE_PLAYER, "combat events filtered to the player")
ok(not top().hidden, "window shown")
frame()
eq(#visibleRows(), 1, "one row")
eq(rowOf("martial").name.text, setName("martial"), "row carries the game's set name")
eq(rowOf("martial").text.text, GetString(SI_PBSPST_READY), "ready before any proc")

local t0 = M.time
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 77, t0, t0 + 5)
frame()
eq(rowOf("martial").text.text, activeText(5) .. "  " .. cdText(8), "proc: active 5.0 and CD 8.0")
ok(rowOf("martial").fill.color[1] == 1 and rowOf("martial").fill.color[2] == 1, "proc: bar flashes white")
eq(rowOf("martial").fill.w, 140, "proc: bar full")
M.advance(2)
frame()
eq(rowOf("martial").text.text, activeText(3) .. "  " .. cdText(6), "t+2: active 3.0, CD 6.0")
eq(rowOf("martial").fill.w, math.floor(140 * 3 / 5), "t+2: bar at 3/5")
-- the same proc reporting again, on a second target inside the cooldown
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 78, t0, t0 + 5)
M.advance(3.5)
frame()
eq(rowOf("martial").text.text, cdText(2.5), "t+5.5: effect over, only CD 2.5 left")
-- a reticle swap to an enemy that already carries the debuff: GAINED with an old beginTime
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 79, M.time - 2, M.time + 1.5)
frame()
ok(rowOf("martial").text.text:find(cdText(2.5), 1, true) ~= nil, "old effect seen on a new target does not restart the cooldown")
M.advance(3)
frame()
eq(rowOf("martial").text.text, GetString(SI_PBSPST_READY), "t+8.5: ready again")
-- a group member wearing the same set must not drive our timer
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 80, M.time, M.time + 5, COMBAT_UNIT_TYPE_GROUP)
frame()
eq(rowOf("martial").text.text, GetString(SI_PBSPST_READY), "another player's proc is ignored")
-- the next proc after the cooldown
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 81, M.time, M.time + 5)
frame()
ok(rowOf("martial").text.text:find(cdText(8), 1, true) ~= nil, "second proc after the cooldown starts a new one")
-- unrelated effects are not matched
effect(EFFECT_RESULT_GAINED, "Minor Berserk", 61744, 1, M.time, M.time + 10)
effect(EFFECT_RESULT_GAINED, "Hex", 99, 1, M.time, M.time + 10)
eq(next(addon.sv.bind), nil, "nothing pinned by itself")

section("fading and the sound at the end of the cooldown")
addon.sv.soundReady = true
M.advance(9)
frame()
eq(#M.sounds, 1, "one tick when the cooldown ended")
M.advance(1)
frame()
eq(#M.sounds, 1, "and only one")

section("Z'en's Redress (a debuff kept up by light attacks, no cooldown)")
addon = boot()
wear("zen", 5)
frame()
eq(rowOf("zen").text.text, GetString(SI_PBSPST_IDLE), "no cooldown: idle shows a dash, not Ready")
t0 = M.time
effect(EFFECT_RESULT_GAINED, AB.zen, 126597, 5, t0, t0 + 20)
frame()
eq(rowOf("zen").text.text, activeText(20), "Touch of Z'en matched by the name in the bonus text, its 20 s agreeing with the text")
M.advance(4)
effect(EFFECT_RESULT_UPDATED, AB.zen, 126597, 5, M.time, M.time + 20)
frame()
eq(rowOf("zen").text.text, activeText(20), "a light attack refreshes it to 20.0")
ok(not (rowOf("zen").fill.color[1] == 1 and rowOf("zen").fill.color[2] == 1), "a refresh does not flash again")
M.advance(6)
frame()
eq(rowOf("zen").text.text, activeText(14), "14.0 left")
effect(EFFECT_RESULT_FADED, AB.zen, 126597, 5, M.time - 10, M.time)
frame()
eq(rowOf("zen").text.text, GetString(SI_PBSPST_IDLE), "faded: back to idle")
-- expiry without a FADED event
effect(EFFECT_RESULT_GAINED, AB.zen, 126597, 6, M.time, M.time + 20)
M.advance(21)
frame()
eq(rowOf("zen").text.text, GetString(SI_PBSPST_IDLE), "expired by the clock alone")

section("Tarnished Nightmare (a delayed burst of hits)")
addon = boot()
wear("nightmare", 5)
frame()
for _ = 1, 5 do -- one burst hitting five enemies
	hit(ACTION_RESULT_DAMAGE, AB.nightmare, 200100)
end
hit(ACTION_RESULT_CRITICAL_DAMAGE, AB.nightmare, 200100)
frame()
near(tonumber(rowOf("nightmare").text.text:match("([%d%.]+)$")), 6.7, "cooldown counts from the critical, 1.3 s before the burst (8 - 1.3)")
ok(rowOf("nightmare").text.text:find(GetString(SI_PBSPST_COOLDOWN):sub(1, 2), 1, true) ~= nil, "shows CD")
-- things that must not count
M.advance(1)
hit(ACTION_RESULT_DAMAGE, "Light Attack", 16165, ACTION_SLOT_TYPE_LIGHT_ATTACK)
hit(ACTION_RESULT_DAMAGE, "Heavy Attack", 16420, ACTION_SLOT_TYPE_HEAVY_ATTACK)
hit(ACTION_RESULT_DOT_TICK, AB.nightmare, 200100)
frame()
near(tonumber(rowOf("nightmare").text.text:match("([%d%.]+)$")), 5.7, "light/heavy attacks and ticks changed nothing")
M.advance(8)
frame()
eq(rowOf("nightmare").text.text, GetString(SI_PBSPST_READY), "ready after 8 s")
hit(ACTION_RESULT_DAMAGE, AB.nightmare, 200100)
frame()
near(tonumber(rowOf("nightmare").text.text:match("([%d%.]+)$")), 6.7, "next burst starts a new cooldown")

section("all three at once, rows packed from the top in the order worn")
addon = boot()
wear("martial", 5)
wear("zen", 5)
wear("nightmare", 4)
frame()
eq(#visibleRows(), 2, "two rows shown, the third (4 pieces) not")
eq(rowOf("martial").control.anchors[1].y, 0, "first row at the top")
eq(rowOf("zen").control.anchors[1].y, 36, "second row directly under it")
wear("martial", 0)
frame()
eq(#visibleRows(), 2, "martial taken off: its row stays through the grace period (a reading may dip)")
M.advance(3)
frame()
eq(#visibleRows(), 1, "and goes once the grace is over")
eq(rowOf("zen").control.anchors[1].y, 0, "the remaining row moves up")
wear("zen", 0)
M.advance(3)
frame()
ok(top().hidden, "nothing worn: window hidden")
eq(M.listening(EVENT_EFFECT_CHANGED), 0, "nothing worn: listeners removed")

-- ======================================================================================
section("any set: the bonus line follows the pieces worn")
addon = boot()
wearId(9001, 2)
eq(#visibleRows(), 0, "2 pieces: the only bonus on is a stat line, no row")
eq(M.listening(EVENT_EFFECT_CHANGED), 0, "and nothing listens")
wearId(9001, 3)
eq(#visibleRows(), 1, "3 pieces: the timed 3-piece line switches a row on")
eq(rowFor("Test Haste Set").name.text, "Test Haste Set", "row carries the set's name")
frame()
t0 = M.time
-- the player's own skill gives Major Courage for 20 s: named in the text, but not the proc's length
effect(EFFECT_RESULT_GAINED, "Major Courage", 61488, 1, t0, t0 + 20)
frame()
eq(rowFor("Test Haste Set").text.text, GetString(SI_PBSPST_READY), "a standard buff named in the text, lasting 20 s, is not the 6 s proc")
-- a fade seen first must not decide anything
effect(EFFECT_RESULT_FADED, "Major Courage", 109084, 1, t0 - 6, t0)
effect(EFFECT_RESULT_GAINED, "Major Courage", 109084, 1, t0, t0 + 6)
frame()
eq(rowFor("Test Haste Set").text.text, activeText(6) .. "  " .. cdText(12), "the same name lasting the text's 6 s is the proc")
-- a hit is never matched on the text alone
hit(ACTION_RESULT_DAMAGE, "Major Courage", 109085)
eq(addon.sv and true, true, "alive")
wearId(9001, 5)
frame()
eq(rowFor("Test Haste Set").text.text, GetString(SI_PBSPST_READY), "5 pieces: the 5-piece line takes over, timers reset")
hit(ACTION_RESULT_POWER_ENERGIZE, "Test Haste Set", 7001)
frame()
eq(rowFor("Test Haste Set").text.text, cdText(20), "the 5-piece line's cooldown is 20 s")
M.advance(1)
effect(EFFECT_RESULT_GAINED, "Major Courage", 109084, 1, M.time, M.time + 6)
frame()
eq(rowFor("Test Haste Set").text.text, cdText(19), "the old line's effect no longer counts")
wearId(9001, 4)
frame()
eq(rowFor("Test Haste Set").text.text, GetString(SI_PBSPST_READY), "4 pieces: back on the 3-piece line")

section("any set: stat-only, monster and Perfected sets")
addon = boot()
wearId(9002, 5)
eq(#visibleRows(), 0, "a set with no time in any bonus gets no row")
M.chat = {}
slash("sets")
ok(table.concat(M.chat, "\n"):find("no time in any bonus text", 1, true) ~= nil, "/procset sets says why")
wearId(9003, 1)
eq(#visibleRows(), 0, "monster set, 1 of 2 pieces: not on")
wearId(9003, 2)
eq(#visibleRows(), 1, "monster set, 2 of 2 pieces: row")
frame()
effect(EFFECT_RESULT_GAINED, "Minor Heroism", 61708, 1, M.time, M.time + 4)
frame()
eq(rowFor("Test Monster Set").text.text, activeText(4) .. "  " .. cdText(10), "monster set proc read from its text")
wearId(9004, 5)
eq(#visibleRows(), 1, "Perfected bonus with 5 ordinary pieces: not on")
M.perfected[9004] = 5
M.fire(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, BAG_WORN, 0)
eq(#visibleRows(), 2, "Perfected bonus with 5 Perfected pieces: on")
effect(EFFECT_RESULT_GAINED, "Empower", 61737, 1, M.time, M.time + 7)
frame()
eq(rowFor("Perfected Test Set").text.text, activeText(7) .. "  " .. cdText(15), "Perfected proc read from its text")

section("any set: more sets than rows")
addon = boot()
for index = 1, 10 do
	wearId(9100 + index, 1)
end
eq(#visibleRows(), 8, "ten timed sets, eight rows")
eq(rowAt(1).name.text, "Cap Set 1", "the first set worn is the first row")
eq(rowAt(8).name.text, "Cap Set 8", "the eighth is the last")
wearId(9101, 0)
M.advance(3)
frame()
eq(#visibleRows(), 8, "one taken off: the ninth moves up into the freed row")
eq(rowAt(8).name.text, "Cap Set 9", "Cap Set 9 now has a row")

section("bar swap: a row stays while its bonus is valid or its timers run")
-- the swap itself: the game counts the worn pieces again, and a piece on the other bar goes
local function swapTo(key, count)
	M.wear(SET[key].id, count)
	M.fire(EVENT_ACTIVE_WEAPON_PAIR_CHANGED, 2, false)
end

-- a reading that dips for a moment and comes back
addon = boot()
wear("martial", 5)
frame()
swapTo("martial", 4)
frame()
eq(#visibleRows(), 1, "count dips on the swap: the row is still there")
eq(M.listening(EVENT_EFFECT_CHANGED), 1, "and the listeners were not torn down")
M.advance(1.5)
frame()
eq(#visibleRows(), 1, "1.5 s later, still inside the grace")
swapTo("martial", 5)
M.advance(1)
frame()
eq(#visibleRows(), 1, "count back: still one row")
M.advance(3)
frame()
eq(#visibleRows(), 1, "and it stays, the grace having been cancelled by the bonus returning")

-- really off, nothing running: the row goes after the grace
swapTo("martial", 4)
M.advance(1.5)
frame()
eq(#visibleRows(), 1, "bonus off, idle: kept for the grace")
M.advance(1)
frame()
eq(#visibleRows(), 0, "bonus still off after the grace: the row goes")
eq(M.listening(EVENT_EFFECT_CHANGED), 0, "and the listeners with it")

-- a proc running when the bonus goes off: the timers keep the row
addon = boot()
wear("martial", 5)
frame()
t0 = M.time
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 77, t0, t0 + 5)
frame()
swapTo("martial", 4)
M.advance(1)
frame()
eq(rowOf("martial").text.text, activeText(4) .. "  " .. cdText(7), "bar swapped away: the running effect and cooldown keep counting")
M.advance(2)
frame()
eq(rowOf("martial").text.text, activeText(2) .. "  " .. cdText(5), "after the grace the timers still hold the row")
eq(M.listening(EVENT_EFFECT_CHANGED), 1, "and the listeners stay while it does")
M.advance(3)
frame()
eq(rowOf("martial").text.text, cdText(2), "effect over, cooldown 2.0 left: still shown")
M.advance(2.5)
frame()
eq(#visibleRows(), 0, "cooldown over and the bonus off: the row goes")
ok(top().hidden, "window hidden")
eq(M.listening(EVENT_EFFECT_CHANGED), 0, "listeners removed")

-- swapping back before the timers end must not reset them
addon = boot()
wear("martial", 5)
frame()
t0 = M.time
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 77, t0, t0 + 5)
swapTo("martial", 4)
M.advance(3)
frame()
swapTo("martial", 5)
frame()
eq(rowOf("martial").text.text, activeText(2) .. "  " .. cdText(5), "swapped back: the timers carried on, not reset")
M.advance(2.5)
frame()
eq(rowOf("martial").text.text, cdText(2.5), "and keep counting")
M.advance(3)
frame()
eq(rowOf("martial").text.text, GetString(SI_PBSPST_READY), "then ready")

-- a debuff on the enemy outlives the swap, and its fade is still heard
addon = boot()
wear("zen", 5)
frame()
t0 = M.time
effect(EFFECT_RESULT_GAINED, AB.zen, 126597, 5, t0, t0 + 20)
swapTo("zen", 4)
M.advance(5)
frame()
eq(rowOf("zen").text.text, activeText(15), "Touch of Z'en still counted after the swap away")
effect(EFFECT_RESULT_FADED, AB.zen, 126597, 5, t0, M.time)
frame()
eq(#visibleRows(), 0, "it faded and the bonus is off: nothing left to show")

-- the user's own "hide" does not wait for any timer
addon = boot()
wear("martial", 5)
frame()
t0 = M.time
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 77, t0, t0 + 5)
frame()
slash("hide 147")
eq(#visibleRows(), 0, "hide: the row goes at once, timers or not")
slash("show 147")
frame()
eq(rowOf("martial").text.text, GetString(SI_PBSPST_READY), "shown again: a fresh row")

-- a zone change drops every effect, including those held by a switched-off row
addon = boot()
wear("martial", 5)
frame()
t0 = M.time
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 77, t0, t0 + 5)
swapTo("martial", 4)
M.advance(3)
frame()
eq(#visibleRows(), 1, "held by the timers")
M.fire(EVENT_PLAYER_ACTIVATED)
frame()
eq(#visibleRows(), 0, "after a zone change nothing runs any more: the row goes")

-- another bonus line takes over: that is a different effect, not a continuation
addon = boot()
wearId(9001, 5)
frame()
hit(ACTION_RESULT_POWER_ENERGIZE, "Test Haste Set", 7001)
frame()
eq(rowFor("Test Haste Set").text.text, cdText(20), "5-piece line proc: cooldown 20 s")
M.wear(9001, 3)
M.fire(EVENT_ACTIVE_WEAPON_PAIR_CHANGED, 2, false)
frame()
eq(rowFor("Test Haste Set").text.text, GetString(SI_PBSPST_READY), "3 pieces: the 3-piece line is a different effect and starts fresh")

section("what /procset log and /procset sets say about a swap")
addon = boot()
wear("martial", 5)
frame()
t0 = M.time
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 77, t0, t0 + 5)
swapTo("martial", 4)
M.advance(3)
frame()
M.chat = {}
slash("log")
local logged = table.concat(M.chat, "\n")
ok(logged:find("bar swap: weapon pair 2", 1, true) ~= nil, "the swap is logged")
ok(logged:find("5 -> 4 piece", 1, true) ~= nil, "so is the change of count, with the game's own count beside it")
ok(logged:find("the game's count for the set: 4", 1, true) ~= nil, "the count the game keeps for the set is shown")
ok(logged:find("no bonus with a time is on", 1, true) ~= nil, "and the bonus going off")
M.chat = {}
slash("sets")
ok(table.concat(M.chat, "\n"):find("switched off, kept while its timers run", 1, true) ~= nil, "/procset sets says why the row is still there")
M.chat = {}
slash("status")
ok(table.concat(M.chat, "\n"):find("switched off, kept while its timers run", 1, true) ~= nil, "/procset status says it too")
for _ = 1, 60 do
	M.fire(EVENT_ACTIVE_WEAPON_PAIR_CHANGED, 1, false)
end
M.chat = {}
slash("log")
ok(#M.chat <= 40, "the log keeps only the last lines")
addon = boot()
M.chat = {}
slash("log")
eq(M.chat[1], "Nothing logged yet.", "an empty log says so")

section("hiding sets by id or by name")
addon = boot()
wearId(9001, 3)
wear("martial", 5)
eq(#visibleRows(), 2, "two rows")
M.chat = {}
slash("hide 9001")
eq(#visibleRows(), 1, "hide by id: the row goes")
eq(addon.sv.hidden[9001], true, "saved")
eq(rowOf("martial").control.anchors[1].y, 0, "the other row moves up")
ok(M.chat[1] ~= nil and M.chat[1]:find("9001", 1, true) ~= nil, "it says what it did")
slash("show haste")
eq(#visibleRows(), 2, "show by part of the name (any case): the row is back")
eq(addon.sv.hidden[9001], nil, "and no longer saved as hidden")
slash("hide " .. setName("martial"):sub(1, 6))
eq(#visibleRows(), 1, "hide by the start of the name")
M.chat = {}
slash("hide nosuchset")
eq(M.chat[1], string.format(GetString(SI_PBSPST_SET_NOT_FOUND), "nosuchset"), "unknown set reported")
slash("hide 4242")
eq(addon.sv.hidden[4242], true, "an id never worn can be hidden in advance")
slash("show 4242")
wearId(147, 0)
wearId(9001, 0)
M.advance(3)
frame()
eq(M.listening(EVENT_EFFECT_CHANGED), 0, "nothing worn")

section("only sets whose proc was seen")
addon = boot()
wear("martial", 5)
addon:Set("onlyDetected", true)
eq(#visibleRows(), 0, "no row until a proc is seen")
ok(top().hidden, "window hidden")
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 77, M.time, M.time + 5)
eq(#visibleRows(), 1, "the first proc brings the row")
ok(not top().hidden, "window shown")
addon:Set("onlyDetected", false)

section("ignoring an ability")
addon = boot()
wear("martial", 5)
slash("ignore 127070")
eq(addon.sv.ignore[127070], true, "saved")
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 77, M.time, M.time + 5)
frame()
eq(rowOf("martial").text.text, GetString(SI_PBSPST_READY), "an ignored ability starts nothing")
slash("ignore clear")
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 78, M.time, M.time + 5)
frame()
ok(rowOf("martial").text.text:find(cdText(8), 1, true) ~= nil, "cleared: it matches again")
slash("ignore nonsense")

-- ======================================================================================
section("every element: position, size, font, visibility")
addon = boot()
wear("martial", 5)
wear("zen", 5)
frame()
local r1 = rowOf("martial")
eq(r1.name.anchors[1].x, 0, "default name x")
eq(r1.barBg.anchors[1].x, 278, "default bar x")
eq(r1.text.anchors[1].x, 426, "default text x")
eq(r1.name.w, 270, "default name width")
eq(r1.barBg.w, 140, "default bar width")
eq(r1.barBg.h, 14, "default bar height")
eq(r1.text.w, 220, "default text width")
eq(r1.name.font, "ZoFontGamepad22", "default name font")
eq(r1.text.font, "ZoFontGamepad22", "default text font")
eq(top().anchors[1].point, TOPLEFT, "block anchored by its top-left corner")
eq(top().anchors[1].rel, GuiRoot, "to the screen")
eq(top().anchors[1].relPoint, CENTER, "centre")
eq(top().anchors[1].x, -905, "default block x")
eq(top().anchors[1].y, 100, "default block y")

addon:Set("nameX", 12)
addon:Set("nameY", -3)
addon:Set("nameWidth", 150)
addon:Set("nameFont", 34)
addon:Set("barX", 200)
addon:Set("barY", 5)
addon:Set("barWidth", 100)
addon:Set("barHeight", 20)
addon:Set("textX", 320)
addon:Set("textY", 2)
addon:Set("textWidth", 90)
addon:Set("textFont", 18)
frame()
r1 = rowOf("martial")
eq(r1.name.anchors[1].x, 12, "name x moved")
eq(r1.name.anchors[1].y, -3, "name y moved")
eq(r1.name.w, 150, "name width set")
eq(r1.name.font, "ZoFontGamepad34", "name font set")
eq(r1.barBg.anchors[1].x, 200, "bar x moved")
eq(r1.barBg.anchors[1].y, 5, "bar y moved")
eq(r1.barBg.w, 100, "bar width set")
eq(r1.barBg.h, 20, "bar height set")
eq(r1.fill.w, 100, "a full (ready) bar is as wide as the bar now is")
eq(r1.fill.h, 20, "and as tall")
eq(r1.text.anchors[1].x, 320, "text x moved")
eq(r1.text.anchors[1].y, 2, "text y moved")
eq(r1.text.w, 90, "text width set")
eq(r1.text.font, "ZoFontGamepad18", "text font set")
eq(r1.name.anchors[1].rel, r1.control, "elements hang off their row, not off each other")
eq(r1.barBg.anchors[1].rel, r1.control, "bar hangs off the row")

addon:Set("rowHeight", 50)
frame()
eq(rowOf("zen").control.anchors[1].y, 50, "row height spaces the rows")
eq(rowOf("zen").name.h, 50, "and the labels follow it")
eq(top().h, 100, "the block is two rows tall")
eq(top().w, 410, "and as wide as the furthest shown element (320 + 90)")
-- a bar of another width must be repainted, not keep the old fill
eq(rowOf("martial").fill.w, 100, "fill still full width")
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 77, M.time, M.time + 5)
M.advance(2.5)
frame()
eq(rowOf("martial").fill.w, 50, "half-way through the effect the fill is half the new width")

addon:Set("posX", 40)
addon:Set("posY", -200)
eq(top().anchors[1].x, 40, "block x moved")
eq(top().anchors[1].y, -200, "block y moved")
addon:Set("scale", 150)
eq(top().scale, 1.5, "scale applied")

addon:Set("nameShow", false)
ok(rowOf("martial").name.hidden, "name hidden")
addon:Set("barShow", false)
ok(rowOf("martial").barBg.hidden, "bar hidden")
addon:Set("textShow", false)
ok(rowOf("martial").text.hidden, "text hidden")
eq(top().w, 1, "nothing shown: the block is a sliver, not a stale width")
addon:Set("nameShow", true)
addon:Set("barShow", true)
addon:Set("textShow", true)
ok(not rowOf("martial").name.hidden and not rowOf("martial").barBg.hidden and not rowOf("martial").text.hidden, "all back")

addon.sv.nameFont = 99
addon:ApplyLayout()
eq(rowOf("martial").name.font, "ZoFontGamepad22", "a font size the client has no font for falls back to 22")

addon:Reset()
r1 = rowOf("martial")
eq(r1.name.anchors[1].x, 0, "reset: name x")
eq(r1.barBg.w, 140, "reset: bar width")
eq(r1.text.font, "ZoFontGamepad22", "reset: text font")
eq(top().anchors[1].x, -905, "reset: block x")
eq(top().scale, 1, "reset: scale")
eq(rowOf("zen").control.anchors[1].y, 36, "reset: row height")
eq(next(addon.sv.hidden), nil, "reset: hidden sets cleared")

section("settings that change what is shown")
addon = boot()
wear("martial", 5)
addon:Set("combatOnly", true)
ok(top().hidden, "combat only: hidden out of combat")
M.fire(EVENT_PLAYER_COMBAT_STATE, true)
ok(not top().hidden, "combat only: shown in combat")
addon:Set("combatOnly", false)
addon:Set("enabled", false)
ok(top().hidden, "disabled: hidden")
addon:Set("enabled", true)
ok(not top().hidden, "enabled again")

section("preview shows three sample rows")
addon = boot()
addon:SetPreview(true)
ok(not top().hidden, "preview: window shown with nothing worn")
frame()
eq(#visibleRows(), 3, "three sample rows")
eq(rowAt(1).name.text, string.format(GetString(SI_PBSPST_SAMPLE_SET), 1), "sample name 1")
eq(rowAt(3).name.text, string.format(GetString(SI_PBSPST_SAMPLE_SET), 3), "sample name 3")
eq(rowAt(1).text.text, GetString(SI_PBSPST_PREVIEW_ROW), "sample row 1: active with a cooldown")
eq(rowAt(2).text.text, cdText(4.8), "sample row 2: cooldown")
eq(rowAt(3).text.text, GetString(SI_PBSPST_READY), "sample row 3: ready")
eq(rowAt(3).fill.w, 140, "sample bar uses the configured width")
addon:Set("barWidth", 200)
frame()
eq(rowAt(3).fill.w, 200, "and follows a change of it")
wear("martial", 5)
eq(#visibleRows(), 3, "worn sets do not add rows during a preview")
addon:SetPreview(false)
eq(#visibleRows(), 1, "preview off: the real row")
addon:SetPreview(true)
addon:SetPreview(false)
wear("martial", 0)
M.advance(3)
frame()
ok(top().hidden, "nothing worn, preview off: hidden")

section("the escape hatches: probe and bind")
addon = boot()
wear("nightmare", 5)
slash("probe")
effect(EFFECT_RESULT_GAINED, "Shards of Glass", 900100, 3, M.time, M.time + 3)
hit(ACTION_RESULT_DAMAGE, "Glass Burst", 900200)
effect(EFFECT_RESULT_GAINED, "Shards of Glass", 900100, 3, M.time, M.time + 3)
local probed = 0
for _, line in ipairs(M.chat) do
	if line:find("ProcSet probe", 1, true) then
		probed = probed + 1
	end
end
eq(probed, 2, "probe lists each unmatched ability once")
frame()
eq(rowOf("nightmare").text.text, GetString(SI_PBSPST_READY), "unmatched abilities start nothing")
slash("bind 900200 " .. SET.nightmare.id)
hit(ACTION_RESULT_DAMAGE, "Glass Burst", 900200)
frame()
ok(rowOf("nightmare").text.text:find(cdText(6.7), 1, true) ~= nil, "pinned ability now drives the set")
eq(addon.sv.bind[900200], 736, "pin saved")
slash("bind 900300 " .. setName("nightmare"):sub(1, 5))
eq(addon.sv.bind[900300], 736, "pin to a set by the start of its name")
slash("bind clear")
eq(next(addon.sv.bind), nil, "pins cleared")
slash("probe")
eq(M.listening(EVENT_EFFECT_CHANGED), 1, "probe off, set still worn: still listening")

section("slash commands print something sensible")
addon = boot()
wear("martial", 5)
wearId(9002, 3)
M.chat = {}
slash("status")
slash("text")
slash("text 9001")
slash("text nonesuch")
slash("sets")
slash("")
slash("bind nonsense")
local joined = table.concat(M.chat, "\n")
ok(joined:find("read from the text", 1, true) ~= nil, "status reports what was read")
ok(joined:find("1129", 1, true) == nil, "text prints only the worn sets by default (no Tarnished Nightmare line)")
ok(joined:find("Test Haste Set (id 9001)", 1, true) ~= nil, "text <id> prints a set that is not worn")
ok(joined:find("Major Courage", 1, true) ~= nil, "and its lines")
ok(joined:find("5-piece bonus", 1, true) ~= nil, "sets lists the row's bonus")
ok(joined:find("no time in any bonus text", 1, true) ~= nil, "sets explains the stat-only set")
print(joined)

section("settings panel builds and every setting reads and writes")
do
	local made = {}
	LibHarvensAddonSettings = {
		ST_SECTION = 1, ST_LABEL = 2, ST_CHECKBOX = 3, ST_SLIDER = 4, ST_BUTTON = 5, ST_DROPDOWN = 6,
		AddAddon = function(_, title)
			local panel = { title = title }
			function panel:AddSetting(setting)
				made[#made + 1] = setting
			end
			function panel:UpdateControls() end
			return panel
		end,
	}
	addon = boot()
	LibHarvensAddonSettings = nil
	local counts = { [3] = 0, [4] = 0, [5] = 0, [6] = 0 }
	for _, setting in ipairs(made) do
		ok(setting.label ~= nil and not tostring(setting.label):find("^<"), "label resolved: " .. tostring(setting.label))
		if setting.tooltip then
			ok(not tostring(setting.tooltip):find("^<"), "tooltip resolved: " .. tostring(setting.label))
		end
		counts[setting.type] = (counts[setting.type] or 0) + 1
		if setting.type == 3 or setting.type == 4 then
			local before = setting.getFunction()
			ok(before ~= nil, "getFunction returns a value: " .. tostring(setting.label))
			setting.setFunction(before)
			eq(setting.getFunction(), before, "set/get round trip: " .. tostring(setting.label))
			ok(setting.default ~= nil, "default present: " .. tostring(setting.label))
			if setting.type == 4 then
				ok(setting.min < setting.max and setting.step > 0, "slider range sane: " .. tostring(setting.label))
			end
		elseif setting.type == 6 then
			ok(#setting.items >= 5, "dropdown lists the font sizes")
			local last = setting.items[#setting.items]
			eq(last.data, 42, "largest font size offered")
			setting.setFunction(nil, last.name, last)
			eq(setting.getFunction(), last.name, "dropdown reads back the name it set")
			ok(setting.default == "22", "dropdown default names the default size")
		elseif setting.type == 5 then
			setting.clickHandler()
		end
	end
	eq(counts[4], 14, "fourteen sliders: block 4, name 3, bar 4, text 3")
	eq(counts[3], 8, "eight checkboxes: four display, preview, three element toggles")
	eq(counts[6], 2, "two font dropdowns")
	eq(counts[5], 1, "one reset button")
end

-- ======================================================================================
-- dump for the picture
section("screen dump")
addon = boot()
wear("martial", 5)
wear("zen", 5)
wear("nightmare", 5)
t0 = M.time
effect(EFFECT_RESULT_GAINED, AB.martial, 127070, 77, t0, t0 + 5)
effect(EFFECT_RESULT_GAINED, AB.zen, 126597, 5, t0 - 3, t0 + 17)
M.advance(5.5)
frame()
local dump = {}
for _, r in ipairs(visibleRows()) do
	dump[#dump + 1] = string.format(
		'{"name":%q,"text":%q,"w":%d,"color":[%s]}',
		r.name.text,
		r.text.text,
		r.fill.w or 0,
		table.concat(r.fill.color or { 0, 0, 0, 0 }, ",")
	)
end
-- DUMP=file.json lua run.lua jp   writes the rows for drawing; nothing is written otherwise
if os.getenv("DUMP") then
	local f = io.open(os.getenv("DUMP"), "w")
	f:write("[" .. table.concat(dump, ",") .. "]")
	f:close()
end
eq(#dump, 3, "three rows in the dump")

print(string.format("\n%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
