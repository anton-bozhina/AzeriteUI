local ADDON = ...

local Core = CogWheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("UnitFrameTarget", "LibEvent", "LibUnitFrame", "LibSound")
local Colors = CogWheel("LibDB"):GetDatabase(ADDON..": Colors")
local Auras = CogWheel("LibDB"):GetDatabase(ADDON..": Auras")
local Fonts = CogWheel("LibDB"):GetDatabase(ADDON..": Fonts")
local Functions = CogWheel("LibDB"):GetDatabase(ADDON..": Functions")
local Layout = CogWheel("LibDB"):GetDatabase(ADDON..": Layout [UnitFrameTarget]")

-- Lua API
local _G = _G
local unpack = unpack

-- WoW API
local GetAccountExpansionLevel = _G.GetAccountExpansionLevel
local GetExpansionLevel = _G.GetExpansionLevel
local GetQuestGreenRange = _G.GetQuestGreenRange
local IsXPUserDisabled = _G.IsXPUserDisabled
local UnitClassification = _G.UnitClassification
local UnitExists = _G.UnitExists
local UnitIsConnected = _G.UnitIsConnected
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitIsEnemy = _G.UnitIsEnemy
local UnitIsFriend = _G.UnitIsFriend
local UnitIsTrivial = _G.UnitIsTrivial
local UnitLevel = _G.UnitLevel

-- WoW Constants & Objects
local DEAD = _G.DEAD
local MAX_PLAYER_LEVEL_TABLE = _G.MAX_PLAYER_LEVEL_TABLE
local PLAYER_OFFLINE = _G.PLAYER_OFFLINE

-- Player Class
local _, PlayerClass = UnitClass("player")

-- Current player level
-- We use this to decide how dangerous enemies are 
-- relative to our current character.
local LEVEL = UnitLevel("player") 

-- Constants to hold various info about our last target 
-- We need this to decide when the artwork should change
local TARGET_STYLE


-- Utility Functions
-----------------------------------------------------------------

-- Returns the correct difficulty color compared to the player
local getDifficultyColorByLevel = function(level)
	level = level - LEVEL
	if (level > 4) then
		return Colors.quest.red.colorCode
	elseif (level > 2) then
		return Colors.quest.orange.colorCode
	elseif (level >= -2) then
		return Colors.quest.yellow.colorCode
	elseif (level >= -GetQuestGreenRange()) then
		return Colors.quest.green.colorCode
	else
		return Colors.quest.gray.colorCode
	end
end

-- Figure out if the player has a XP bar
local PlayerHasXP = Functions.PlayerHasXP


-- Callbacks
-----------------------------------------------------------------

-- Number abbreviations
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
		if element.Percent then 
			element.Percent:SetText("")
		end 
		if element.Value then 
			element.Value:SetText(PLAYER_OFFLINE)
		end 
	elseif dead then 
		if element.Percent then 
			element.Percent:SetText("")
		end 
		if element.Value then 
			element.Value:SetText(DEAD)
		end 
	else
		if element.Percent then 
			element.Percent:SetFormattedText("%d", min/max*100 - (min/max*100)%1)
		end 
		if element.Value then 
			OverrideValue(element, unit, min, max, disconnected, dead, tapped)
		end 
	end 
end 

local Threat_UpdateColor = function(element, unit, status, r, g, b)
	if element.health then 
		element.health:SetVertexColor(r, g, b)
	end
	if element.power then 
		element.power:SetVertexColor(r, g, b)
	end
	if element.portrait then 
		element.portrait:SetVertexColor(r, g, b)
	end 
end

local Threat_IsShown = function(element)
	return element.health and element.health:IsShown()
end 

local Threat_Show = function(element)
	if 	element.health then 
		element.health:Show()
	end
	if 	element.power then 
		element.power:Show()
	end
	if element.portrait then 
		element.portrait:Show()
	end 
end 

local Threat_Hide = function(element)
	if 	element.health then 
		element.health:Hide()
	end 
	if element.power then 
		element.power:Hide()
	end
	if element.portrait then 
		element.portrait:Hide()
	end
end 

local PostCreateAuraButton = function(element, button)
	button.Icon:SetTexCoord(unpack(Layout.AuraIconTexCoord))
	button.Icon:SetSize(unpack(Layout.AuraIconSize))
	button.Icon:ClearAllPoints()
	button.Icon:SetPoint(unpack(Layout.AuraIconPlace))

	button.Count:SetFontObject(Layout.AuraCountFont)
	button.Count:SetJustifyH("CENTER")
	button.Count:SetJustifyV("MIDDLE")
	button.Count:ClearAllPoints()
	button.Count:SetPoint(unpack(Layout.AuraCountPlace))
	if Layout.AuraCountColor then 
		button.Count:SetTextColor(unpack(Layout.AuraCountColor))
	end 

	button.Time:SetFontObject(Layout.AuraTimeFont)
	button.Time:ClearAllPoints()
	button.Time:SetPoint(unpack(Layout.AuraTimePlace))

	local layer, level = button.Icon:GetDrawLayer()

	button.Darken = button.Darken or button:CreateTexture()
	button.Darken:SetDrawLayer(layer, level + 1)
	button.Darken:SetSize(button.Icon:GetSize())
	button.Darken:SetPoint("CENTER", 0, 0)
	button.Darken:SetColorTexture(0, 0, 0, .25)

	button.Overlay:SetFrameLevel(button:GetFrameLevel() + 10)
	button.Overlay:ClearAllPoints()
	button.Overlay:SetPoint("CENTER", 0, 0)
	button.Overlay:SetSize(button.Icon:GetSize())

	button.Border = button.Border or button.Overlay:CreateFrame("Frame", nil, button.Overlay)
	button.Border:SetFrameLevel(button.Overlay:GetFrameLevel() - 5)
	button.Border:ClearAllPoints()
	button.Border:SetPoint(unpack(Layout.AuraBorderFramePlace))
	button.Border:SetSize(unpack(Layout.AuraBorderFrameSize))
	button.Border:SetBackdrop(Layout.AuraBorderBackdrop)
	button.Border:SetBackdropColor(unpack(Layout.AuraBorderBackdropColor))
	button.Border:SetBackdropBorderColor(unpack(Layout.AuraBorderBackdropBorderColor))

	if Layout.UseAuraSpellHightlight then 
		button.SpellHighlight = button.SpellHighlight or button.Overlay:CreateFrame("Frame", nil, button.Overlay)
		button.SpellHighlight:Hide()
		button.SpellHighlight:SetFrameLevel(button.Overlay:GetFrameLevel() - 6)
		button.SpellHighlight:ClearAllPoints()
		button.SpellHighlight:SetPoint(unpack(Layout.AuraSpellHighlightFramePlace))
		button.SpellHighlight:SetSize(unpack(Layout.AuraSpellHighlightFrameSize))
		button.SpellHighlight:SetBackdrop(Layout.AuraSpellHighlightBackdrop)
	end 

end

local PostUpdateAuraButton = function(element, button)
	if (not button) or (not button:IsVisible()) or (not button.unit) or (not UnitExists(button.unit)) then 
		return 
	end 
	if UnitIsFriend("player", button.unit) then 
		if button.isBuff then 
			button.SpellHighlight:Hide()
		else
			button.SpellHighlight:SetBackdropColor(0, 0, 0, 0)
			button.SpellHighlight:SetBackdropBorderColor(1, 0, 0, 1)
			button.SpellHighlight:Show()
		end
	else 
		if button.isStealable then 
			button.SpellHighlight:SetBackdropColor(0, 0, 0, 0)
			button.SpellHighlight:SetBackdropBorderColor(Colors.power.ARCANE_CHARGES[1], Colors.power.ARCANE_CHARGES[2], Colors.power.ARCANE_CHARGES[3], 1)
			button.SpellHighlight:Show()
		elseif button.isBuff then 
			button.SpellHighlight:SetBackdropColor(0, 0, 0, 0)
			button.SpellHighlight:SetBackdropBorderColor(0, .7, 0, 1)
			button.SpellHighlight:Show()
		else
			button.SpellHighlight:Hide()
		end
	end 
end

local PostUpdateTextures = function(self)
	if (not Layout.UseProgressiveFrames) then 
		return
	end 

	local CURRENT_STYLE

	-- Figure out if the various artwork and bar textures need to be updated
	-- We could put this into element post updates, 
	-- but to avoid needless checks we limit this to actual target updates. 
	local level = UnitLevel("target")
	local classification = UnitClassification("target")

	if ((classification == "worldboss") or (level and level < 1)) then 
		CURRENT_STYLE = "Boss"

	elseif ((level and level >= MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()]) or (UnitIsUnit("target", "player") and (not PlayerHasXP()))) then 
		CURRENT_STYLE = "Seasoned"

	elseif (level and level >= Layout.HardenedLevel) then 
		CURRENT_STYLE = "Hardened"

	elseif ((level and level == 1) and (not UnitIsPlayer("target"))) then 
		CURRENT_STYLE = "Critter"

	elseif ((level and level > 1) or UnitIsPlayer("target")) then 
		CURRENT_STYLE = "Novice"
	end 

	-- Silently return if there was no change
	if (CURRENT_STYLE == TARGET_STYLE) or (not CURRENT_STYLE) then 
		return 
	end 

	-- Store the new style
	TARGET_STYLE = CURRENT_STYLE

	-- Do this?
	self.progressiveFrameStyle = CURRENT_STYLE

	if Layout.UseProgressiveHealth then 
		self.Health:Place(unpack(Layout[TARGET_STYLE.."HealthPlace"]))
		self.Health:SetSize(unpack(Layout[TARGET_STYLE.."HealthSize"]))
		self.Health:SetStatusBarTexture(Layout[TARGET_STYLE.."HealthTexture"])
		self.Health:SetSparkMap(Layout[TARGET_STYLE.."HealthSparkMap"])

		if Layout.UseHealthBackdrop and Layout.UseProgressiveHealthBackdrop then 
			self.Health.Bg:ClearAllPoints()
			self.Health.Bg:SetPoint(unpack(Layout[TARGET_STYLE.."HealthBackdropPlace"]))
			self.Health.Bg:SetSize(unpack(Layout[TARGET_STYLE.."HealthBackdropSize"]))
			self.Health.Bg:SetTexture(Layout[TARGET_STYLE.."HealthBackdropTexture"])
			self.Health.Bg:SetVertexColor(unpack(Layout[TARGET_STYLE.."HealthBackdropColor"]))
		end

		if Layout.UseHealthValue and Layout[TARGET_STYLE.."HealthValueVisible"]  then 
			self.Health.Value:Show()
		elseif Layout.UseHealthValue then 
			self.Health.Value:Hide()
		end 

		if Layout.UseHealthPercent and Layout[TARGET_STYLE.."HealthPercentVisible"]  then 
			self.Health.Percent:Show()
		elseif Layout.UseHealthPercent then 
			self.Health.Percent:Hide()
		end 
	end 

	if Layout.UseAbsorbBar and Layout.UseProgressiveAbsorbBar then 
		self.Absorb:SetSize(unpack(Layout[TARGET_STYLE.."AbsorbSize"]))
		self.Absorb:SetStatusBarTexture(Layout[TARGET_STYLE.."AbsorbTexture"])
	end

	if Layout.UsePowerBar and Layout.UseProgressivePowerBar then 
		if Layout.UsePowerForeground then 
			self.Power.Fg:SetTexture(Layout[TARGET_STYLE.."PowerForegroundTexture"])
			self.Power.Fg:SetVertexColor(unpack(Layout[TARGET_STYLE.."PowerForegroundColor"]))
		end
	end

	if Layout.UseMana and Layout.UseProgressiveMana then 
		self.ExtraPower.Border:SetTexture(Layout[TARGET_STYLE.."ManaOrbTexture"])
		self.ExtraPower.Border:SetVertexColor(unpack(Layout[TARGET_STYLE.."ManaOrbColor"])) 
	end 

	if Layout.UseThreat and Layout.UseProgressiveThreat then
		if self.Threat.health then 
			self.Threat.health:SetTexture(Layout[TARGET_STYLE.."HealthThreatTexture"])
			if Layout[TARGET_STYLE.."HealthThreatPlace"] then 
				self.Threat.health:ClearAllPoints()
				self.Threat.health:SetPoint(unpack(Layout[TARGET_STYLE.."HealthThreatPlace"]))
			end 
			if Layout[TARGET_STYLE.."HealthThreatSize"] then 
				self.Threat.health:SetSize(unpack(Layout[TARGET_STYLE.."HealthThreatSize"]))
			end 
		end 
	end

	if Layout.UseCastBar and Layout.UseProgressiveCastBar then 
		self.Cast:Place(unpack(Layout[TARGET_STYLE.."CastPlace"]))
		self.Cast:SetSize(unpack(Layout[TARGET_STYLE.."CastSize"]))
		self.Cast:SetStatusBarTexture(Layout[TARGET_STYLE.."CastTexture"])
		self.Cast:SetSparkMap(Layout[TARGET_STYLE.."CastSparkMap"])
	end 

	if Layout.UsePortrait and Layout.UseProgressivePortrait then 


		if Layout.UsePortraitBackground then 
		end 

		if Layout.UsePortraitShade then 
		end 

		if Layout.UsePortraitForeground then 
			self.Portrait.Fg:SetTexture(Layout[TARGET_STYLE.."PortraitForegroundTexture"])
			self.Portrait.Fg:SetVertexColor(unpack(Layout[TARGET_STYLE.."PortraitForegroundColor"]))
		end 
	end 
	
end 

local Style = function(self, unit, id, ...)

	-- Frame
	self:SetSize(unpack(Layout.Size)) 
	self:Place(unpack(Layout.Place)) 

	if Layout.HitRectInsets then 
		self:SetHitRectInsets(unpack(Layout.HitRectInsets))
	else 
		self:SetHitRectInsets(0, 0, 0, 0)
	end 

	-- Assign our own global custom colors
	self.colors = Colors

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

	-- Health 
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
	health.colorReaction = Layout.HealthColorReaction -- color NPCs by their reaction standing with us
	health.colorThreat = Layout.HealthColorThreat -- color units with threat in threat color
	health.colorHealth = Layout.HealthColorHealth -- color anything else in the default health color
	health.frequent = Layout.HealthFrequentUpdates -- listen to frequent health events for more accurate updates
	health.threatFeedbackUnit = Layout.HealthThreatFeedbackUnit
	health.threatHideSolo = Layout.HealthThreatHideSolo

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
		if Layout.HealthBackdropTexCoord then 
			healthBg:SetTexCoord(unpack(Layout.HealthBackdropTexCoord))
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
		self.Health.Fg = healthFg
	end 

	-- Absorb Bar
	if Layout.UseAbsorbBar then 
		local absorb = content:CreateStatusBar()
		absorb:SetFrameLevel(health:GetFrameLevel() + 1)
		absorb:Place(unpack(Layout.AbsorbBarPlace))
		absorb:SetOrientation(Layout.AbsorbBarOrientation) 
		absorb:SetFlippedHorizontally(Layout.AbsorbBarSetFlippedHorizontally)
		absorb:SetStatusBarColor(unpack(Layout.AbsorbBarColor)) 

		if (not Layout.UseProgressiveFrames) then
			absorb:SetSize(unpack(Layout.AbsorbSize))
			absorb:SetStatusBarTexture(Layout.AbsorbBarTexture)
		end
		if Layout.AbsorbBarSparkMap then 
			absorb:SetSparkMap(Layout.AbsorbBarSparkMap) -- set the map the spark follows along the bar.
		end 

		self.Absorb = absorb
	end 

	-- Power 
	if Layout.UsePowerBar then 
		local power = (Layout.PowerInOverlay and overlay or backdrop):CreateStatusBar()
		power:SetSize(unpack(Layout.PowerSize))
		power:Place(unpack(Layout.PowerPlace))
		power:SetStatusBarTexture(Layout.PowerBarTexture)
		power:SetTexCoord(unpack(Layout.PowerBarTexCoord))
		power:SetOrientation(Layout.PowerBarOrientation or "RIGHT") -- set the bar to grow towards the top.
		power:SetSmoothingMode(Layout.PowerBarSmoothingMode) -- set the smoothing mode.
		power:SetSmoothingFrequency(Layout.PowerBarSmoothingFrequency or .5) -- set the duration of the smoothing.

		if Layout.PowerBarSetFlippedHorizontally then 
			power:SetFlippedHorizontally(Layout.PowerBarSetFlippedHorizontally)
		end

		if Layout.PowerBarSparkMap then 
			power:SetSparkMap(Layout.PowerBarSparkMap) -- set the map the spark follows along the bar.
		end 

		if Layout.PowerBarSparkTexture then 
			power:SetSparkTexture(Layout.PowerBarSparkTexture)
		end

		-- make the bar hide when MANA is the primary resource. 
		power.ignoredResource = Layout.PowerIgnoredResource 

		-- use this bar for alt power as well
		power.showAlternate = Layout.PowerShowAlternate

		-- hide the bar when it's empty
		power.hideWhenEmpty = Layout.PowerHideWhenEmpty

		-- hide the bar when the unit is dead
		power.hideWhenDead = Layout.PowerHideWhenDead

		-- Use filters to decide what units to show for 
		power.visibilityFilter = Layout.PowerVisibilityFilter

		self.Power = power
		self.Power.OverrideColor = OverridePowerColor

		if Layout.UsePowerBackground then 
			local powerBg = power:CreateTexture()
			powerBg:SetDrawLayer(unpack(Layout.PowerBackgroundDrawLayer))
			powerBg:SetSize(unpack(Layout.PowerBackgroundSize))
			powerBg:SetPoint(unpack(Layout.PowerBackgroundPlace))
			powerBg:SetTexture(Layout.PowerBackgroundTexture)
			powerBg:SetVertexColor(unpack(Layout.PowerBackgroundColor)) 
			if Layout.PowerBackgroundTexCoord then 
				powerBg:SetTexCoord(unpack(Layout.PowerBackgroundTexCoord))
			end 
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

		-- Power Value
		if Layout.UsePowerBar then 
			if Layout.UsePowerValue then 
				local powerVal = self.Power:CreateFontString()
				powerVal:SetPoint(unpack(Layout.PowerValuePlace))
				powerVal:SetDrawLayer(unpack(Layout.PowerValueDrawLayer))
				powerVal:SetJustifyH(Layout.PowerValueJustifyH)
				powerVal:SetJustifyV(Layout.PowerValueJustifyV)
				powerVal:SetFontObject(Layout.PowerValueFont)
				powerVal:SetTextColor(unpack(Layout.PowerValueColor))
				self.Power.Value = powerVal
				self.Power.OverrideValue = Layout.PowerValueOverride
			end 
		end		
	end 

	-- Cast Bar
	if Layout.UseCastBar then
		local cast = content:CreateStatusBar()
		cast:SetSize(unpack(Layout.CastBarSize))
		cast:SetFrameLevel(health:GetFrameLevel() + 1)
		cast:Place(unpack(Layout.CastBarPlace))
		cast:SetOrientation(Layout.CastBarOrientation) 
		cast:SetFlippedHorizontally(Layout.CastBarSetFlippedHorizontally)
		cast:SetSmoothingMode(Layout.CastBarSmoothingMode) 
		cast:SetSmoothingFrequency(Layout.CastBarSmoothingFrequency)
		cast:SetStatusBarColor(unpack(Layout.CastBarColor)) 
		
		if (not Layout.UseProgressiveFrames) then 
			cast:SetStatusBarTexture(Layout.CastBarTexture)
		end 

		if Layout.CastBarSparkMap then 
			cast:SetSparkMap(Layout.CastBarSparkMap) -- set the map the spark follows along the bar.
		end

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
			cast.Name = name
		end 

		if Layout.UseCastBarValue then 
			local value, parent 
			if Layout.CastBarValueParent then 
				parent = self[Layout.CastBarValueParent]
			end 
			local value = (parent or overlay):CreateFontString()
			value:SetPoint(unpack(Layout.CastBarValuePlace))
			value:SetFontObject(Layout.CastBarValueFont)
			value:SetDrawLayer(unpack(Layout.CastBarValueDrawLayer))
			value:SetJustifyH(Layout.CastBarValueJustifyH)
			value:SetJustifyV(Layout.CastBarValueJustifyV)
			value:SetTextColor(unpack(Layout.CastBarValueColor))
			if Layout.CastBarValueSize then 
				value:SetSize(unpack(Layout.CastBarValueSize))
			end 
			cast.Value = value
		end 

		self.Cast = cast
		self.Cast.PostUpdate = Layout.CastBarPostUpdate
		
	end 

	-- Portrait
	if Layout.UsePortrait then 
		local portrait = backdrop:CreateFrame("PlayerModel")
		portrait:SetPoint(unpack(Layout.PortraitPlace))
		portrait:SetSize(unpack(Layout.PortraitSize)) 
		portrait:SetAlpha(Layout.PortraitAlpha)
		portrait.distanceScale = Layout.PortraitDistanceScale
		portrait.positionX = Layout.PortraitPositionX
		portrait.positionY = Layout.PortraitPositionY
		portrait.positionZ = Layout.PortraitPositionZ
		portrait.rotation = Layout.PortraitRotation -- in degrees
		portrait.showFallback2D = Layout.PortraitShowFallback2D -- display 2D portraits when unit is out of range of 3D models
		self.Portrait = portrait
		
		-- To allow the backdrop and overlay to remain 
		-- visible even with no visible player model, 
		-- we add them to our backdrop and overlay frames, 
		-- not to the portrait frame itself.  
		if Layout.UsePortraitBackground then 
			local portraitBg = backdrop:CreateTexture()
			portraitBg:SetPoint(unpack(Layout.PortraitBackgroundPlace))
			portraitBg:SetSize(unpack(Layout.PortraitBackgroundSize))
			portraitBg:SetTexture(Layout.PortraitBackgroundTexture)
			portraitBg:SetDrawLayer(unpack(Layout.PortraitBackgroundDrawLayer))
			portraitBg:SetVertexColor(unpack(Layout.PortraitBackgroundColor)) -- keep this dark
			self.Portrait.Bg = portraitBg
		end 

		if Layout.UsePortraitShade then 
			local portraitShade = content:CreateTexture()
			portraitShade:SetPoint(unpack(Layout.PortraitShadePlace))
			portraitShade:SetSize(unpack(Layout.PortraitShadeSize)) 
			portraitShade:SetTexture(Layout.PortraitShadeTexture)
			portraitShade:SetDrawLayer(unpack(Layout.PortraitShadeDrawLayer))
			self.Portrait.Shade = portraitShade
		end 

		if Layout.UsePortraitForeground then 
			local portraitFg = content:CreateTexture()
			portraitFg:SetPoint(unpack(Layout.PortraitForegroundPlace))
			portraitFg:SetSize(unpack(Layout.PortraitForegroundSize))
			portraitFg:SetDrawLayer(unpack(Layout.PortraitForegroundDrawLayer))
			self.Portrait.Fg = portraitFg
		end 
	end 

	-- Threat
	if Layout.UseThreat then 
		
		local threat 
		if Layout.UseSingleThreat then 
			threat = backdrop:CreateTexture()
		else 
			threat = {}
			threat.IsShown = Threat_IsShown
			threat.Show = Threat_Show
			threat.Hide = Threat_Hide 
			threat.IsObjectType = function() end

			if Layout.UseHealthThreat then 

				local healthThreatHolder = backdrop:CreateFrame("Frame")
				healthThreatHolder:SetAllPoints(health)

				local threatHealth = healthThreatHolder:CreateTexture()
				if Layout.ThreatHealthPlace then 
					threatHealth:SetPoint(unpack(Layout.ThreatHealthPlace))
				end 
				if Layout.ThreatHealthSize then 
					threatHealth:SetSize(unpack(Layout.ThreatHealthSize))
				end 
				if Layout.ThreatHealthTexCoord then 
					threatHealth:SetTexCoord(unpack(Layout.ThreatHealthTexCoord))
				end 
				if (not Layout.UseProgressiveHealthThreat) then 
					threatHealth:SetTexture(Layout.ThreatHealthTexture)
				end 
				threatHealth:SetDrawLayer(unpack(Layout.ThreatHealthDrawLayer))
				threatHealth:SetAlpha(Layout.ThreatHealthAlpha)

				threatHealth._owner = self.Health
				threat.health = threatHealth
			end 
		
			if Layout.UsePowerBar and (Layout.UsePowerThreat or Layout.UsePowerBgThreat) then 

				local threatPowerFrame = backdrop:CreateFrame("Frame")
				threatPowerFrame:SetFrameLevel(backdrop:GetFrameLevel())
				threatPowerFrame:SetAllPoints(self.Power)
		
				-- Hook the power visibility to the power crystal
				self.Power:HookScript("OnShow", function() threatPowerFrame:Show() end)
				self.Power:HookScript("OnHide", function() threatPowerFrame:Hide() end)

				if Layout.UsePowerThreat then
					local threatPower = threatPowerFrame:CreateTexture()
					threatPower:SetPoint(unpack(Layout.ThreatPowerPlace))
					threatPower:SetDrawLayer(unpack(Layout.ThreatPowerDrawLayer))
					threatPower:SetSize(unpack(Layout.ThreatPowerSize))
					threatPower:SetAlpha(Layout.ThreatPowerAlpha)

					if (not Layout.UseProgressivePowerThreat) then 
						threatPower:SetTexture(Layout.ThreatPowerTexture)
					end

					threatPower._owner = self.Power
					threat.power = threatPower
				end 

				if Layout.UsePowerBgThreat then 
					local threatPowerBg = threatPowerFrame:CreateTexture()
					threatPowerBg:SetPoint(unpack(Layout.ThreatPowerBgPlace))
					threatPowerBg:SetDrawLayer(unpack(Layout.ThreatPowerBgDrawLayer))
					threatPowerBg:SetSize(unpack(Layout.ThreatPowerBgSize))
					threatPowerBg:SetAlpha(Layout.ThreatPowerBgAlpha)

					if (not Layout.UseProgressivePowerBgThreat) then 
						threatPowerBg:SetTexture(Layout.ThreatPowerBgTexture)
					end

					threatPowerBg._owner = self.Power
					threat.powerBg = threatPowerBg
				end 
	
			end 
		
			if Layout.UsePortrait and Layout.UsePortraitThreat then 
				local threatPortraitFrame = backdrop:CreateFrame("Frame")
				threatPortraitFrame:SetFrameLevel(backdrop:GetFrameLevel())
				threatPortraitFrame:SetAllPoints(self.Portrait)
		
				-- Hook the power visibility to the power crystal
				self.Portrait:HookScript("OnShow", function() threatPortraitFrame:Show() end)
				self.Portrait:HookScript("OnHide", function() threatPortraitFrame:Hide() end)

				local threatPortrait = threatPortraitFrame:CreateTexture()
				threatPortrait:SetPoint(unpack(Layout.ThreatPortraitPlace))
				threatPortrait:SetSize(unpack(Layout.ThreatPortraitSize))
				threatPortrait:SetTexture(Layout.ThreatPortraitTexture)
				threatPortrait:SetDrawLayer(unpack(Layout.ThreatPortraitDrawLayer))
				threatPortrait:SetAlpha(Layout.ThreatPortraitAlpha)

				threatPortrait._owner = self.Power
				threat.portrait = threatPortrait
			end 
		end 

		threat.hideSolo = Layout.ThreatHideSolo
		threat.fadeOut = Layout.ThreatFadeOut
		threat.feedbackUnit = "player"
	
		self.Threat = threat
		self.Threat.OverrideColor = Threat_UpdateColor
	end 

	-- Unit Level
	if Layout.UseLevel then 

		-- level text
		local level = overlay:CreateFontString()
		level:SetPoint(unpack(Layout.LevelPlace))
		level:SetDrawLayer(unpack(Layout.LevelDrawLayer))
		level:SetJustifyH(Layout.LevelJustifyH)
		level:SetJustifyV(Layout.LevelJustifyV)
		level:SetFontObject(Layout.LevelFont)

		-- Hide the level of capped (or higher) players and NPcs 
		-- Doesn't affect high/unreadable level (??) creatures, as they will still get a skull.
		level.hideCapped = Layout.LevelHideCapped 

		-- Hide the level of level 1's
		level.hideFloored = Layout.LevelHideFloored

		-- Set the default level coloring when nothing special is happening
		level.defaultColor = Layout.LevelColor
		level.alpha = Layout.LevelAlpha

		-- Use a custom method to decide visibility
		level.visibilityFilter = Layout.LevelVisibilityFilter

		-- Badge backdrop
		if Layout.UseLevelBadge then 
			local levelBadge = overlay:CreateTexture()
			levelBadge:SetPoint("CENTER", level, "CENTER", 0, 0)
			levelBadge:SetSize(unpack(Layout.LevelBadgeSize))
			levelBadge:SetDrawLayer(unpack(Layout.LevelBadgeDrawLayer))
			levelBadge:SetTexture(Layout.LevelBadgeTexture)
			levelBadge:SetVertexColor(unpack(Layout.LevelBadgeColor))
			level.Badge = levelBadge
		end 

		-- Skull texture for bosses, high level (and dead units if the below isn't provided)
		if Layout.UseLevelSkull then 
			local skull = overlay:CreateTexture()
			skull:Hide()
			skull:SetPoint("CENTER", level, "CENTER", 0, 0)
			skull:SetSize(unpack(Layout.LevelSkullSize))
			skull:SetDrawLayer(unpack(Layout.LevelSkullDrawLayer))
			skull:SetTexture(Layout.LevelSkullTexture)
			skull:SetVertexColor(unpack(Layout.LevelSkullColor))
			level.Skull = skull
		end 

		-- Skull texture for dead units only
		if Layout.UseLevelDeadSkull then 
			local dead = overlay:CreateTexture()
			dead:Hide()
			dead:SetPoint("CENTER", level, "CENTER", 0, 0)
			dead:SetSize(unpack(Layout.LevelDeadSkullSize))
			dead:SetDrawLayer(unpack(Layout.LevelDeadSkullDrawLayer))
			dead:SetTexture(Layout.LevelDeadSkullTexture)
			dead:SetVertexColor(unpack(Layout.LevelDeadSkullColor))
			level.Dead = dead
		end 
		
		self.Level = level	
	end 

	-- Unit Classification (boss, elite, rare)
	if Layout.UseClassificationIndicator then 
		self.Classification = {}

		local boss = overlay:CreateTexture()
		boss:SetPoint(unpack(Layout.ClassificationIndicatorBossPlace))
		boss:SetSize(unpack(Layout.ClassificationIndicatorBossSize))
		boss:SetTexture(Layout.ClassificationIndicatorBossTexture)
		boss:SetVertexColor(unpack(Layout.ClassificationIndicatorBossColor))
		self.Classification.Boss = boss

		local elite = overlay:CreateTexture()
		elite:SetPoint(unpack(Layout.ClassificationIndicatorElitePlace))
		elite:SetSize(unpack(Layout.ClassificationIndicatorEliteSize))
		elite:SetTexture(Layout.ClassificationIndicatorEliteTexture)
		elite:SetVertexColor(unpack(Layout.ClassificationIndicatorEliteColor))
		self.Classification.Elite = elite

		local rare = overlay:CreateTexture()
		rare:SetPoint(unpack(Layout.ClassificationIndicatorRarePlace))
		rare:SetSize(unpack(Layout.ClassificationIndicatorRareSize))
		rare:SetTexture(Layout.ClassificationIndicatorRareTexture)
		rare:SetVertexColor(unpack(Layout.ClassificationIndicatorRareColor))
		self.Classification.Rare = rare
	end

	-- Targeting
	-- Indicates who your target is targeting
	if Layout.UseTargetIndicator then 
		self.Targeted = {}

		local friend = overlay:CreateTexture()
		friend:SetPoint(unpack(Layout.TargetIndicatorYouByFriendPlace))
		friend:SetSize(unpack(Layout.TargetIndicatorYouByFriendSize))
		friend:SetTexture(Layout.TargetIndicatorYouByFriendTexture)
		friend:SetVertexColor(unpack(Layout.TargetIndicatorYouByFriendColor))
		self.Targeted.YouByFriend = friend

		local enemy = overlay:CreateTexture()
		enemy:SetPoint(unpack(Layout.TargetIndicatorYouByEnemyPlace))
		enemy:SetSize(unpack(Layout.TargetIndicatorYouByEnemySize))
		enemy:SetTexture(Layout.TargetIndicatorYouByEnemyTexture)
		enemy:SetVertexColor(unpack(Layout.TargetIndicatorYouByEnemyColor))
		self.Targeted.YouByEnemy = enemy

		local pet = overlay:CreateTexture()
		pet:SetPoint(unpack(Layout.TargetIndicatorPetByEnemyPlace))
		pet:SetSize(unpack(Layout.TargetIndicatorPetByEnemySize))
		pet:SetTexture(Layout.TargetIndicatorPetByEnemyTexture)
		pet:SetVertexColor(unpack(Layout.TargetIndicatorPetByEnemyColor))
		self.Targeted.PetByEnemy = pet
	end 

	-- Auras
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
		auras.debuffsFirst = Layout.AuraDebuffs -- show debuffs before buffs
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
		self.Auras.PostCreateButton = PostCreateAuraButton -- post creation styling
		self.Auras.PostUpdateButton = PostUpdateAuraButton -- post updates when something changes (even timers)
	end 

	-- Buffs
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
		self.Buffs.PostCreateButton = PostCreateAuraButton -- post creation styling
		self.Buffs.PostUpdateButton = PostUpdateAuraButton -- post updates when something changes (even timers)
	end 

	-- Debuffs
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
		self.Debuffs.PostCreateButton = PostCreateAuraButton -- post creation styling
		self.Debuffs.PostUpdateButton = PostUpdateAuraButton -- post updates when something changes (even timers)
	end 

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
		self.Health.Value = healthVal
	end 

	-- Health Percentage 
	if Layout.UseHealthPercent then 
		local healthPerc = health:CreateFontString()
		healthPerc:SetPoint(unpack(Layout.HealthPercentPlace))
		healthPerc:SetDrawLayer(unpack(Layout.HealthPercentDrawLayer))
		healthPerc:SetJustifyH(Layout.HealthPercentJustifyH)
		healthPerc:SetJustifyV(Layout.HealthPercentJustifyV)
		healthPerc:SetFontObject(Layout.HealthPercentFont)
		healthPerc:SetTextColor(unpack(Layout.HealthPercentColor))
		self.Health.Percent = healthPerc
	end 

	-- Custom Health Value override function
	if (Layout.HealthValueOverride ~= nil) then 
		self.Health.OverrideValue = Layout.HealthValueOverride
	else 
		self.Health.OverrideValue = OverrideHealthValue
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

	-- Update textures according to player level
	if Layout.UseProgressiveFrames then 
		PostUpdateTextures(self)
	end 
end

Module.GetFrame = function(self)
	return self.frame
end 

Module.OnEvent = function(self, event, ...)
	if (event == "PLAYER_TARGET_CHANGED") then
	
		if UnitExists("target") then
			-- Play a fitting sound depending on what kind of target we gained
			if UnitIsEnemy("target", "player") then
				self:PlaySoundKitID(SOUNDKIT.IG_CREATURE_AGGRO_SELECT, "SFX")
			elseif UnitIsFriend("player", "target") then
				self:PlaySoundKitID(SOUNDKIT.IG_CHARACTER_NPC_SELECT, "SFX")
			else
				self:PlaySoundKitID(SOUNDKIT.IG_CREATURE_NEUTRAL_SELECT, "SFX")
			end

			-- Update textures according to player level
			if Layout.UseProgressiveFrames then 
				PostUpdateTextures(self:GetFrame())
			end 
		else
			-- Play a sound indicating we lost our target
			self:PlaySoundKitID(SOUNDKIT.INTERFACE_SOUND_LOST_TARGET_UNIT, "SFX")
		end

	elseif (event == "PLAYER_LEVEL_UP") then 
		local level = ...
		if (level and (level ~= LEVEL)) then
			LEVEL = level
		else
			local level = UnitLevel("player")
			if (level ~= LEVEL) then
				LEVEL = level
			end
		end
	end
end

Module.OnInit = function(self)
	local targetFrame = self:SpawnUnitFrame("target", "UICenter", Style)
	self.frame = targetFrame
end 

Module.OnEnable = function(self)
	self:RegisterEvent("PLAYER_LEVEL_UP", "OnEvent")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")
end 