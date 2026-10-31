-- PB's Proc Set Timer -- reading a set's timings out of its own bonus text.
--
-- Nothing about a set's effect is kept in this add-on. The game already writes it down, in the
-- player's language, for the item tooltip:
--
--     GetItemSetInfo(setId)              -> hasSet, setName, numBonuses, ...
--     GetItemSetBonusInfo(setId, index)  -> numRequired, bonusDescription, ...
--
-- The description of the proc bonus carries every number we need ("for 5 seconds", "once every
-- 8 seconds"), so a balance patch changes the timers without touching this add-on.
--
-- ---------------------------------------------------------------------------------------
-- HOW A NUMBER OF SECONDS IS TOLD APART
-- ---------------------------------------------------------------------------------------
--
-- Every "<number> <seconds word>" is found first. Then each one is classified by the words
-- right around it, using cue lists for every language the game ships (they are all tried on
-- every text; a cue of one language never occurs in another):
--
--     cooldown  "once every 8 seconds"   "8秒に1回"      "alle 8 Sekunden"
--     delay     "after 1.3 seconds"      "1.3秒後"       "nach 1,3 Sekunden"
--     duration  "for 5 seconds"          "5秒間"         "für 5 Sekunden"
--
-- When no cue matches (a language whose wording is not covered, or a patch that rewords the
-- sentence) the position decides: the description ends with the cooldown sentence, so a time
-- that is still unclassified and comes after every other time is the cooldown. A text with a
-- single unclassified time keeps it as a duration.
--
-- /procset text prints the raw lines and what was read from them.

if not PBS_PROCSETTIMER then
	return
end

local addon = PBS_PROCSETTIMER

-- "second(s)" in every language of the client. CJK has the one character 秒 and no spaces.
local CJK_SECOND = "秒"
local SECOND_WORDS = {
	second = true,
	seconds = true,
	sekunde = true,
	sekunden = true,
	seconde = true,
	secondes = true,
	segundo = true,
	segundos = true,
	["секунда"] = true,
	["секунды"] = true,
	["секунду"] = true,
	["секунд"] = true,
}

-- Lua patterns. "before" cues are anchored to the END of the text before the number, "after"
-- cues to the START of the text after the unit; both sides are lower-cased first. No
-- multi-byte character may sit inside [...] -- a set matches single bytes, not characters.
local CUES = {
	cooldown = {
		before = {
			"once every%s*$",
			"once per%s*$",
			"every%s*$",
			"cooldown of%s*$",
			"alle%s*$",
			"abklingzeit von%s*$",
			"toutes les%s*$",
			"tous les%s*$",
			"cada%s*$",
			"раз в%s*$",
			"каждые%s*$",
			"每%s*$",
		},
		after = {
			"^%s*cooldown",
			"^%s*internal cooldown",
			"^%s*abklingzeit",
			"^%s*de recharge",
			"^%s*de reutilizaci",
			"^%s*перезарядк",
			"^に1回",
			"^に一回",
			"^に1度",
			"^に一度",
			"^ごと",
			"^毎",
			"^おき",
			"^間隔",
			"^の間隔",
			"^のクールダウン",
			"^クールダウン",
			"^冷却",
			"^的冷却",
		},
	},
	delay = {
		before = { "after%s*$", "nach%s*$", "après%s*$", "apres%s*$", "después de%s*$", "despues de%s*$", "через%s*$" },
		after = { "^後", "^后" },
	},
	duration = {
		before = { "for%s*$", "lasting%s*$", "für%s*$", "pendant%s*$", "durante%s*$" },
		after = { "^間", "^持続", "^内" },
	},
}
local CLASS_ORDER = { "cooldown", "delay", "duration" }

-- How much text on either side of a number is looked at for a cue.
local CONTEXT_BYTES = 32

-- Colour codes, texture tags and full-width digits would hide a number from the scan.
local function Normalize(text)
	text = text or ""
	text = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|t[^|]*|t", "")
	-- U+FF10..U+FF19 are EF BC 90..99, U+FF0E is EF BC 8E
	text = text:gsub("\239\188([\144-\153])", function(c)
		return string.char(c:byte() - 96)
	end)
	text = text:gsub("\239\188\142", ".")
	return text
end

local function Cued(list, str)
	for _, pattern in ipairs(list) do
		if str:find(pattern) then
			return true
		end
	end
	return false
end

local function Classify(before, after)
	for _, class in ipairs(CLASS_ORDER) do
		local cues = CUES[class]
		if Cued(cues.before, before) or Cued(cues.after, after) then
			return class
		end
	end
	return "unknown"
end

-- All "<number> <seconds>" in a text, in reading order.
local function ScanTimes(text)
	local hits = {}
	local pos = 1
	while true do
		local s, e, num = text:find("(%d+[%.,]?%d*)", pos)
		if not s then
			break
		end
		pos = e + 1

		local _, spaceEnd = text:find("^%s*", e + 1)
		local unitStart = spaceEnd + 1
		local unitEnd
		if text:sub(unitStart, unitStart + #CJK_SECOND - 1) == CJK_SECOND then
			unitEnd = unitStart + #CJK_SECOND - 1
		else
			local ws, we, word = text:find("^([%a\128-\255]+)", unitStart)
			if ws and SECOND_WORDS[word:lower()] then
				unitEnd = we
			end
		end

		if unitEnd then
			local seconds = tonumber((num:gsub(",", ".")))
			if seconds then
				local before = text:sub(zo_max(1, s - CONTEXT_BYTES), s - 1):lower()
				local after = text:sub(unitEnd + 1, unitEnd + CONTEXT_BYTES):lower()
				hits[#hits + 1] = { seconds = seconds, class = Classify(before, after) }
			end
			pos = unitEnd + 1
		end
	end
	return hits
end

-- text -> { cooldown = seconds|nil, duration = seconds|nil, delay = seconds|nil, hits = {...} }
function addon.ParseBonusText(text)
	local hits = ScanTimes(Normalize(text))

	local cooldown
	for _, hit in ipairs(hits) do
		if hit.class == "cooldown" then
			cooldown = hit
			break
		end
	end
	-- No cooldown phrase recognised: the closing time of a text with several is the cooldown.
	if not cooldown and #hits >= 2 and hits[#hits].class == "unknown" then
		cooldown = hits[#hits]
		cooldown.class = "cooldown"
		cooldown.inferred = true
	end

	local duration, delay
	for _, hit in ipairs(hits) do
		if hit ~= cooldown then
			if hit.class == "duration" and not duration then
				duration = hit
			elseif hit.class == "delay" and not delay then
				delay = hit
			end
		end
	end
	if not duration then
		for _, hit in ipairs(hits) do
			if hit ~= cooldown and hit.class == "unknown" then
				duration = hit
				duration.inferred = true
				break
			end
		end
	end

	return {
		cooldown = cooldown and cooldown.seconds or nil,
		duration = duration and duration.seconds or nil,
		delay = delay and delay.seconds or nil,
		inferred = (cooldown and cooldown.inferred) or (duration and duration.inferred) or false,
		hits = hits,
	}
end

addon.NormalizeText = Normalize

-- setId -> every bonus line of the set, each read for its timings; nil if the game has no such set.
--   bonuses[i] = {
--     index, required   the line's position and the pieces it needs
--     perfected         a Perfected-set bonus: counted against Perfected pieces only
--     text              the description, cleaned (the proc's own words, used to match events)
--     cooldown / duration / delay   seconds, or nil when the text does not say
--     inferred          a time was placed by its position, not by its wording
--     timed             the line has a cooldown or a duration, so it is worth a row
--   }
-- Which line a row follows is decided by the caller: the highest timed one that the worn
-- pieces switch on.
function addon.ReadSetEffect(setId)
	local hasSet, setName, numBonuses = GetItemSetInfo(setId)
	if not hasSet or not numBonuses or numBonuses < 1 then
		return nil
	end

	local bonuses = {}
	local anyTimed = false
	for index = 1, numBonuses do
		local required, description, perfected = GetItemSetBonusInfo(setId, index)
		local parsed = addon.ParseBonusText(description)
		local timed = parsed.cooldown ~= nil or parsed.duration ~= nil
		anyTimed = anyTimed or timed
		bonuses[index] = {
			index = index,
			required = required or 5,
			perfected = perfected and true or false,
			text = Normalize(description),
			parsed = parsed,
			cooldown = parsed.cooldown,
			duration = parsed.duration,
			delay = parsed.delay,
			inferred = parsed.inferred,
			timed = timed,
		}
	end
	return { setName = setName, bonuses = bonuses, timed = anyTimed }
end
