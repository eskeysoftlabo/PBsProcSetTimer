-- English, and the base every other language file overrides.
local strings = {
	SI_PBSPST_ACTIVE = "Active %.1f",
	SI_PBSPST_COOLDOWN = "CD %.1f",
	SI_PBSPST_READY = "Ready",
	SI_PBSPST_IDLE = "-",
	SI_PBSPST_AGO = "%.1fs ago",
	SI_PBSPST_PREVIEW_ROW = "Active 3.2  CD 4.8",
	SI_PBSPST_SAMPLE_SET = "Set name %d",

	SI_PBSPST_EXPLANATION = "Shows, for every set you wear that has a time in its bonus text, when the proc fires, how long it stays active and how long its cooldown has left. Nothing about any set is stored in the add-on: it reads the sets you wear and their bonus text from the game.",
	SI_PBSPST_SETS_HINT = "To drop a set from the display: /procset sets lists what you wear, /procset hide <id or part of the name> removes its row, /procset show brings it back.",

	SI_PBSPST_SECTION_DISPLAY = "Display",
	SI_PBSPST_ENABLED = "Show the timers",
	SI_PBSPST_ENABLED_TOOLTIP = "A row appears for each worn set whose bonus text has a time, while you wear enough pieces to switch that bonus on.",
	SI_PBSPST_COMBAT_ONLY = "Only in combat",
	SI_PBSPST_COMBAT_ONLY_TOOLTIP = "Hides the rows outside combat.",
	SI_PBSPST_ONLY_DETECTED = "Only sets whose proc was seen",
	SI_PBSPST_ONLY_DETECTED_TOOLTIP = "A row stays hidden until the set's proc has been detected once this session. Keeps the display short when you wear many sets, at the price of not seeing a set whose proc is not recognised.",
	SI_PBSPST_SOUND_READY = "Tick when the cooldown ends",
	SI_PBSPST_SOUND_READY_TOOLTIP = "Plays a short tick the moment a set's cooldown is over.",
	SI_PBSPST_PREVIEW = "Preview the rows",
	SI_PBSPST_PREVIEW_TOOLTIP = "Shows three sample rows so you can place and size the elements. Not saved.",

	SI_PBSPST_SECTION_BLOCK = "Whole display",
	SI_PBSPST_POS_X = "Horizontal position",
	SI_PBSPST_POS_X_TOOLTIP = "The top-left corner of the display, measured from the middle of the screen.",
	SI_PBSPST_POS_Y = "Vertical position",
	SI_PBSPST_POS_Y_TOOLTIP = "The top-left corner of the display, measured from the middle of the screen. Larger moves it down.",
	SI_PBSPST_SCALE = "Size (%)",
	SI_PBSPST_SCALE_TOOLTIP = "Scales everything together, from the top-left corner.",
	SI_PBSPST_ROW_HEIGHT = "Row height",
	SI_PBSPST_ROW_HEIGHT_TOOLTIP = "Distance between one set's row and the next.",

	SI_PBSPST_SECTION_NAME = "Set name",
	SI_PBSPST_SECTION_BAR = "Bar",
	SI_PBSPST_SECTION_TEXT = "Status text",
	SI_PBSPST_ELEM_SHOW = "Show",
	SI_PBSPST_ELEM_X = "Position, horizontal",
	SI_PBSPST_ELEM_X_TOOLTIP = "Distance from the left edge of the row.",
	SI_PBSPST_ELEM_Y = "Position, vertical",
	SI_PBSPST_ELEM_Y_TOOLTIP = "Distance from the vertical middle of the row. Larger moves it down.",
	SI_PBSPST_ELEM_WIDTH = "Width",
	SI_PBSPST_ELEM_HEIGHT = "Height",
	SI_PBSPST_ELEM_FONT = "Text size",

	SI_PBSPST_RESET = "Reset all settings",
	SI_PBSPST_RESET_BUTTON = "Reset",

	SI_PBSPST_LOADED = "PB's Proc Set Timer %s loaded. /procset for commands.",
	SI_PBSPST_HELP = "/procset on | off -- show or hide the rows\n/procset sets -- the sets you wear and whether each has a row\n/procset hide | show <set id or part of its name> -- take a set's row away or bring it back\n/procset status -- each row: timings read from the text, abilities matched\n/procset log -- what the worn sets did lately: bar swaps, piece counts, bonuses on and off\n/procset text [set id] -- the raw bonus lines of the worn sets (or of one set) and what was read from them\n/procset probe -- list every ability of yours seen while a set is worn (to find a proc that is not matched)\n/procset bind <abilityId> <set id or name> -- pin an ability to a set by hand; bind clear removes them\n/procset ignore <abilityId> -- never match this ability; ignore clear removes them\n/procset preview -- sample rows for placing the display",
	SI_PBSPST_ON = "Proc Set Timer on.",
	SI_PBSPST_OFF = "Proc Set Timer off.",
	SI_PBSPST_PROBE_ON = "Probe on: abilities of yours that match no set are listed once each.",
	SI_PBSPST_PROBE_OFF = "Probe off.",
	SI_PBSPST_PREVIEW_ON = "Preview on.",
	SI_PBSPST_PREVIEW_OFF = "Preview off.",
	SI_PBSPST_SET_NOT_FOUND = "No set matches '%s'. /procset sets lists the sets you wear.",
	SI_PBSPST_HIDE_DONE = "Hidden: %s (id %d). /procset show %d brings it back.",
	SI_PBSPST_SHOW_DONE = "Shown again: %s (id %d).",
	SI_PBSPST_BIND_DONE = "Pinned ability %d to %s.",
	SI_PBSPST_BIND_CLEARED = "All pinned abilities removed.",
	SI_PBSPST_BIND_USAGE = "Usage: /procset bind <abilityId> <set id or part of its name>   or   /procset bind clear",
	SI_PBSPST_IGNORE_DONE = "Ability %d will no longer be matched to any set.",
	SI_PBSPST_IGNORE_CLEARED = "All ignored abilities removed.",
	SI_PBSPST_IGNORE_USAGE = "Usage: /procset ignore <abilityId>   or   /procset ignore clear",
}

for stringId, stringValue in pairs(strings) do
	ZO_CreateStringId(stringId, stringValue)
	SafeAddVersion(stringId, 1)
end
