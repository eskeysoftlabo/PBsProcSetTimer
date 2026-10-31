-- A stand-in for the parts of the ESO API that PBsProcSetTimer touches, so the whole add-on can
-- be run offline in plain Lua (5.1 semantics; also runs under luajit).
--
-- Controls record what the add-on asks of them (text, colour, size, anchors, hidden) so a test
-- can read the screen back. A control's __index only invents CAPITALISED method names, so a
-- field the add-on stores on a control (row.lastText ...) stays nil until it is set.

local M = {}

M.time = 100 -- GetFrameTimeSeconds()
M.chat = {}
M.sounds = {}
M.controls = {}
M.events = {} -- [event] = { { ns =, cb = }, ... }
M.filters = {}
M.updates = {}

function M.advance(seconds)
	M.time = M.time + seconds
end

-- ---- strings ------------------------------------------------------------------------
local stringTable = {}
function ZO_CreateStringId(id, value)
	stringTable[id] = value
	_G[id] = id
end
function SafeAddVersion() end
function GetString(id)
	return stringTable[id] or ("<" .. tostring(id) .. ">")
end

-- ---- ZO helpers ---------------------------------------------------------------------
zo_floor = math.floor
zo_max = math.max
zo_min = math.min
function zo_strlower(s)
	return s:lower()
end
function zo_strtrim(s)
	return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end
function d(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	M.chat[#M.chat + 1] = table.concat(parts, " ")
end
SLASH_COMMANDS = {}
SOUNDS = { COUNTDOWN_TICK = "COUNTDOWN_TICK" }
function PlaySound(s)
	M.sounds[#M.sounds + 1] = s
end
function GetFrameTimeSeconds()
	return M.time
end
function GetFrameTimeMilliseconds()
	return M.time * 1000
end
function IsUnitInCombat()
	return M.inCombat or false
end

-- ---- constants ----------------------------------------------------------------------
local nextId = 0
local function const(name)
	nextId = nextId + 1
	_G[name] = nextId
end
for _, name in ipairs({
	"EVENT_ADD_ON_LOADED",
	"EVENT_PLAYER_ACTIVATED",
	"EVENT_PLAYER_COMBAT_STATE",
	"EVENT_INVENTORY_SINGLE_SLOT_UPDATE",
	"EVENT_ACTIVE_WEAPON_PAIR_CHANGED",
	"EVENT_EFFECT_CHANGED",
	"EVENT_COMBAT_EVENT",
	"REGISTER_FILTER_SOURCE_COMBAT_UNIT_TYPE",
	"REGISTER_FILTER_BAG_ID",
	"BAG_WORN",
	"ACTION_SLOT_TYPE_LIGHT_ATTACK",
	"ACTION_SLOT_TYPE_HEAVY_ATTACK",
	"ACTION_SLOT_TYPE_NOTHING",
	"ACTION_RESULT_DAMAGE",
	"ACTION_RESULT_CRITICAL_DAMAGE",
	"ACTION_RESULT_PRECISE_DAMAGE",
	"ACTION_RESULT_WRECKING_DAMAGE",
	"ACTION_RESULT_BLOCKED_DAMAGE",
	"ACTION_RESULT_DAMAGE_SHIELDED",
	"ACTION_RESULT_HEAL",
	"ACTION_RESULT_CRITICAL_HEAL",
	"ACTION_RESULT_POWER_ENERGIZE",
	"ACTION_RESULT_DOT_TICK",
	"ACTION_RESULT_DOT_TICK_CRITICAL",
	"ACTION_RESULT_HOT_TICK",
	"CT_CONTROL",
	"CT_LABEL",
	"CT_TEXTURE",
	"LEFT",
	"RIGHT",
	"CENTER",
	"TOPLEFT",
	"TEXT_ALIGN_CENTER",
	"TEXT_ALIGN_RIGHT",
	"TEXT_WRAP_MODE_ELLIPSIS",
}) do
	const(name)
end
EFFECT_RESULT_GAINED = 1
EFFECT_RESULT_FADED = 2
EFFECT_RESULT_UPDATED = 3
COMBAT_UNIT_TYPE_NONE = 0
COMBAT_UNIT_TYPE_PLAYER = 1
COMBAT_UNIT_TYPE_GROUP = 6

-- ---- events -------------------------------------------------------------------------
EVENT_MANAGER = {}
function EVENT_MANAGER:RegisterForEvent(ns, event, cb)
	M.events[event] = M.events[event] or {}
	local list = M.events[event]
	for i, entry in ipairs(list) do
		if entry.ns == ns then
			list[i] = { ns = ns, cb = cb }
			return
		end
	end
	list[#list + 1] = { ns = ns, cb = cb }
end
function EVENT_MANAGER:UnregisterForEvent(ns, event)
	local list = M.events[event] or {}
	for i = #list, 1, -1 do
		if list[i].ns == ns then
			table.remove(list, i)
		end
	end
end
function EVENT_MANAGER:AddFilterForEvent(ns, event, filterType, value)
	M.filters[ns .. ":" .. event] = { filterType, value }
end
function EVENT_MANAGER:RegisterForUpdate(ns, ms, cb)
	M.updates[ns] = { ms = ms, cb = cb }
end
function M.fire(event, ...)
	local list = M.events[event] or {}
	local copy = {}
	for i, entry in ipairs(list) do
		copy[i] = entry
	end
	for _, entry in ipairs(copy) do
		entry.cb(event, ...)
	end
end
function M.listening(event)
	return #(M.events[event] or {})
end

-- ---- controls -----------------------------------------------------------------------
local Control = {}
Control.__index = function(self, key)
	if type(key) == "string" and key:match("^[A-Z]") then
		return Control[key] or function() end
	end
	return nil
end
function Control:SetText(text)
	self.text = text
end
function Control:SetHidden(hidden)
	self.hidden = hidden
end
function Control:IsHidden()
	return self.hidden
end
function Control:SetDimensions(w, h)
	self.w, self.h = w, h
end
function Control:SetColor(r, g, b, a)
	self.color = { r, g, b, a }
end
function Control:SetFont(font)
	self.font = font
end
function Control:ClearAnchors()
	self.anchors = {}
end
function Control:SetAnchor(point, rel, relPoint, x, y)
	self.anchors = self.anchors or {}
	self.anchors[#self.anchors + 1] = { point = point, rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 }
end
function Control:SetHandler(name, fn)
	self.handlers = self.handlers or {}
	self.handlers[name] = fn
end
function Control:SetScale(scale)
	self.scale = scale
end
function Control:SetDrawLevel(level)
	self.drawLevel = level
end

WINDOW_MANAGER = {}
local function newControl(name, parent, kind)
	if parent and name:find("$(parent)", 1, true) then
		name = name:gsub("%$%(parent%)", parent.name)
	end
	local c = setmetatable({ name = name, parent = parent, kind = kind, children = {}, hidden = false }, Control)
	if parent then
		parent.children[#parent.children + 1] = c
	end
	M.controls[name] = c
	return c
end
function WINDOW_MANAGER:CreateTopLevelWindow(name)
	return newControl(name, nil, "top")
end
function WINDOW_MANAGER:CreateControl(name, parent, kind)
	return newControl(name, parent, kind)
end
GuiRoot = newControl("GuiRoot", nil, "root")

local function scene()
	local s = { callbacks = {}, showing = false }
	function s:RegisterCallback(_, cb)
		self.callbacks[#self.callbacks + 1] = cb
	end
	function s:IsShowing()
		return self.showing
	end
	function s:Set(showing)
		self.showing = showing
		for _, cb in ipairs(self.callbacks) do
			cb(nil, showing and "showing" or "hidden")
		end
	end
	return s
end
HUD_SCENE = scene()
HUD_UI_SCENE = scene()

-- ---- the add-on manager: the real manifest of the add-on under test ---------------------
function GetAddOnManager()
	return {
		GetNumAddOns = function()
			return 2
		end,
		GetAddOnInfo = function(_, index)
			if index == 1 then
				return "SomeOtherAddOn", "Some Other Add-On 9.9"
			end
			local file = io.open("../PBsProcSetTimer/PBsProcSetTimer.addon")
			local text = file and file:read("*a") or ""
			if file then
				file:close()
			end
			return "PBsProcSetTimer", text:match("## Title:%s*([^\n]*)")
		end,
	}
end

-- ---- the client's callback manager and scene states -----------------------------------
M.callbacks = {}
CALLBACK_MANAGER = {
	RegisterCallback = function(_, name, fn)
		M.callbacks[name] = M.callbacks[name] or {}
		table.insert(M.callbacks[name], fn)
	end,
	FireCallbacks = function(_, name, ...)
		-- the client passes the arguments of the call, not the callback's name
		for _, fn in ipairs(M.callbacks[name] or {}) do
			fn(...)
		end
	end,
}
SCENE_SHOWN = "shown"
SCENE_HIDING = "hiding"

-- ---- saved variables ----------------------------------------------------------------
local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = deepCopy(v)
	end
	return out
end
ZO_SavedVars = {}
-- M.persist, when set, is the saved data of an earlier session: it is kept across boots, and keys
-- it lacks are filled from the defaults the way ZO_SavedVars does.
M.persist = nil
function ZO_SavedVars:NewAccountWide(_, _, _, defaults)
	if M.persist then
		for key, value in pairs(defaults) do
			if M.persist[key] == nil then
				M.persist[key] = deepCopy(value)
			end
		end
		return M.persist
	end
	return deepCopy(defaults)
end

-- ---- equipment and item sets --------------------------------------------------------
-- M.sets[setId] = { name =, max = 5, bonuses = { { required, text, perfected }, ... } }
-- M.worn[slot] = setId (or nil)
-- M.perfected[setId] = how many of the worn pieces of that set are Perfected ones
M.sets = {}
M.worn = {}
M.perfected = {}
M.WORN_SLOTS = 20

function GetBagSize()
	return M.WORN_SLOTS
end
function GetItemLink(_, slot)
	local setId = M.worn[slot]
	return setId and ("|H1:item:" .. setId .. ":" .. slot .. "|h|h") or ""
end
local function wornCount(setId)
	local n = 0
	for _, id in pairs(M.worn) do
		if id == setId then
			n = n + 1
		end
	end
	return n
end
-- the item tooltip's call: has set, name, bonuses, normal pieces, max, set id, perfected pieces
function GetItemLinkSetInfo(link)
	local setId = tonumber(link:match("item:(%d+):"))
	local set = M.sets[setId]
	if not set then
		return false, "", 0, 0, 0, 0, 0
	end
	local perfected = M.perfected[setId] or 0
	return true, set.name, #set.bonuses, wornCount(setId) - perfected, set.max or 5, setId, perfected
end
function GetItemSetInfo(setId)
	local set = M.sets[setId]
	if not set then
		return false, "", 0, 0, 0, 0
	end
	return true, set.name, #set.bonuses, wornCount(setId), M.perfected[setId] or 0, set.max or 5
end
-- what the game says an ability does: M.abilityText[abilityId] = "..."
M.abilityText = {}
function GetAbilityDescription(abilityId)
	return M.abilityText[abilityId] or ""
end
function GetItemSetName(setId)
	local set = M.sets[setId]
	return set and set.name or ""
end
function GetItemSetBonusInfo(setId, index)
	local bonus = M.sets[setId].bonuses[index]
	return bonus[1], bonus[2], bonus[3] or false
end

function M.wear(setId, count)
	-- clear this set's slots and refill
	for slot, id in pairs(M.worn) do
		if id == setId then
			M.worn[slot] = nil
		end
	end
	local placed = 0
	for slot = 0, M.WORN_SLOTS - 1 do
		if placed >= count then
			break
		end
		if not M.worn[slot] then
			M.worn[slot] = setId
			placed = placed + 1
		end
	end
end

return M
