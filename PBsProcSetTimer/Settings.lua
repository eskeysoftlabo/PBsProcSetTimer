-- PB's Proc Set Timer -- the settings panel (LibHarvensAddonSettings, optional)
--
-- PBS_PROCSETTIMER is nil if Main.lua bailed out early (e.g. already loaded).
if not PBS_PROCSETTIMER then
	return
end

local addon = PBS_PROCSETTIMER

function addon:InitSettings()
	local LHAS = LibHarvensAddonSettings
	if not LHAS then
		return
	end

	local settings = LHAS:AddAddon(self.title)
	if not settings then
		return
	end
	settings.allowDefaults = true
	settings.author = self.author
	settings.version = self.version

	local function Heading(label)
		settings:AddSetting({ type = LHAS.ST_SECTION or LHAS.ST_LABEL, label = GetString(label) })
	end

	local function Checkbox(key, label, tooltip)
		settings:AddSetting(
			{
				type = LHAS.ST_CHECKBOX,
				label = GetString(label),
				tooltip = tooltip and GetString(tooltip) or nil,
				default = self.DEFAULTS[key],
				getFunction = function()
					return self.sv[key]
				end,
				setFunction = function(value)
					self:Set(key, value)
				end
			}
		)
	end

	local function Slider(key, label, tooltip, min, max, step)
		settings:AddSetting(
			{
				type = LHAS.ST_SLIDER,
				label = GetString(label),
				tooltip = tooltip and GetString(tooltip) or nil,
				min = min,
				max = max,
				step = step,
				default = self.DEFAULTS[key],
				getFunction = function()
					return self.sv[key]
				end,
				setFunction = function(value)
					self:Set(key, value)
				end
			}
		)
	end

	-- The sizes of the gamepad fonts the client has; the stored value is the size itself.
	local function FontSize(key)
		local items = {}
		for _, size in ipairs(self.FONT_SIZES) do
			items[#items + 1] = { name = tostring(size), data = size }
		end
		settings:AddSetting(
			{
				type = LHAS.ST_DROPDOWN,
				label = GetString(SI_PBSPST_ELEM_FONT),
				items = items,
				default = tostring(self.DEFAULTS[key]),
				getFunction = function()
					return tostring(self.sv[key])
				end,
				setFunction = function(_, _, item)
					self:Set(key, item.data)
				end
			}
		)
	end

	-- One element of a row: shown or not, where, and how big.
	--   prefix  "name" | "bar" | "text", the start of its saved-variable keys
	--   sizes   which of width / height / font the element has
	local function Element(prefix, section, sizes)
		Heading(section)
		Checkbox(prefix .. "Show", SI_PBSPST_ELEM_SHOW)
		Slider(prefix .. "X", SI_PBSPST_ELEM_X, SI_PBSPST_ELEM_X_TOOLTIP, -300, 1200, 2)
		Slider(prefix .. "Y", SI_PBSPST_ELEM_Y, SI_PBSPST_ELEM_Y_TOOLTIP, -60, 60, 1)
		Slider(prefix .. "Width", SI_PBSPST_ELEM_WIDTH, nil, 20, 700, 5)
		if sizes.height then
			Slider(prefix .. "Height", SI_PBSPST_ELEM_HEIGHT, nil, 2, 60, 1)
		end
		if sizes.font then
			FontSize(prefix .. "Font")
		end
	end

	settings:AddSetting({ type = LHAS.ST_LABEL, label = GetString(SI_PBSPST_EXPLANATION) })
	settings:AddSetting({ type = LHAS.ST_LABEL, label = GetString(SI_PBSPST_SETS_HINT) })

	Heading(SI_PBSPST_SECTION_DISPLAY)
	Checkbox("enabled", SI_PBSPST_ENABLED, SI_PBSPST_ENABLED_TOOLTIP)
	Checkbox("combatOnly", SI_PBSPST_COMBAT_ONLY, SI_PBSPST_COMBAT_ONLY_TOOLTIP)
	Checkbox("onlyDetected", SI_PBSPST_ONLY_DETECTED, SI_PBSPST_ONLY_DETECTED_TOOLTIP)
	Checkbox("soundReady", SI_PBSPST_SOUND_READY, SI_PBSPST_SOUND_READY_TOOLTIP)
	settings:AddSetting(
		{
			type = LHAS.ST_CHECKBOX,
			label = GetString(SI_PBSPST_PREVIEW),
			tooltip = GetString(SI_PBSPST_PREVIEW_TOOLTIP),
			default = false,
			getFunction = function()
				return self.preview
			end,
			setFunction = function(value)
				self:SetPreview(value)
			end
		}
	)

	Heading(SI_PBSPST_SECTION_BLOCK)
	Slider("posX", SI_PBSPST_POS_X, SI_PBSPST_POS_X_TOOLTIP, -960, 960, 5)
	Slider("posY", SI_PBSPST_POS_Y, SI_PBSPST_POS_Y_TOOLTIP, -540, 540, 5)
	Slider("scale", SI_PBSPST_SCALE, SI_PBSPST_SCALE_TOOLTIP, 50, 200, 5)
	Slider("rowHeight", SI_PBSPST_ROW_HEIGHT, SI_PBSPST_ROW_HEIGHT_TOOLTIP, 16, 80, 2)

	Element("name", SI_PBSPST_SECTION_NAME, { font = true })
	Element("bar", SI_PBSPST_SECTION_BAR, { height = true })
	Element("text", SI_PBSPST_SECTION_TEXT, { font = true })

	settings:AddSetting(
		{
			type = LHAS.ST_BUTTON,
			label = GetString(SI_PBSPST_RESET),
			buttonText = GetString(SI_PBSPST_RESET_BUTTON),
			clickHandler = function()
				self:Reset()
				if settings.UpdateControls then
					settings:UpdateControls()
				end
			end
		}
	)
end
