local ADDON = ...
local Functions = CogWheel("LibDB"):GetDatabase(ADDON..": Functions")
local Auras = CogWheel("LibDB"):GetDatabase(ADDON..": Auras")
local Colors = CogWheel("LibDB"):GetDatabase(ADDON..": Colors")
local Fonts = CogWheel("LibDB"):GetDatabase(ADDON..": Fonts")
local UnitFrameStyles = CogWheel("LibDB"):NewDatabase(ADDON..": UnitFrameStyles")

-- Lua API
local _G = _G
local unpack = unpack
local string_format = string.format

-- WoW API
local UnitIsPlayer = _G.UnitIsPlayer
local UnitIsUnit = _G.UnitIsUnit
local UnitLevel = _G.UnitLevel

-- WoW Strings
local S_DEAD = _G.DEAD
local S_PLAYER_OFFLINE = _G.PLAYER_OFFLINE

-- Speed shortcuts
local GetMediaPath = Functions.GetMediaPath

-----------------------------------------------------------
-- Callbacks
-----------------------------------------------------------

local OverrideValue = function(element, unit, min, max, disconnected, dead, tapped)
	if (min >= 1e8) then 		element.Value:SetFormattedText("%dm", min/1e6) 		-- 100m, 1000m, 2300m, etc
	elseif (min >= 1e6) then 	element.Value:SetFormattedText("%.1fm", min/1e6) 	-- 1.0m - 99.9m 
	elseif (min >= 1e5) then 	element.Value:SetFormattedText("%dk", min/1e3) 		-- 100k - 999k
	elseif (min >= 1e3) then 	element.Value:SetFormattedText("%.1fk", min/1e3) 	-- 1.0k - 99.9k
	elseif (min > 0) then 		element.Value:SetText(min) 							-- 1 - 999
	else 						element.Value:SetText("")
	end 
end 

local OverrideHealthValue = function(element, unit, min, max, disconnected, dead, tapped)
	if disconnected then 
		if element.Value then 
			element.Value:SetText(S_PLAYER_OFFLINE)
		end 
	elseif dead then 
		if element.Value then 
			return element.Value:SetText(S_DEAD)
		end
	else 
		if element.Value then 
			return OverrideValue(element, unit, min, max, disconnected, dead, tapped)
		end 
	end 
end 

local PostCreateAuraButton_Small = function(element, button)
	
	-- Downscale factor of the border backdrop
	local sizeMod = 2/4


	-- Restyle original elements
	----------------------------------------------------

	-- Spell icon
	-- We inset the icon, so the border aligns with the button edge
	local icon = button.Icon
	icon:SetTexCoord(5/64, 59/64, 5/64, 59/64)
	icon:ClearAllPoints()
	icon:SetPoint("TOPLEFT", 9*sizeMod, -9*sizeMod)
	icon:SetPoint("BOTTOMRIGHT", -9*sizeMod, 9*sizeMod)

	-- Aura stacks
	local count = button.Count
	count:SetFontObject(Fonts(11, true))
	count:ClearAllPoints()
	count:SetPoint("BOTTOMRIGHT", 2, -2)

	-- Aura time remaining
	local time = button.Time
	time:SetFontObject(Fonts(11, true))


	-- Create custom elements
	----------------------------------------------------

	-- Retrieve the icon drawlayer, and put our darkener right above
	local iconDrawLayer, iconDrawLevel = icon:GetDrawLayer()

	-- Darken the icons slightly, don't want them too bright
	local darken = button:CreateTexture()
	darken:SetDrawLayer(iconDrawLayer, iconDrawLevel + 1)
	darken:SetSize(icon:GetSize())
	darken:SetAllPoints(icon)
	darken:SetColorTexture(0, 0, 0, .25)

	-- Create our own custom border.
	-- Using our new thick tooltip border, just scaled down slightly.
	sizeMod = 1/4

	local border = button.Overlay:CreateFrame("Frame")
	border:SetPoint("TOPLEFT", -8 *sizeMod, 8*sizeMod)
	border:SetPoint("BOTTOMRIGHT", 8 *sizeMod, -8 *sizeMod)
	border:SetBackdrop({
		edgeFile = GetMediaPath("tooltip_border"),
		edgeSize = 32 *sizeMod
	})
	border:SetBackdropBorderColor(Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3])

	-- This one we reference, for magic school coloring later on
	button.Border = border

end

-- Anything to post update at all?
local PostUpdateAuraButton_Small = function(element, button)
end

local PostUpdateAlpha = function(self)
	local unit = self.unit
	if (not unit) then 
		return 
	end 

	local CURRENT_STYLE

	-- Hide it when tot is the same as the target
	if self.hideWhenUnitIsPlayer and (UnitIsUnit(unit, "player")) then 
		CURRENT_STYLE = "Hidden"

	elseif self.hideWhenUnitIsTarget and (UnitIsUnit(unit, "target")) then 
		CURRENT_STYLE = "Hidden"

	elseif self.hideWhenTargetIsCritter then 
		local level = UnitLevel("target")
		if ((level and level == 1) and (not UnitIsPlayer("target"))) then 
			CURRENT_STYLE = "Hidden"
		else 
			CURRENT_STYLE = "Shown"
		end 
	else 
		CURRENT_STYLE = "Shown"
	end 

	-- Silently return if there was no change
	if (CURRENT_STYLE == self.alphaStyle) then 
		return 
	end 

	-- Store the new style
	self.alphaStyle = CURRENT_STYLE

	-- Apply the new style
	if (CURRENT_STYLE == "Shown") then 
		self:SetAlpha(1)
	elseif (CURRENT_STYLE == "Hidden") then 
		self:SetAlpha(0)
	end
end

-----------------------------------------------------------
-- Style Templates
-----------------------------------------------------------

-- Small frames (pet, tot, focus, boss, arena)
UnitFrameStyles.StyleSmallFrame = function(self, unit, id, Layout, ...)

	-- Frame
	-----------------------------------------------------------
	self:SetSize(unpack(Layout.Size)) 

	-- Todo: iterate on this for a grid layout
	local id = tonumber(id)
	if id then 
		local place = { unpack(Layout.Place) }
		local growthX = Layout.GrowthX
		local growthY = Layout.GrowthY

		if (growthX and growthY) then 
			if (type(place[#place]) == "number") then 
				place[#place - 1] = place[#place - 1] + growthX*(id-1)
				place[#place] = place[#place] + growthY*(id-1)
			else 
				place[#place + 1] = growthX
				place[#place + 1] = growthY
			end 
		end 

		self:Place(unpack(place))
	else 
		self:Place(unpack(Layout.Place)) 
	end

	if Layout.FrameLevel then 
		self:SetFrameLevel(self:GetFrameLevel() + Layout.FrameLevel)
	end 

	if Layout.HitRectInsets then 
		self:SetHitRectInsets(unpack(Layout.HitRectInsets))
	else 
		self:SetHitRectInsets(0, 0, 0, 0)
	end 

	-- Assign our own global custom colors
	self.colors = Colors


	-- Scaffolds
	-----------------------------------------------------------
	-- frame to contain art backdrops, shadows, etc
	local backdrop = self:CreateFrame("Frame")
	backdrop:SetAllPoints()
	backdrop:SetFrameLevel(self:GetFrameLevel())
	
	-- frame to contain bars, icons, etc
	local content = self:CreateFrame("Frame")
	content:SetAllPoints()
	content:SetFrameLevel(self:GetFrameLevel() + 5)

	-- frame to contain art overlays, texts, etc
	local overlay = self:CreateFrame("Frame")
	overlay:SetAllPoints()
	overlay:SetFrameLevel(self:GetFrameLevel() + 10)


	-- Border
	-----------------------------------------------------------	
	if Layout.UseBorderBackdrop then 
		local border = self:CreateFrame("Frame")
		border:SetFrameLevel(self:GetFrameLevel() + 8)
		border:SetSize(unpack(Layout.BorderFrameSize))
		border:Place(unpack(Layout.BorderFramePlace))
		border:SetBackdrop(Layout.BorderFrameBackdrop)
		border:SetBackdropColor(unpack(Layout.BorderFrameBackdropColor))
		border:SetBackdropBorderColor(unpack(Layout.BorderFrameBackdropBorderColor))
		self.Border = border
	end 

	-- Health Bar
	-----------------------------------------------------------	
	local health 

	if (Layout.HealthType == "Orb") then 
		health = content:CreateOrb()

	elseif (Layout.HealthType == "SpinBar") then 
		health = content:CreateSpinBar()

	else 
		health = content:CreateStatusBar()
		health:SetOrientation(Layout.HealthBarOrientation or "RIGHT") 
		health:SetFlippedHorizontally(Layout.HealthBarSetFlippedHorizontally)
		if Layout.HealthBarSparkMap then 
			health:SetSparkMap(Layout.HealthBarSparkMap) -- set the map the spark follows along the bar.
		end 
	end 
	if (not Layout.UseProgressiveFrames) then 
		health:SetStatusBarTexture(Layout.HealthBarTexture)
		health:SetSize(unpack(Layout.HealthSize))
	end 

	health:Place(unpack(Layout.HealthPlace))
	health:SetSmoothingMode(Layout.HealthSmoothingMode or "bezier-fast-in-slow-out") -- set the smoothing mode.
	health:SetSmoothingFrequency(Layout.HealthSmoothingFrequency or .5) -- set the duration of the smoothing.
	health.colorTapped = Layout.HealthColorTapped  -- color tap denied units 
	health.colorDisconnected = Layout.HealthColorDisconnected -- color disconnected units
	health.colorClass = Layout.HealthColorClass -- color players by class 
	health.colorPetAsPlayer = Layout.HealthColorPetAsPlayer -- color your pet as you
	health.colorReaction = Layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorHealth = Layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = Layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates

	self.Health = health
	self.Health.PostUpdate = Layout.HealthBarPostUpdate
	
	if Layout.UseHealthBackdrop then 
		local healthBg = health:CreateTexture()
		healthBg:SetDrawLayer(unpack(Layout.HealthBackdropDrawLayer))
		healthBg:SetSize(unpack(Layout.HealthBackdropSize))
		healthBg:SetPoint(unpack(Layout.HealthBackdropPlace))
		if (not Layout.UseProgressiveFrames) then 
			healthBg:SetTexture(Layout.HealthBackdropTexture)
		end 
		if Layout.HealthBackdropColor then 
			healthBg:SetVertexColor(unpack(Layout.HealthBackdropColor))
		end
		self.Health.Bg = healthBg
	end 

	if Layout.UseHealthForeground then 
		local healthFg = health:CreateTexture()
		healthFg:SetDrawLayer("BORDER", 1)
		healthFg:SetSize(unpack(Layout.HealthForegroundSize))
		healthFg:SetPoint(unpack(Layout.HealthForegroundPlace))
		healthFg:SetTexture(Layout.HealthForegroundTexture)
		healthFg:SetDrawLayer(unpack(Layout.HealthForegroundDrawLayer))
		if Layout.HealthForegroundColor then 
			healthFg:SetVertexColor(unpack(Layout.HealthForegroundColor))
		end 
		self.Health.Fg = healthFg
	end 

	-- Absorb Bar
	-----------------------------------------------------------	
	if Layout.UseAbsorbBar then 
		local absorb = content:CreateStatusBar()
		absorb:SetFrameLevel(health:GetFrameLevel() + 1)
		absorb:Place(unpack(Layout.AbsorbBarPlace))
		absorb:SetOrientation(Layout.AbsorbBarOrientation) -- grow the bar towards the left (grows from the end of the health)
		absorb:SetFlippedHorizontally(Layout.AbsorbBarSetFlippedHorizontally)

		if (not Layout.UseProgressiveFrames) then
			absorb:SetSize(unpack(Layout.AbsorbSize))
			absorb:SetStatusBarTexture(Layout.AbsorbBarTexture)
		end

		if Layout.AbsorbBarSparkMap then 
			absorb:SetSparkMap(Layout.AbsorbBarSparkMap) -- set the map the spark follows along the bar.
		end 

		absorb:SetStatusBarColor(unpack(Layout.AbsorbBarColor)) -- make the bar fairly transparent, it's just an overlay after all. 
		self.Absorb = absorb
	end 

	-- Power 
	-----------------------------------------------------------
	if Layout.UsePowerBar then 
		local power = backdrop:CreateStatusBar()
		power:SetSize(unpack(Layout.PowerSize))
		power:Place(unpack(Layout.PowerPlace))
		power:SetStatusBarTexture(Layout.PowerBarTexture)
		power:SetTexCoord(unpack(Layout.PowerBarTexCoord))
		power:SetOrientation(Layout.PowerBarOrientation or "RIGHT") -- set the bar to grow towards the top.
		power:SetSmoothingMode(Layout.PowerBarSmoothingMode) -- set the smoothing mode.
		power:SetSmoothingFrequency(Layout.PowerBarSmoothingFrequency or .5) -- set the duration of the smoothing.

		if Layout.PowerBarSparkMap then 
			power:SetSparkMap(Layout.PowerBarSparkMap) -- set the map the spark follows along the bar.
		end 

		power.ignoredResource = Layout.PowerIgnoredResource -- make the bar hide when MANA is the primary resource. 

		self.Power = power
		self.Power.OverrideColor = OverridePowerColor

		if Layout.UsePowerBackground then 
			local powerBg = power:CreateTexture()
			powerBg:SetDrawLayer(unpack(Layout.PowerBackgroundDrawLayer))
			powerBg:SetSize(unpack(Layout.PowerBackgroundSize))
			powerBg:SetPoint(unpack(Layout.PowerBackgroundPlace))
			powerBg:SetTexture(Layout.PowerBackgroundTexture)
			powerBg:SetVertexColor(unpack(Layout.PowerBackgroundColor)) 
			self.Power.Bg = powerBg
		end

		if Layout.UsePowerForeground then 
			local powerFg = power:CreateTexture()
			powerFg:SetSize(unpack(Layout.PowerForegroundSize))
			powerFg:SetPoint(unpack(Layout.PowerForegroundPlace))
			powerFg:SetDrawLayer(unpack(Layout.PowerForegroundDrawLayer))
			powerFg:SetTexture(Layout.PowerForegroundTexture)
			self.Power.Fg = powerFg
		end
	end 

	-- Cast Bar
	-----------------------------------------------------------
	if Layout.UseCastBar then
		local cast = content:CreateStatusBar()
		cast:SetSize(unpack(Layout.CastBarSize))
		cast:SetFrameLevel(health:GetFrameLevel() + 1)
		cast:Place(unpack(Layout.CastBarPlace))
		cast:SetOrientation(Layout.CastBarOrientation) -- set the bar to grow towards the right.
		cast:SetSmoothingMode(Layout.CastBarSmoothingMode) -- set the smoothing mode.
		cast:SetSmoothingFrequency(Layout.CastBarSmoothingFrequency)
		cast:SetStatusBarColor(unpack(Layout.CastBarColor)) -- the alpha won't be overwritten. 

		if (not Layout.UseProgressiveFrames) then 
			cast:SetStatusBarTexture(Layout.CastBarTexture)
		end 

		if Layout.CastBarSparkMap then 
			cast:SetSparkMap(Layout.CastBarSparkMap) -- set the map the spark follows along the bar.
		end

		self.Cast = cast
		self.Cast.PostUpdate = Layout.CastBarPostUpdate
	end 


	-- Auras
	-----------------------------------------------------------
	if Layout.UseAuras then 
		local auras = content:CreateFrame("Frame")
		auras:Place(unpack(Layout.AuraFramePlace))
		auras:SetSize(unpack(Layout.AuraFrameSize)) -- auras will be aligned in the available space, this size gives us 8x1 auras
		auras.auraSize = Layout.AuraSize -- size of the aura. assuming squares. 
		auras.spacingH = Layout.AuraSpaceH -- horizontal/column spacing between buttons
		auras.spacingV = Layout.AuraSpaceV -- vertical/row spacing between aura buttons
		auras.growthX = Layout.AuraGrowthX -- auras grow to the left
		auras.growthY = Layout.AuraGrowthY -- rows grow downwards (we just have a single row, though)
		auras.maxVisible = Layout.AuraMax -- when set will limit the number of buttons regardless of space available
		auras.maxBuffs = Layout.AuraMaxBuffs -- maximum number of visible buffs
		auras.maxDebuffs = Layout.AuraMaxDebuffs -- maximum number of visible debuffs
		auras.debuffsFirst = Layout.AuraDebuffsFirst -- show debuffs before buffs
		auras.showCooldownSpiral = Layout.ShowAuraCooldownSpirals -- don't show the spiral as a timer
		auras.showCooldownTime = Layout.ShowAuraCooldownTime -- show timer numbers
		auras.auraFilter = Layout.AuraFilter -- general aura filter, only used if the below aren't here
		auras.buffFilter = Layout.AuraBuffFilter -- buff specific filter passed to blizzard API calls
		auras.debuffFilter = Layout.AuraDebuffFilter -- debuff specific filter passed to blizzard API calls
		auras.AuraFilter = Layout.AuraFilterFunc -- general aura filter function, called when the below aren't there
		auras.BuffFilter = Layout.BuffFilterFunc -- buff specific filter function
		auras.DebuffFilter = Layout.DebuffFilterFunc -- debuff specific filter function
		auras.tooltipDefaultPosition = Layout.AuraTooltipDefaultPosition
		auras.tooltipPoint = Layout.AuraTooltipPoint
		auras.tooltipAnchor = Layout.AuraTooltipAnchor
		auras.tooltipRelPoint = Layout.AuraTooltipRelPoint
		auras.tooltipOffsetX = Layout.AuraTooltipOffsetX
		auras.tooltipOffsetY = Layout.AuraTooltipOffsetY
			
		self.Auras = auras
		self.Auras.PostCreateButton = PostCreateAuraButton_Small -- post creation styling
		self.Auras.PostUpdateButton = PostUpdateAuraButton_Small -- post updates when something changes (even timers)
	end 

	if Layout.UseBuffs then 
		local buffs = content:CreateFrame("Frame")
		buffs:Place(unpack(Layout.BuffFramePlace))
		buffs:SetSize(unpack(Layout.BuffFrameSize)) -- auras will be aligned in the available space, this size gives us 8x1 auras
		buffs.auraSize = Layout.BuffSize -- size of the aura. assuming squares. 
		buffs.spacingH = Layout.BuffSpaceH -- horizontal/column spacing between buttons
		buffs.spacingV = Layout.BuffSpaceV -- vertical/row spacing between aura buttons
		buffs.growthX = Layout.BuffGrowthX -- auras grow to the left
		buffs.growthY = Layout.BuffGrowthY -- rows grow downwards (we just have a single row, though)
		buffs.maxVisible = Layout.BuffMax -- when set will limit the number of buttons regardless of space available
		buffs.showCooldownSpiral = Layout.ShowBuffCooldownSpirals -- don't show the spiral as a timer
		buffs.showCooldownTime = Layout.ShowBuffCooldownTime -- show timer numbers
		buffs.debuffFilter = Layout.BuffFilter -- general aura filter, only used if the below aren't here
		buffs.BuffFilter = Layout.BuffFilterFunc -- general aura filter function, called when the below aren't there
		buffs.tooltipDefaultPosition = Layout.BuffTooltipDefaultPosition
		buffs.tooltipPoint = Layout.BuffTooltipPoint
		buffs.tooltipAnchor = Layout.BuffTooltipAnchor
		buffs.tooltipRelPoint = Layout.BuffTooltipRelPoint
		buffs.tooltipOffsetX = Layout.BuffTooltipOffsetX
		buffs.tooltipOffsetY = Layout.BuffTooltipOffsetY
			
		self.Buffs = buffs
		self.Buffs.PostCreateButton = PostCreateAuraButton_Small -- post creation styling
		self.Buffs.PostUpdateButton = PostUpdateAuraButton_Small -- post updates when something changes (even timers)
	end 

	if Layout.UseDebuffs then 
		local debuffs = content:CreateFrame("Frame")
		debuffs:Place(unpack(Layout.DebuffFramePlace))
		debuffs:SetSize(unpack(Layout.DebuffFrameSize)) -- auras will be aligned in the available space, this size gives us 8x1 auras
		debuffs.auraSize = Layout.DebuffSize -- size of the aura. assuming squares. 
		debuffs.spacingH = Layout.DebuffSpaceH -- horizontal/column spacing between buttons
		debuffs.spacingV = Layout.DebuffSpaceV -- vertical/row spacing between aura buttons
		debuffs.growthX = Layout.DebuffGrowthX -- auras grow to the left
		debuffs.growthY = Layout.DebuffGrowthY -- rows grow downwards (we just have a single row, though)
		debuffs.maxVisible = Layout.DebuffMax -- when set will limit the number of buttons regardless of space available
		debuffs.showCooldownSpiral = Layout.ShowDebuffCooldownSpirals -- don't show the spiral as a timer
		debuffs.showCooldownTime = Layout.ShowDebuffCooldownTime -- show timer numbers
		debuffs.debuffFilter = Layout.DebuffFilter -- general aura filter, only used if the below aren't here
		debuffs.DebuffFilter = Layout.DebuffFilterFunc -- general aura filter function, called when the below aren't there
		debuffs.tooltipDefaultPosition = Layout.DebuffTooltipDefaultPosition
		debuffs.tooltipPoint = Layout.DebuffTooltipPoint
		debuffs.tooltipAnchor = Layout.DebuffTooltipAnchor
		debuffs.tooltipRelPoint = Layout.DebuffTooltipRelPoint
		debuffs.tooltipOffsetX = Layout.DebuffTooltipOffsetX
		debuffs.tooltipOffsetY = Layout.DebuffTooltipOffsetY
			
		self.Debuffs = debuffs
		self.Debuffs.PostCreateButton = PostCreateAuraButton_Small -- post creation styling
		self.Debuffs.PostUpdateButton = PostUpdateAuraButton_Small -- post updates when something changes (even timers)
	end 

	-- Texts
	-----------------------------------------------------------
	-- Unit Name
	if Layout.UseName then 
		local name = overlay:CreateFontString()
		name:SetPoint(unpack(Layout.NamePlace))
		name:SetDrawLayer(unpack(Layout.NameDrawLayer))
		name:SetJustifyH(Layout.NameDrawJustifyH)
		name:SetJustifyV(Layout.NameDrawJustifyV)
		name:SetFontObject(Layout.NameFont)
		name:SetTextColor(unpack(Layout.NameColor))
		if Layout.NameSize then 
			name:SetSize(unpack(Layout.NameSize))
		end 
		self.Name = name
	end 

	-- Health Value
	if Layout.UseHealthValue then 
		local healthVal = health:CreateFontString()
		healthVal:SetPoint(unpack(Layout.HealthValuePlace))
		healthVal:SetDrawLayer(unpack(Layout.HealthValueDrawLayer))
		healthVal:SetJustifyH(Layout.HealthValueJustifyH)
		healthVal:SetJustifyV(Layout.HealthValueJustifyV)
		healthVal:SetFontObject(Layout.HealthValueFont)
		healthVal:SetTextColor(unpack(Layout.HealthValueColor))
		healthVal.showPercent = Layout.HealthShowPercent

		-- Health percentage for bosses
		-- TODO: FIX!
		if Layout.UseHealthPercent then 
			local healthPerc = health:CreateFontString()
			healthPerc:SetPoint("LEFT", 27, 4)
			healthPerc:SetDrawLayer("OVERLAY")
			healthPerc:SetJustifyH("CENTER")
			healthPerc:SetJustifyV("MIDDLE")
			healthPerc:SetFontObject(Fonts(18, true))
			healthPerc:SetShadowOffset(0, 0)
			healthPerc:SetShadowColor(0, 0, 0, 0)
			healthPerc:SetTextColor(240/255, 240/255, 240/255, .5)
		end 
		
		self.Health.Value = healthVal
		self.Health.Percent = healthPerc
		self.Health.OverrideValue = Layout.HealthValueOverride or OverrideHealthValue
	end 

	-- Cast Name
	if Layout.UseCastBar then
		if Layout.UseCastBarName then 
			local name, parent 
			if Layout.CastBarNameParent then 
				parent = self[Layout.CastBarNameParent]
			end 
			local name = (parent or overlay):CreateFontString()
			name:SetPoint(unpack(Layout.CastBarNamePlace))
			name:SetFontObject(Layout.CastBarNameFont)
			name:SetDrawLayer(unpack(Layout.CastBarNameDrawLayer))
			name:SetJustifyH(Layout.CastBarNameJustifyH)
			name:SetJustifyV(Layout.CastBarNameJustifyV)
			name:SetTextColor(unpack(Layout.CastBarNameColor))
			if Layout.CastBarNameSize then 
				name:SetSize(unpack(Layout.CastBarNameSize))
			end 
			self.Cast.Name = name
		end 
	end

	-- Absorb Value
	if Layout.UseAbsorbBar then 
		if Layout.UseAbsorbValue then 
			local absorbVal = overlay:CreateFontString()
			if Layout.AbsorbValuePlaceFunction then 
				absorbVal:SetPoint(Layout.AbsorbValuePlaceFunction(self))
			else 
				absorbVal:SetPoint(unpack(Layout.AbsorbValuePlace))
			end 
			absorbVal:SetDrawLayer(unpack(Layout.AbsorbValueDrawLayer))
			absorbVal:SetJustifyH(Layout.AbsorbValueJustifyH)
			absorbVal:SetJustifyV(Layout.AbsorbValueJustifyV)
			absorbVal:SetFontObject(Layout.AbsorbValueFont)
			absorbVal:SetTextColor(unpack(Layout.AbsorbValueColor))
			self.Absorb.Value = absorbVal 
			self.Absorb.OverrideValue = OverrideValue
		end 
	end 

	if (Layout.HideWhenUnitIsPlayer or Layout.HideWhenTargetIsCritter or Layout.HideWhenUnitIsTarget) then 
		self.hideWhenUnitIsPlayer = Layout.HideWhenUnitIsPlayer
		self.hideWhenUnitIsTarget = Layout.HideWhenUnitIsTarget
		self.hideWhenTargetIsCritter = Layout.HideWhenTargetIsCritter
		self.PostUpdate = PostUpdateAlpha
		self:RegisterEvent("PLAYER_TARGET_CHANGED", PostUpdateAlpha, true)
	end 

end
