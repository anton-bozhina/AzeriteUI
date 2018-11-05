local ADDON = ...
local Core = CogWheel("LibModule"):GetModule(ADDON)
if (not Core) then 
	return 
end

local Module = Core:NewModule("Minimap", "LibEvent", "LibDB", "LibMinimap", "LibTooltip", "LibTime")

-- Don't grab buttons if these are active
local MBB = Module:IsAddOnEnabled("MBB") 
local MBF = Module:IsAddOnEnabled("MinimapButtonFrame")

-- Lua API
local _G = _G
local math_floor = math.floor
local math_pi = math.pi
local select = select
local string_format = string.format
local string_gsub = string.gsub
local string_match = string.match
local string_upper = string.upper
local tonumber = tonumber
local unpack = unpack

-- WoW API
local FindActiveAzeriteItem = _G.C_AzeriteItem.FindActiveAzeriteItem
local GetAccountExpansionLevel = _G.GetAccountExpansionLevel
local GetAzeriteItemXPInfo = _G.C_AzeriteItem.GetAzeriteItemXPInfo
local GetFactionInfo = _G.GetFactionInfo
local GetFactionParagonInfo = _G.C_Reputation.GetFactionParagonInfo
local GetFramerate = _G.GetFramerate
local GetFriendshipReputation = _G.GetFriendshipReputation
local GetNetStats = _G.GetNetStats
local GetNumFactions = _G.GetNumFactions
local GetPowerLevel = _G.C_AzeriteItem.GetPowerLevel
local GetWatchedFactionInfo = _G.GetWatchedFactionInfo
local IsFactionParagon = _G.C_Reputation.IsFactionParagon
local IsXPUserDisabled = _G.IsXPUserDisabled
local SetCursor = _G.SetCursor
local ToggleCalendar = _G.ToggleCalendar
local UnitExists = _G.UnitExists
local UnitLevel = _G.UnitLevel
local UnitRace = _G.UnitRace

-- WoW Strings
local REPUTATION = _G.REPUTATION 
local STANDING = _G.STANDING 
local UNKNOWN = _G.UNKNOWN

local Spinner = {}
local shortXPString = "%s%%"
local longXPString = "%s / %s"
local fullXPString = "%s / %s (%s)"
local restedString = " (%s%% %s)"
local shortLevelString = "%s %d"
local LEVEL = UnitLevel("player")
local maxRested = select(2, UnitRace("player")) == "Pandaren" and 3 or 1.5

local defaults = {
	useStandardTime = true, -- as opposed to military/24-hour time
	useServerTime = false, -- as opposed to your local computer time
	stickyBars = false
}

local Colors, Fonts, Functions, L, Layout
local GetMediaPath, PlayerHasRep, PlayerHasXP

local degreesToRadians = function(degrees)
	return degrees * (2*math_pi)/180
end 

local getTimeStrings = function(h, m, suffix, useStandardTime, abbreviateSuffix)
	if useStandardTime then 
		return "%d:%02d |cff888888%s|r", h, m, abbreviateSuffix and string_match(suffix, "^.") or suffix
	else 
		return "%02d:%02d", h, m
	end 
end 

local short = function(value)
	value = tonumber(value)
	if (not value) then return "" end
	if (value >= 1e9) then
		return ("%.1fb"):format(value / 1e9):gsub("%.?0+([kmb])$", "%1")
	elseif value >= 1e6 then
		return ("%.1fm"):format(value / 1e6):gsub("%.?0+([kmb])$", "%1")
	elseif value >= 1e3 or value <= -1e3 then
		return ("%.1fk"):format(value / 1e3):gsub("%.?0+([kmb])$", "%1")
	else
		return tostring(math_floor(value))
	end	
end

-- zhCN exceptions
local gameLocale = GetLocale()
if (gameLocale == "zhCN") then 
	short = function(value)
		value = tonumber(value)
		if (not value) then return "" end
		if (value >= 1e8) then
			return ("%.1f亿"):format(value / 1e8):gsub("%.?0+([km])$", "%1")
		elseif value >= 1e4 or value <= -1e3 then
			return ("%.1f万"):format(value / 1e4):gsub("%.?0+([km])$", "%1")
		else
			return tostring(math_floor(value))
		end 
	end
end 

-- Callbacks
----------------------------------------------------
local Coordinates_OverrideValue = function(element, x, y)
	local xval = string_gsub(string_format("%.1f", x*100), "%.(.+)", "|cff888888.%1|r")
	local yval = string_gsub(string_format("%.1f", y*100), "%.(.+)", "|cff888888.%1|r")
	element:SetFormattedText("%s %s", xval, yval) 
end 

local Clock_OverrideValue = function(element, h, m, suffix)
	element:SetFormattedText(getTimeStrings(h, m, suffix, element.useStandardTime, true))
end 

local FrameRate_OverrideValue = function(element, fps)
	element:SetFormattedText("|cff888888%d %s|r", math_floor(fps), string_upper(string_match(FPS_ABBR, "^.")))
end 

local Latency_OverrideValue = function(element, home, world)
	element:SetFormattedText("|cff888888%s|r %d - |cff888888%s|r %d", string_upper(string_match(HOME, "^.")), math_floor(home), string_upper(string_match(WORLD, "^.")), math_floor(world))
end 

local Performance_UpdateTooltip = function(self)
	local tooltip = Module:GetMinimapTooltip()

	local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = GetNetStats()
	local fps = GetFramerate()

	local rt, gt, bt = unpack(Colors.title)
	local r, g, b = unpack(Colors.normal)
	local rh, gh, bh = unpack(Colors.highlight)
	local rg, gg, bg = unpack(Colors.quest.green)

	tooltip:SetDefaultAnchor(self)
	tooltip:SetMaximumWidth(360)
	tooltip:AddLine(L["Network Stats"], rt, gt, bt)
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(L["World latency:"], ("%d|cff888888%s|r"):format(math_floor(latencyWorld), MILLISECONDS_ABBR), rh, gh, bh, r, g, b)
	tooltip:AddLine(L["This is the latency of the world server, and affects casting, crafting, interaction with other players and NPCs. This is the value that decides how delayed your combat actions are."], rg, gg, bg, true)
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(L["Home latency:"], ("%d|cff888888%s|r"):format(math_floor(latencyHome), MILLISECONDS_ABBR), rh, gh, bh, r, g, b)
	tooltip:AddLine(L["This is the latency of the home server, which affects things like chat, guild chat, the auction house and some other non-combat related things."], rg, gg, bg, true)
	tooltip:Show()
end 

local Performance_OnEnter = function(self)
	self.UpdateTooltip = Performance_UpdateTooltip
	self:UpdateTooltip()
end 

local Performance_OnLeave = function(self)
	Module:GetMinimapTooltip():Hide()
	self.UpdateTooltip = nil
end 

-- This is the XP and AP tooltip (and rep/honor later on) 
local Toggle_UpdateTooltip = function(self)

	local tooltip = Module:GetMinimapTooltip()

	local hasXP = PlayerHasXP()
	local hasRep = PlayerHasRep()
	local hasAP = FindActiveAzeriteItem()

	local NC = "|r"
	local rt, gt, bt = unpack(Colors.title)
	local r, g, b = unpack(Colors.normal)
	local rh, gh, bh = unpack(Colors.highlight)
	local rgg, ggg, bgg = unpack(Colors.quest.gray)
	local rg, gg, bg = unpack(Colors.quest.green)
	local rr, gr, br = unpack(Colors.quest.red)
	local green = Colors.quest.green.colorCode
	local normal = Colors.normal.colorCode
	local highlight = Colors.highlight.colorCode

	local resting, restState, restedName, mult
	local restedLeft, restedTimeLeft

	if hasXP or hasAP or hasRep then 
		tooltip:SetDefaultAnchor(self)
		tooltip:SetMaximumWidth(360)
	end

	-- XP tooltip
	-- Currently more or less a clone of the blizzard tip, we should improve!
	if hasXP then 
		resting = IsResting()
		restState, restedName, mult = GetRestState()
		restedLeft, restedTimeLeft = GetXPExhaustion(), GetTimeToWellRested()
		
		local min, max = UnitXP("player"), UnitXPMax("player")

		tooltip:AddDoubleLine(POWER_TYPE_EXPERIENCE, LEVEL or UnitLevel("player"), rt, gt, bt, rt, gt, bt)
		tooltip:AddDoubleLine(L["Current XP: "], fullXPString:format(normal..short(min)..NC, normal..short(max)..NC, highlight..math_floor(min/max*100).."%"..NC), rh, gh, bh, rgg, ggg, bgg)

		-- add rested bonus if it exists
		if (restedLeft and (restedLeft > 0)) then
			tooltip:AddDoubleLine(L["Rested Bonus: "], fullXPString:format(normal..short(restedLeft)..NC, normal..short(max * maxRested)..NC, highlight..math_floor(restedLeft/(max * maxRested)*100).."%"..NC), rh, gh, bh, rgg, ggg, bgg)
		end
		
	end 

	-- Rep tooltip
	if hasRep then 

		local name, reaction, min, max, current, factionID = GetWatchedFactionInfo()
		if (factionID and IsFactionParagon(factionID)) then
			local currentValue, threshold, _, hasRewardPending = GetFactionParagonInfo(factionID)
			if (currentValue and threshold) then
				min, max = 0, threshold
				current = currentValue % threshold
				if hasRewardPending then
					current = current + threshold
				end
			end
		end
	
		local standingID, isFriend, friendText
		local standingLabel, standingDescription
		for i = 1, GetNumFactions() do
			local factionName, description, standingId, barMin, barMax, barValue, atWarWith, canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, factionID, hasBonusRepGain, canBeLFGBonus = GetFactionInfo(i)
			
			local friendID, friendRep, friendMaxRep, friendName, friendText, friendTexture, friendTextLevel, friendThreshold, nextFriendThreshold = GetFriendshipReputation(factionID)
			
			if (factionName == name) then
				if friendID then
					isFriend = true
					if nextFriendThreshold then 
						min = friendThreshold
						max = nextFriendThreshold
					else
						min = 0
						max = friendMaxRep
						current = friendRep
					end 
					standingLabel = friendTextLevel
					standingDescription = friendText
				end
				standingID = standingId
				break
			end
		end

		if standingID then 
			if hasXP then 
				tooltip:AddLine(" ")
			end 
			if (not isFriend) then 
				standingLabel = _G["FACTION_STANDING_LABEL"..standingID]
			end 

			tooltip:AddDoubleLine(name, standingLabel, rt, gt, bt, rt, gt, bt)

			local barMax = max - min 
			local barValue = current - min
			if (barMax > 0) then 
				tooltip:AddDoubleLine(L["Current Standing: "], fullXPString:format(normal..short(current-min)..NC, normal..short(max-min)..NC, highlight..math_floor((current-min)/(max-min)*100).."%"..NC), rh, gh, bh, rgg, ggg, bgg)
			else 
				tooltip:AddDoubleLine(L["Current Standing: "], "100%", rh, gh, bh, r, g, b)
			end 
		else 
			-- Don't add additional spaces if we can't display the information
			hasRep = nil
		end
	end

	-- New BfA Artifact Power tooltip!
	if hasAP then 
		if hasXP or hasRep then 
			tooltip:AddLine(" ")
		end 

		local min, max = GetAzeriteItemXPInfo(hasAP)
		local level = GetPowerLevel(hasAP) 

		tooltip:AddDoubleLine(ARTIFACT_POWER, level, rt, gt, bt, rt, gt, bt)
		tooltip:AddDoubleLine(L["Current Artifact Power: "], fullXPString:format(normal..short(min)..NC, normal..short(max)..NC, highlight..math_floor(min/max*100).."%"..NC), rh, gh, bh, rgg, ggg, bgg)
	end 

	if hasXP then 
		if (restState == 1) then
			if resting and restedTimeLeft and restedTimeLeft > 0 then
				tooltip:AddLine(" ")
				--tooltip:AddLine(L["Resting"], rh, gh, bh)
				if restedTimeLeft > hour*2 then
					tooltip:AddLine(L["You must rest for %s additional hours to become fully rested."]:format(highlight..math_floor(restedTimeLeft/hour)..NC), r, g, b, true)
				else
					tooltip:AddLine(L["You must rest for %s additional minutes to become fully rested."]:format(highlight..math_floor(restedTimeLeft/minute)..NC), r, g, b, true)
				end
			else
				tooltip:AddLine(" ")
				--tooltip:AddLine(L["Rested"], rh, gh, bh)
				tooltip:AddLine(L["%s of normal experience gained from monsters."]:format(shortXPString:format((mult or 1)*100)), rg, gg, bg, true)
			end
		elseif (restState >= 2) then
			if not(restedTimeLeft and restedTimeLeft > 0) then 
				tooltip:AddLine(" ")
				tooltip:AddLine(L["You should rest at an Inn."], rr, gr, br)
			else
				-- No point telling people there's nothing to tell them, is there?
				--tooltip:AddLine(" ")
				--tooltip:AddLine(L["Normal"], rh, gh, bh)
				--tooltip:AddLine(L["%s of normal experience gained from monsters."]:format(shortXPString:format((mult or 1)*100)), rg, gg, bg, true)
			end
		end
	end 

	-- Only adding the sticky toggle to the toggle button for now, not the frame.
	if MouseIsOver(self) then 
		tooltip:AddLine(" ")
		if Module.db.stickyBars then 
			tooltip:AddLine(L["%s to disable sticky bars."]:format(green..L["<Left-Click>"]..NC), rh, gh, bh)
		else 
			tooltip:AddLine(L["%s to enable sticky bars."]:format(green..L["<Left-Click>"]..NC), rh, gh, bh)
		end 
	end 

	tooltip:Show()
end 

local Toggle_OnUpdate = function(self, elapsed)

	self.fadeDelay = self.fadeDelay - elapsed
	if (self.fadeDelay > 0) then 
		return
	end 

	self.Frame:SetAlpha(1 - self.timeFading / self.fadeDuration)

	if (self.timeFading >= self.fadeDuration) then 
		self.Frame:Hide()
		self.fadeDelay = nil
		self.fadeDuration = nil
		self.timeFading = nil
		self:SetScript("OnUpdate", nil)

		-- In case it got stuck, which happens
		Module:GetMinimapTooltip():Hide()

		return 
	end 

	self.timeFading = self.timeFading + elapsed
end 

local Toggle_UpdateFrame = function(self)
	local frame = self.Frame

	local db = Module.db
	if ((db.stickyBars or self.isMouseOver or frame.isMouseOver) and (not frame:IsShown())) then 

		-- Kill off any hide countdowns
		self:SetScript("OnUpdate", nil)
		self.fadeDelay = nil
		self.fadeDuration = nil
		self.timeFading = nil

		if (not frame:IsShown()) then 
			frame:SetAlpha(1)
			frame:Show()
		end 

	elseif ((not db.stickyBars) and ((not frame.isMouseOver) or (not self.isMouseOver)) and frame:IsShown()) then 

		-- Initiate hide countdown
		self.fadeDelay = .5
		self.fadeDuration = .25
		self.timeFading = 0
		self:SetScript("OnUpdate", Toggle_OnUpdate)
	end 
end

local Toggle_OnMouseUp = function(self, button)
	local db = Module.db
	db.stickyBars = not db.stickyBars

	Toggle_UpdateFrame(self)

	if self.UpdateTooltip then 
		self:UpdateTooltip()
	end 

	if Module.db.stickyBars then 
		print(self._owner.colors.title.colorCode..L["Sticky Minimap bars enabled."].."|r")
	else
		print(self._owner.colors.title.colorCode..L["Sticky Minimap bars disabled."].."|r")
	end 	
end

local Toggle_OnEnter = function(self)
	self.UpdateTooltip = Toggle_UpdateTooltip
	self.isMouseOver = true

	Toggle_UpdateFrame(self)

	self:UpdateTooltip()
end

local Toggle_OnLeave = function(self)
	local db = Module.db

	self.isMouseOver = nil
	self.UpdateTooltip = nil

	Toggle_UpdateFrame(self)
	
	if (not MouseIsOver(self.Frame)) then 
		Module:GetMinimapTooltip():Hide()
	end 
end

local RingFrame_UpdateTooltip = function(self)
	Toggle_UpdateTooltip(self._owner)
end 

local RingFrame_OnEnter = function(self)
	self.UpdateTooltip = RingFrame_UpdateTooltip
	self.isMouseOver = true

	Toggle_UpdateFrame(self._owner)

	self:UpdateTooltip()
end

local RingFrame_OnLeave = function(self)
	local db = Module.db

	self.isMouseOver = nil
	self.UpdateTooltip = nil

	Toggle_UpdateFrame(self._owner)
	
	if (not MouseIsOver(self._owner)) then 
		Module:GetMinimapTooltip():Hide()
	end 
end

local Time_UpdateTooltip = function(self)
	local tooltip = Module:GetMinimapTooltip()

	local rt, gt, bt = unpack(Colors.title)
	local r, g, b = unpack(Colors.normal)
	local rh, gh, bh = unpack(Colors.highlight)
	local rg, gg, bg = unpack(Colors.quest.green)
	local green = Colors.quest.green.colorCode
	local NC = "|r"

	local useStandardTime = Module.db.useStandardTime
	local useServerTime = Module.db.useServerTime

	-- client time
	local lh, lm, lsuffix = Module:GetLocalTime(useStandardTime)

	-- server time
	local sh, sm, ssuffix = Module:GetServerTime(useStandardTime)

	tooltip:SetDefaultAnchor(self)
	tooltip:SetMaximumWidth(360)
	tooltip:AddLine(TIMEMANAGER_TOOLTIP_TITLE, rt, gt, bt)
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_LOCALTIME, string_format(getTimeStrings(lh, lm, lsuffix, useStandardTime)), rh, gh, bh, r, g, b)
	tooltip:AddDoubleLine(TIMEMANAGER_TOOLTIP_REALMTIME, string_format(getTimeStrings(sh, sm, ssuffix, useStandardTime)), rh, gh, bh, r, g, b)
	tooltip:AddLine(" ")
	tooltip:AddLine(L["%s to toggle calendar."]:format(green..L["<Left-Click>"]..NC), rh, gh, bh)

	if useServerTime then 
		tooltip:AddLine(L["%s to use local computer time."]:format(green..L["<Middle-Click>"]..NC), rh, gh, bh)
	else 
		tooltip:AddLine(L["%s to use game server time."]:format(green..L["<Middle-Click>"]..NC), rh, gh, bh)
	end 

	if useStandardTime then 
		tooltip:AddLine(L["%s to use military (24-hour) time."]:format(green..L["<Right-Click>"]..NC), rh, gh, bh)
	else 
		tooltip:AddLine(L["%s to use standard (12-hour) time."]:format(green..L["<Right-Click>"]..NC), rh, gh, bh)
	end 

	tooltip:Show()
end 

local Time_OnEnter = function(self)
	self.UpdateTooltip = Time_UpdateTooltip
	self:UpdateTooltip()
end 

local Time_OnLeave = function(self)
	Module:GetMinimapTooltip():Hide()
	self.UpdateTooltip = nil
end 

local Time_OnClick = function(self, mouseButton)
	if (mouseButton == "LeftButton") then
		ToggleCalendar()

	elseif (mouseButton == "MiddleButton") then 
		Module.db.useServerTime = not Module.db.useServerTime

		self.clock.useServerTime = Module.db.useServerTime
		self.clock:ForceUpdate()

		if self.UpdateTooltip then 
			self:UpdateTooltip()
		end 

		if Module.db.useServerTime then 
			print(self._owner.colors.title.colorCode..L["Now using game server time."].."|r")
		else
			print(self._owner.colors.title.colorCode..L["Now using local computer time."].."|r")
		end 

	elseif (mouseButton == "RightButton") then 
		Module.db.useStandardTime = not Module.db.useStandardTime

		self.clock.useStandardTime = Module.db.useStandardTime
		self.clock:ForceUpdate()

		if self.UpdateTooltip then 
			self:UpdateTooltip()
		end 

		if Module.db.useStandardTime then 
			print(self._owner.colors.title.colorCode..L["Now using standard (12-hour) time."].."|r")
		else
			print(self._owner.colors.title.colorCode..L["Now using military (24-hour) time."].."|r")
		end 
	end
end

local Zone_OnEnter = function(self)
	local tooltip = Module:GetMinimapTooltip()

end 

local Zone_OnLeave = function(self)
	Module:GetMinimapTooltip():Hide()
end 

local PostUpdate_XP = function(element, min, max, restedLeft, restedTimeLeft)
	local description = element.Value and element.Value.Description
	if description then 
		local level = LEVEL or UnitLevel("player")
		if (level and (level > 0)) then 
			description:SetFormattedText(L["to level %s"], level + 1)
		else 
			description:SetText("")
		end 
	end 
end

local PostUpdate_Rep = function(element, current, min, max, factionName, standingID, standingLabel, isFriend)
	local description = element.Value and element.Value.Description
	if description then 
		if (standingID == MAX_REPUTATION_REACTION) then
			description:SetText(standingLabel)
		else
			if isFriend then 
				if standingLabel then 
					description:SetFormattedText(L["%s"], standingLabel)
				else
					description:SetText("")
				end 
			else 
				local nextStanding = standingID and _G["FACTION_STANDING_LABEL"..(standingID + 1)]
				if nextStanding then 
					description:SetFormattedText(L["to %s"], nextStanding)
				else
					description:SetText("")
				end 
			end 
		end 
	end 
end

local PostUpdate_AP = function(element, min, max, level)
	local description = element.Value and element.Value.Description
	if description then 
		description:SetText(L["to next trait"])
	end 
end

local XP_OverrideValue = function(element, min, max, restedLeft, restedTimeLeft)
	local value = element.Value or element:IsObjectType("FontString") and element 
	if value.showDeficit then 
		value:SetFormattedText(short(max - min))
	else 
		value:SetFormattedText(short(min))
	end
	local percent = value.Percent
	if percent then 
		if (max > 0) then 
			local percValue = math_floor(min/max*100)
			if (percValue > 0) then 
				-- removing the percentage sign
				percent:SetFormattedText("%d", percValue)
			else 
				percent:SetText("xp") -- no localization for this
			end 
		else 
			percent:SetText("xp") -- no localization for this
		end 
	end 
	if element.colorValue then 
		local color
		if restedLeft then 
			local colors = element._owner.colors
			color = colors.restedValue or colors.rested or colors.xpValue or colors.xp
		else 
			local colors = element._owner.colors
			color = colors.xpValue or colors.xp
		end 
		value:SetTextColor(color[1], color[2], color[3])
		if percent then 
			percent:SetTextColor(color[1], color[2], color[3])
		end 
	end 
end 

local Rep_OverrideValue = function(element, current, min, max, factionName, standingID, standingLabel, isFriend)
	local value = element.Value or element:IsObjectType("FontString") and element 
	local barMax = max - min 
	local barValue = current - min
	if value.showDeficit then 
		if (barMax - barValue > 0) then 
			value:SetFormattedText(short(barMax - barValue))
		else 
			value:SetText("100%")
		end 
	else 
		value:SetFormattedText(short(current - min))
	end
	local percent = value.Percent
	if percent then 
		if (max - min > 0) then 
			local percValue = math_floor((current - min)/(max - min)*100)
			if (percValue > 0) then 
				-- removing the percentage sign
				percent:SetFormattedText("%d", percValue)
			else 
				percent:SetText("rp") 
			end 
		else 
			percent:SetText("rp") 
		end 
	end 
	if element.colorValue then 
		local color
		local color = Colors[isFriend and "friendship" or "reaction"][standingID]
		value:SetTextColor(color[1], color[2], color[3])
		if percent then 
			percent:SetTextColor(color[1], color[2], color[3])
		end 
	end 
end

local AP_OverrideValue = function(element, min, max, level)
	local value = element.Value or element:IsObjectType("FontString") and element 
	if value.showDeficit then 
		value:SetFormattedText(short(max - min))
	else 
		value:SetFormattedText(short(min))
	end
	local percent = value.Percent
	if percent then 
		if (max > 0) then 
			local percValue = math_floor(min/max*100)
			if (percValue > 0) then 
				-- removing the percentage sign
				percent:SetFormattedText("%d", percValue)
			else 
				percent:SetText("ap") 
			end 
		else 
			percent:SetText("ap") 
		end 
	end 
	if element.colorValue then 
		local color = element._owner.colors.artifact
		value:SetTextColor(color[1], color[2], color[3])
		if percent then 
			percent:SetTextColor(color[1], color[2], color[3])
		end 
	end 
end 

Module.SetUpMinimap = function(self)

	local db = self.db


	-- Frame
	----------------------------------------------------
	-- This is needed to initialize the map to 
	-- the most recent version of the libarary.
	-- All other calls will fail without it.
	self:SyncMinimap() 

	-- Retrieve an unique element handler for our module
	local Handler = self:GetMinimapHandler()
	Handler.colors = Colors
	
	-- Reposition minimap tooltip 
	local tooltip = self:GetMinimapTooltip()

	-- Blob & Ring Textures
	----------------------------------------------------
	-- Set the alpha values of the various map blob and ring textures. Values range from 0-255. 
	-- Using tested versions from DiabolicUI, which makes the map IMO much more readable. 
	self:SetMinimapBlobAlpha(unpack(Layout.BlobAlpha)) 

	-- Minimap Buttons
	----------------------------------------------------
	-- We don't want them, simple as that.
	-- Will add in support for MBB later one, or make our own system. 
	self:SetMinimapAllowAddonButtons(Layout.AllowButtons)

	-- Minimap Compass
	if Layout.UseCompass then 
		self:SetMinimapCompassEnabled(true)
		self:SetMinimapCompassText(unpack(Layout.CompassTexts)) 
		self:SetMinimapCompassTextFontObject(Layout.CompassFont) 
		self:SetMinimapCompassTextColor(unpack(Layout.CompassColor)) 
		self:SetMinimapCompassRadiusInset(Layout.CompassRadiusInset) 
	end 
	
	-- Background
	if Layout.UseMapBackdrop then 
		local mapBackdrop = Handler:CreateBackdropTexture()
		mapBackdrop:SetDrawLayer("BACKGROUND")
		mapBackdrop:SetAllPoints()
		mapBackdrop:SetTexture(Layout.MapBackdropTexture)
		mapBackdrop:SetVertexColor(unpack(Layout.MapBackdropColor))
	end 

	-- Overlay
	if Layout.UseMapOverlay then 
		local mapOverlay = Handler:CreateContentTexture()
		mapOverlay:SetDrawLayer("BORDER")
		mapOverlay:SetAllPoints()
		mapOverlay:SetTexture(Layout.MapOverlayTexture)
		mapOverlay:SetVertexColor(unpack(Layout.MapOverlayColor))
	end 
	
	-- Border
	if Layout.UseMapBorder then 
		local border = Handler:CreateOverlayTexture()
		border:SetDrawLayer("BACKGROUND")
		border:SetTexture(Layout.MapBorderTexture)
		border:SetSize(unpack(Layout.MapBorderSize))
		border:SetVertexColor(unpack(Layout.MapBorderColor))
		border:SetPoint(unpack(Layout.MapBorderPlace))
		Handler.Border = border
	end 

	-- Mail
	if Layout.UseMail then 
		local mail = Handler:CreateOverlayFrame()
		mail:SetSize(unpack(Layout.MailSize)) 
		mail:Place(unpack(Layout.MailPlace)) 

		local icon = mail:CreateTexture()
		icon:SetTexture(Layout.MailTexture)
		icon:SetDrawLayer(unpack(Layout.MailTextureDrawLayer))
		icon:SetPoint(unpack(Layout.MailTexturePlace))
		icon:SetSize(unpack(Layout.MailTextureSize)) 

		if Layout.MailTextureRotation then 
			icon:SetRotation(Layout.MailTextureRotation)
		end 

		Handler.Mail = mail 
	end 

	-- Clock 
	if Layout.UseClock then 
		local clockFrame 
		if Layout.ClockFrameInOverlay then 
			clockFrame = Handler:CreateOverlayFrame("Button")
		else 
			clockFrame = Handler:CreateBorderFrame("Button")
		end 
		Handler.ClockFrame = clockFrame

		local clock = Handler:CreateFontString()
		clock:SetPoint(unpack(Layout.ClockPlace)) 
		clock:SetDrawLayer("OVERLAY")
		clock:SetJustifyH("RIGHT")
		clock:SetJustifyV("BOTTOM")
		clock:SetFontObject(Layout.ClockFont)
		clock:SetTextColor(unpack(Layout.ClockColor))
		clock.useStandardTime = self.db.useStandardTime -- standard (12-hour) or military (24-hour) time
		clock.useServerTime = self.db.useServerTime -- realm time or local time
		clock.showSeconds = false -- show seconds in the clock
		clock.OverrideValue = Clock_OverrideValue

		-- Make the clock clickable to change time settings 
		clockFrame:SetAllPoints(clock)
		clockFrame:SetScript("OnEnter", Time_OnEnter)
		clockFrame:SetScript("OnLeave", Time_OnLeave)
		clockFrame:SetScript("OnClick", Time_OnClick)

		-- Register all buttons separately, as "AnyUp" doesn't include the middle button!
		clockFrame:RegisterForClicks("RightButtonUp", "LeftButtonUp", "MiddleButtonUp")
		
		clockFrame.clock = clock
		clockFrame._owner = Handler

		clock:SetParent(clockFrame)

		Handler.Clock = clock		
	end 

	-- Zone Information
	if Layout.UseZone then 
		local zoneFrame = Handler:CreateBorderFrame()
		Handler.ZoneFrame = zoneFrame
	
		local zone = zoneFrame:CreateFontString()
		if Layout.ZonePlaceFunc then 
			zone:SetPoint(Layout.ZonePlaceFunc(Handler)) 
		else 
			zone:SetPoint(unpack(Layout.ZonePlace)) 
		end
	
		zone:SetDrawLayer("OVERLAY")
		zone:SetJustifyH("RIGHT")
		zone:SetJustifyV("BOTTOM")
		zone:SetFontObject(Layout.ZoneFont)
		zone:SetAlpha(Layout.ZoneAlpha or 1)
		zone.colorPvP = true -- color zone names according to their PvP type 
		zone.colorcolorDifficulty = true -- color instance names according to their difficulty
	
		-- Strap the frame to the text
		zoneFrame:SetAllPoints(zone)
		zoneFrame:SetScript("OnEnter", Zone_OnEnter)
		zoneFrame:SetScript("OnLeave", Zone_OnLeave)
	
		Handler.Zone = zone	
	end 

	-- Coordinates
	if Layout.UseCoordinates then 
		local coordinates = Handler:CreateBorderText()

		if Layout.CoordinatePlaceFunc then 
			coordinates:SetPoint(Layout.CoordinatePlaceFunc(Handler)) 
		else
			coordinates:SetPoint(unpack(Layout.CoordinatePlace)) 
		end 

		coordinates:SetDrawLayer("OVERLAY")
		coordinates:SetJustifyH("CENTER")
		coordinates:SetJustifyV("BOTTOM")
		coordinates:SetFontObject(Layout.CoordinateFont)
		coordinates:SetTextColor(unpack(Layout.CoordinateColor)) 
		coordinates.OverrideValue = Coordinates_OverrideValue

		Handler.Coordinates = coordinates
	end 
		
	-- Performance Information
	if Layout.UsePerformance then 
		local performanceFrame = Handler:CreateBorderFrame()
		Handler.PerformanceFrame = performanceFrame
	
		local framerate = performanceFrame:CreateFontString()
		framerate:SetDrawLayer("OVERLAY")
		framerate:SetJustifyH("RIGHT")
		framerate:SetJustifyV("BOTTOM")
		framerate:SetFontObject(Layout.FrameRateFont)
		framerate:SetTextColor(unpack(Layout.FrameRateColor))
		framerate.OverrideValue = FrameRate_OverrideValue
	
		Handler.FrameRate = framerate
	
		local latency = performanceFrame:CreateFontString()
		latency:SetDrawLayer("OVERLAY")
		latency:SetJustifyH("CENTER")
		latency:SetJustifyV("BOTTOM")
		latency:SetFontObject(Layout.LatencyFont)
		latency:SetTextColor(unpack(Layout.LatencyColor))
		latency.OverrideValue = Latency_OverrideValue
	
		Handler.Latency = latency
	
		-- Strap the frame to the text
		performanceFrame:SetScript("OnEnter", Performance_OnEnter)
		performanceFrame:SetScript("OnLeave", Performance_OnLeave)
	
		if Layout.FrameRatePlaceFunc then
			framerate:Place(Layout.FrameRatePlaceFunc(Handler)) 
		else 
			framerate:Place(unpack(Layout.FrameRatePlace)) 
		end 

		if Layout.LatencyPlaceFunc then
			latency:Place(Layout.LatencyPlaceFunc(Handler)) 
		else 
			latency:Place(unpack(Layout.LatencyPlace)) 
		end 

		if Layout.PerformanceFramePlaceAdvancedFunc then 
			Layout.PerformanceFramePlaceAdvancedFunc(performanceFrame, Handler)
		end 
	end 

	if Layout.UseStatusRings then 

		-- Ring frame
		local ringFrame = Handler:CreateOverlayFrame()
		ringFrame:Hide()
		ringFrame:SetAllPoints() -- set it to cover the map
		ringFrame:EnableMouse(true) -- make sure minimap blips and their tooltips don't punch through
		ringFrame:SetScript("OnEnter", RingFrame_OnEnter)
		ringFrame:SetScript("OnLeave", RingFrame_OnLeave)

		ringFrame:HookScript("OnShow", function() 
			local compassFrame = CogWheel("LibMinimap"):GetCompassFrame()
			if compassFrame then 
				compassFrame.supressCompass = true
			end 
		end)

		ringFrame:HookScript("OnHide", function() 
			local compassFrame = CogWheel("LibMinimap"):GetCompassFrame()
			if compassFrame then 
				compassFrame.supressCompass = nil
			end 
		end)

		-- Wait with this until now to trigger compass visibility changes
		ringFrame:SetShown(db.stickyBars) 

		-- ring frame backdrops
		local ringFrameBg = ringFrame:CreateTexture()
		ringFrameBg:SetPoint(unpack(Layout.RingFrameBackdropPlace))
		ringFrameBg:SetSize(unpack(Layout.RingFrameBackdropSize))  
		ringFrameBg:SetDrawLayer(unpack(Layout.RingFrameBackdropDrawLayer))
		ringFrameBg:SetTexture(Layout.RingFrameBackdropTexture)
		ringFrameBg:SetVertexColor(unpack(Layout.RingFrameBackdropColor))
		ringFrame.Bg = ringFrameBg

		-- outer ring
		local ring1 = ringFrame:CreateSpinBar()
		ring1:SetPoint(unpack(Layout.OuterRingPlace))
		ring1:SetSize(unpack(Layout.OuterRingSize)) 
		ring1:SetSparkOffset(Layout.OuterRingSparkOffset)
		ring1:SetSparkFlash(unpack(Layout.OuterRingSparkFlash))
		ring1:SetSparkBlendMode(Layout.OuterRingSparkBlendMode)
		ring1:SetClockwise(Layout.OuterRingClockwise) 
		ring1:SetDegreeOffset(Layout.OuterRingDegreeOffset) 
		ring1:SetDegreeSpan(Layout.OuterRingDegreeSpan)
		ring1.showSpark = Layout.OuterRingShowSpark 
		ring1.colorXP = Layout.OuterRingColorXP
		ring1.colorPower = Layout.OuterRingColorPower 
		ring1.colorStanding = Layout.OuterRingColorStanding 
		ring1.colorValue = Layout.OuterRingColorValue 
		ring1.backdropMultiplier = Layout.OuterRingBackdropMultiplier 
		ring1.sparkMultiplier = Layout.OuterRingSparkMultiplier

		-- outer ring value text
		local ring1Value = ring1:CreateFontString()
		ring1Value:SetPoint("TOP", ringFrameBg, "CENTER", 0, -2)
		ring1Value:SetJustifyH("CENTER")
		ring1Value:SetJustifyV("TOP")
		ring1Value:SetFontObject(Fonts(15, true))
		ring1Value:SetShadowOffset(0, 0)
		ring1Value:SetShadowColor(0, 0, 0, 0)
		ring1Value.showDeficit = true -- show what's missing 
		ring1.Value = ring1Value

		-- outer ring value description text
		local ring1ValueDescription = ring1:CreateFontString()
		ring1ValueDescription:SetPoint("TOP", ring1Value, "BOTTOM", 0, -1)
		ring1ValueDescription:SetWidth(100)
		ring1ValueDescription:SetTextColor(Colors.quest.gray[1], Colors.quest.gray[2], Colors.quest.gray[3])
		ring1ValueDescription:SetJustifyH("CENTER")
		ring1ValueDescription:SetJustifyV("TOP")
		ring1ValueDescription:SetFontObject(Fonts(12, true))
		ring1ValueDescription:SetShadowOffset(0, 0)
		ring1ValueDescription:SetShadowColor(0, 0, 0, 0)
		ring1ValueDescription:SetIndentedWordWrap(false)
		ring1ValueDescription:SetWordWrap(true)
		ring1ValueDescription:SetNonSpaceWrap(false)
		ring1.Value.Description = ring1ValueDescription

		-- inner ring 
		local ring2 = ringFrame:CreateSpinBar()
		ring2:SetPoint(unpack(Layout.InnerRingPlace))
		ring2:SetSize(unpack(Layout.InnerRingSize)) 
		ring2:SetSparkSize(unpack(Layout.InnerRingSparkSize))
		ring2:SetSparkInset(Layout.InnerRingSparkInset)
		ring2:SetSparkOffset(Layout.InnerRingSparkOffset)
		ring2:SetSparkFlash(unpack(Layout.InnerRingSparkFlash))
		ring2:SetSparkBlendMode(Layout.InnerRingSparkBlendMode)
		ring2:SetClockwise(Layout.InnerRingClockwise) 
		ring2:SetDegreeOffset(Layout.InnerRingDegreeOffset) 
		ring2:SetDegreeSpan(Layout.InnerRingDegreeSpan)
		ring2:SetStatusBarTexture(Layout.InnerRingBarTexture)
		ring2.showSpark = Layout.InnerRingShowSpark 
		ring2.colorXP = Layout.InnerRingColorXP
		ring2.colorPower = Layout.InnerRingColorPower 
		ring2.colorStanding = Layout.InnerRingColorStanding 
		ring2.colorValue = Layout.InnerRingColorValue 
		ring2.backdropMultiplier = Layout.InnerRingBackdropMultiplier 
		ring2.sparkMultiplier = Layout.InnerRingSparkMultiplier

		-- inner ring value text
		local ring2Value = ring2:CreateFontString()
		ring2Value:SetPoint("BOTTOM", ringFrameBg, "CENTER", 0, 2)
		ring2Value:SetJustifyH("CENTER")
		ring2Value:SetJustifyV("TOP")
		ring2Value:SetFontObject(Fonts(15, true))
		ring2Value:SetShadowOffset(0, 0)
		ring2Value:SetShadowColor(0, 0, 0, 0)
		ring2Value.showDeficit = true -- show what's missing 
		ring2.Value = ring2Value

		-- Store the bars locally
		Spinner[1] = ring1
		Spinner[2] = ring2
		
		-- Toggle button for ring frame
		local toggle = Handler:CreateOverlayFrame()
		toggle:SetFrameLevel(toggle:GetFrameLevel() + 10) -- need this above the ring frame and the rings
		toggle:SetPoint("CENTER", Handler, "BOTTOM", 2, -6)
		toggle:SetSize(56,56)
		toggle:EnableMouse(true)
		toggle:SetScript("OnEnter", Toggle_OnEnter)
		toggle:SetScript("OnLeave", Toggle_OnLeave)
		toggle:SetScript("OnMouseUp", Toggle_OnMouseUp)
		toggle._owner = Handler
		ringFrame._owner = toggle
		toggle.Frame = ringFrame

		local toggleBackdrop = toggle:CreateTexture()
		toggleBackdrop:SetDrawLayer("BACKGROUND")
		toggleBackdrop:SetSize(100,100)
		toggleBackdrop:SetPoint("CENTER", 0, 0)
		toggleBackdrop:SetTexture(GetMediaPath("point_plate"))
		toggleBackdrop:SetVertexColor(Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3])

		local innerPercent = ringFrame:CreateFontString()
		innerPercent:SetDrawLayer("OVERLAY")
		innerPercent:SetJustifyH("CENTER")
		innerPercent:SetJustifyV("MIDDLE")
		innerPercent:SetFontObject(Fonts(15, true))
		innerPercent:SetShadowOffset(0, 0)
		innerPercent:SetShadowColor(0, 0, 0, 0)
		innerPercent:SetPoint("CENTER", ringFrameBg, "CENTER", 2, -64)
		ring2.Value.Percent = innerPercent

		local outerPercent = toggle:CreateFontString()
		outerPercent:SetDrawLayer("OVERLAY")
		outerPercent:SetJustifyH("CENTER")
		outerPercent:SetJustifyV("MIDDLE")
		outerPercent:SetFontObject(Fonts(16, true))
		outerPercent:SetShadowOffset(0, 0)
		outerPercent:SetShadowColor(0, 0, 0, 0)
		outerPercent:SetPoint("CENTER", 1, -1)
		ring1.Value.Percent = outerPercent

		Handler.Toggle = toggle
	end 

	if Layout.UseGroupFinderEye then 
		local queueButton = _G.QueueStatusMinimapButton

		local button = Handler:CreateOverlayFrame()
		button:SetFrameLevel(button:GetFrameLevel() + 10) 
		button:Place(unpack(Layout.GroupFinderEyePlace))
		button:SetSize(unpack(Layout.GroupFinderEyeSize))

		queueButton:SetParent(button)
		queueButton:ClearAllPoints()
		queueButton:SetPoint("CENTER", 0, 0)
		queueButton:SetSize(unpack(Layout.GroupFinderEyeSize))

		if Layout.UseGroupFinderEyeBackdrop then 
			local backdrop = queueButton:CreateTexture()
			backdrop:SetDrawLayer("BACKGROUND", -6)
			backdrop:SetPoint("CENTER", 0, 0)
			backdrop:SetSize(unpack(Layout.GroupFinderEyeBackdropSize))
			backdrop:SetTexture(Layout.GroupFinderEyeBackdropTexture)
			backdrop:SetVertexColor(unpack(Layout.GroupFinderEyeBackdropColor))
		end 

		if Layout.GroupFinderEyeTexture then 
			local UIHider = CreateFrame("Frame")
			UIHider:Hide()
			queueButton.Eye.texture:SetParent(UIHider)
			queueButton.Eye.texture:SetAlpha(0)

			--local iconTexture = button:CreateTexture()
			local iconTexture = queueButton:CreateTexture()
			iconTexture:SetDrawLayer("ARTWORK", 1)
			iconTexture:SetPoint("CENTER", 0, 0)
			iconTexture:SetSize(unpack(Layout.GroupFinderEyeSize))
			iconTexture:SetTexture(Layout.GroupFinderEyeTexture)
			iconTexture:SetVertexColor(unpack(Layout.GroupFinderEyeColor))
		else
			queueButton.Eye:SetSize(unpack(Layout.GroupFinderEyeSize)) 
			queueButton.Eye.texture:SetSize(unpack(Layout.GroupFinderEyeSize))
		end 

		if Layout.GroupFinderQueueStatusPlace then 
			QueueStatusFrame:ClearAllPoints()
			QueueStatusFrame:SetPoint(unpack(Layout.GroupFinderQueueStatusPlace))
		end 
	end 

end 

-- Perform and initial update of all elements, 
-- as this is not done automatically by the back-end.
Module.EnableAllElements = function(self)
	local Handler = self:GetMinimapHandler()
	Handler:EnableAllElements()
end 

-- Set the mask texture
Module.UpdateMinimapMask = function(self)
	-- Transparency in these textures also affect the indoors opacity 
	-- of the minimap, something changing the map alpha directly does not. 
	self:SetMinimapMaskTexture(Layout.MaskTexture)
end 

-- Set the size and position 
-- Can't change this in combat, will cause taint!
Module.UpdateMinimapSize = function(self)
	if InCombatLockdown() then 
		return self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	end

	self:SetMinimapSize(unpack(Layout.Size)) 
	self:SetMinimapPosition(unpack(Layout.Place)) 
end 

Module.UpdateBars = function(self, event, ...)
	if (not Layout.UseStatusRings) then 
		return 
	end 

	local Handler = self:GetMinimapHandler()

	-- Figure out what should be shown. 
	-- Priority us currently xp > rep > ap
	local hasRep = PlayerHasRep()
	local hasXP = PlayerHasXP()
	local hasAP = FindActiveAzeriteItem()

	-- Will include choices later on
	local first, second 
	if hasXP then 
		first = "XP"
	elseif hasRep then 
		first = "Reputation"
	elseif hasAP then 
		first = "ArtifactPower"
	end 
	if first then 
		if hasRep and (first ~= "Reputation") then 
			second = "Reputation"
		elseif hasAP and (first ~= "ArtifactPower") then 
			second = "ArtifactPower"
		end
	end 

	if (first or second) then
		if (not Handler.Toggle:IsShown()) then  
			Handler.Toggle:Show()
		end

		-- Dual bars
		if (first and second) then

			-- Setup the bars and backdrops for dual bar mode
			if self.spinnerMode ~= "Dual" then 

				-- Set the backdrop to the two bar backdrop
				Handler.Toggle.Frame.Bg:SetTexture(Layout.RingFrameBackdropDoubleTexture)

				-- Update the look of the outer spinner
				Spinner[1]:SetStatusBarTexture(Layout.RingFrameOuterRingTexture)
				Spinner[1]:SetSparkSize(unpack(Layout.RingFrameOuterRingSparkSize))
				Spinner[1]:SetSparkInset(unpack(Layout.RingFrameOuterRingSparkInset))

				if Layout.RingFrameOuterRingValueFunc then 
					Layout.RingFrameOuterRingValueFunc(Spinner[1].Value, Handler)
				end 

				Spinner[1].PostUpdate = nil
			end

			-- Assign the spinners to the elements
			if (self.spinner1 ~= first) then 

				-- Disable the old element 
				self:DisableMinimapElement(first)

				-- Link the correct spinner
				Handler[first] = Spinner[1]

				-- Assign the correct post updates
				if (first == "XP") then 
					Handler[first].OverrideValue = XP_OverrideValue
	
				elseif (first == "Reputation") then 
					Handler[first].OverrideValue = Rep_OverrideValue
	
				elseif (first == "ArtifactPower") then 
					Handler[first].OverrideValue = AP_OverrideValue
				end 

				-- Enable the updated element 
				self:EnableMinimapElement(first)

				-- Run an update
				Handler[first]:ForceUpdate()
			end

			if (self.spinner2 ~= second) then 

				-- Disable the old element 
				self:DisableMinimapElement(second)

				-- Link the correct spinner
				Handler[second] = Spinner[2]

				-- Assign the correct post updates
				if (second == "XP") then 
					Handler[second].OverrideValue = XP_OverrideValue
	
				elseif (second == "Reputation") then 
					Handler[second].OverrideValue = Rep_OverrideValue
	
				elseif (second == "ArtifactPower") then 
					Handler[second].OverrideValue = AP_OverrideValue
				end 

				-- Enable the updated element 
				self:EnableMinimapElement(second)

				-- Run an update
				Handler[second]:ForceUpdate()
			end

			-- Store the current modes
			self.spinnerMode = "Dual"
			self.spinner1 = first
			self.spinner2 = second

		-- Single bar
		else

			-- Setup the bars and backdrops for single bar mode
			if (self.spinnerMode ~= "Single") then 

				-- Set the backdrop to the single thick bar backdrop
				Handler.Toggle.Frame.Bg:SetTexture(Layout.RingFrameBackdropTexture)

				-- Update the look of the outer spinner to the big single bar look
				Spinner[1]:SetStatusBarTexture(Layout.RingFrameSingleRingTexture)
				Spinner[1]:SetSparkSize(unpack(Layout.RingFrameSingleRingSparkSize))
				Spinner[1]:SetSparkInset(unpack(Layout.RingFrameSingleRingSparkInset))

				if Layout.RingFrameSingleRingValueFunc then 
					Layout.RingFrameSingleRingValueFunc(Spinner[1].Value, Handler)
				end 

				-- Hide 2nd spinner values
				Spinner[2].Value:SetText("")
				Spinner[2].Value.Percent:SetText("")
			end 		

			-- Disable any previously active secondary element
			if self.spinner2 and Handler[self.spinner2] then 
				self:DisableMinimapElement(self.spinner2)
				Handler[self.spinner2] = nil
			end 

			-- Update the element if needed
			if (self.spinner1 ~= first) then 

				-- Update pointers and callbacks to the active element
				Handler[first] = Spinner[1]
				Handler[first].OverrideValue = hasXP and XP_OverrideValue or hasRep and Rep_OverrideValue or AP_OverrideValue
				Handler[first].PostUpdate = hasXP and PostUpdate_XP or hasRep and PostUpdate_Rep or PostUpdate_AP

				-- Enable the active element
				self:EnableMinimapElement(first)

				-- Make sure descriptions are updated
				Handler[first].Value.Description:Show()

				-- Update the visible element
				Handler[first]:ForceUpdate()
			end 

			-- If the second spinner is still shown, hide it!
			if (Spinner[2]:IsShown()) then 
				Spinner[2]:Hide()
			end 

			-- Store the current modes
			self.spinnerMode = "Single"
			self.spinner1 = first
			self.spinner2 = nil
		end 

		-- Post update the frame, could be sticky
		Toggle_UpdateFrame(Handler.Toggle)

	else 
		Handler.Toggle:Hide()
		Handler.Toggle.Frame:Hide()
	end 

end

Module.OnEvent = function(self, event, ...)
	if (event == "PLAYER_LEVEL_UP") then 
		local level = ...
		if (level and (level ~= LEVEL)) then
			LEVEL = level
		else
			local level = UnitLevel("player")
			if (not LEVEL) or (LEVEL < level) then
				LEVEL = level
			end
		end
	end

	if (event == "PLAYER_REGEN_ENABLED") then 
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	end

	if (event == "PLAYER_ENTERING_WORLD") or (event == "VARIABLES_LOADED") then 
		self:UpdateMinimapSize()
		self:UpdateMinimapMask()
	end

	if Layout.UseStatusRings then 
		self:UpdateBars()
	end 
end 

Module.PreInit = function(self)
	local PREFIX = Core:GetPrefix()

	Colors = CogWheel("LibDB"):GetDatabase(PREFIX..": Colors")
	Fonts = CogWheel("LibDB"):GetDatabase(PREFIX..": Fonts")
	Functions = CogWheel("LibDB"):GetDatabase(PREFIX..": Functions")
	Layout = CogWheel("LibDB"):GetDatabase(PREFIX..": Layout [Minimap]")
	L = CogWheel("LibLocale"):GetLocale(PREFIX)

	GetMediaPath = Functions.GetMediaPath
	PlayerHasRep = Functions.PlayerHasRep
	PlayerHasXP = Functions.PlayerHasXP
end 

Module.OnInit = function(self)
	self.db = self:NewConfig("Minimap", defaults, "global")

	self:SetUpMinimap()

	if Layout.UseStatusRings then 
		self:UpdateBars()
	end
end 

Module.OnEnable = function(self)

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent") -- don't we always need this? :)
	self:RegisterEvent("VARIABLES_LOADED", "OnEvent") -- size and mask must be updated after this

	if Layout.UseStatusRings then 
		self:RegisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED", "OnEvent") -- Bar count updates
		self:RegisterEvent("DISABLE_XP_GAIN", "OnEvent")
		self:RegisterEvent("ENABLE_XP_GAIN", "OnEvent")
		self:RegisterEvent("PLAYER_ALIVE", "OnEvent")
		self:RegisterEvent("PLAYER_FLAGS_CHANGED", "OnEvent")
		self:RegisterEvent("PLAYER_LEVEL_UP", "OnEvent")
		self:RegisterEvent("PLAYER_XP_UPDATE", "OnEvent")
		self:RegisterEvent("UPDATE_FACTION", "OnEvent")
	end 

	-- Enable all minimap elements
	self:EnableAllElements()
end 
