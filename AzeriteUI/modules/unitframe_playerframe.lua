local ADDON = ...

local AzeriteUI = CogWheel("CogModule"):GetModule("AzeriteUI")
if (not AzeriteUI) then 
	return 
end

local UnitFramePlayer = AzeriteUI:NewModule("UnitFramePlayer", "CogDB", "CogEvent", "CogUnitFrame", "CogStatusBar")
local Colors = CogWheel("CogDB"):GetDatabase("AzeriteUI: Colors")

-- Lua API
local _G = _G
local unpack = unpack

-- WoW API
local GetQuestGreenRange = _G.GetQuestGreenRange
local UnitLevel = _G.UnitLevel

-- Current player level
local LEVEL = UnitLevel("player") 


-- Health Bar Map
-- (Texture Size 512x64, Growth: RIGHT)
local barMap = {
	{ keyPercent =   0/512, topOffset = -24/64, bottomOffset = -39/64 }, -- #1: begins growing from zero height
	{ keyPercent =   9/512, topOffset =   0/64, bottomOffset = -16/64 }, -- #2: normal size begins
	{ keyPercent = 460/512, topOffset =   0/64, bottomOffset = -16/64 }, -- #3: starts growing from the bottom
	{ keyPercent = 478/512, topOffset =   0/64, bottomOffset =   0/64 }, -- #4: bottom peak, now starts shrinking from the bottom
	{ keyPercent = 483/512, topOffset =   0/64, bottomOffset =  -3/64 }, -- #4: bottom peak, now starts shrinking from the bottom
	{ keyPercent = 507/512, topOffset =   0/64, bottomOffset = -46/64 }, -- #5: starts shrinking from the top
	{ keyPercent = 512/512, topOffset = -11/64, bottomOffset = -54/64 }  -- #6: ends at zero height
}

-- Power Crystal Map
-- (Texture Size 256, 256, Growth: UP)
-- (topOffset = left - bottomOffset = right)
local crystalMap2 = {
	top = {
		{ keyPercent =   0/256, offset =  -65/256 }, -- #1: 
		{ keyPercent =  72/256, offset =    0/256 }, -- #2: 
		{ keyPercent = 116/256, offset =  -16/256 }, -- #3: 
		{ keyPercent = 128/256, offset =  -28/256 }, -- #4: 
		{ keyPercent = 256/256, offset =  -84/256 }, -- #5: 
	},
	bottom = {
		{ keyPercent =   0/256, offset =  -47/256 }, -- #1: 
		{ keyPercent =  84/256, offset =    0/256 }, -- #2: 
		{ keyPercent = 135/256, offset =  -24/256 }, -- #3: 
		{ keyPercent = 142/256, offset =  -32/256 }, -- #4: 
		{ keyPercent = 225/256, offset =  -79/256 }, -- #5: 
		{ keyPercent = 256/256, offset = -168/256 }, -- #6: 
	}
}


-- Utility Functions
-----------------------------------------------------------------

-- Returns the correct difficulty color compared to the player
local getDifficultyColorByLevel = function(level)
	level = level - LEVEL
	if (level > 4) then
		return C.General.DimRed.colorCode
	elseif (level > 2) then
		return C.General.Orange.colorCode
	elseif (level >= -2) then
		return C.General.Normal.colorCode
	elseif (level >= -GetQuestGreenRange()) then
		return C.General.OffGreen.colorCode
	else
		return C.General.Gray.colorCode
	end
end

-- Proxy function to get media from our local media folder
local getPath = function(fileName)
	return ([[Interface\AddOns\%s\media\%s.tga]]):format(ADDON, fileName)
end 


-- Callbacks
-----------------------------------------------------------------

-- Number abbreviations
local OverrideValue = function(fontString, unit, min, max)
	if (min >= 1e8) then 		fontString:SetFormattedText("%dm", min/1e6) 	-- 100m, 1000m, 2300m, etc
	elseif (min >= 1e6) then 	fontString:SetFormattedText("%.1fm", min/1e6) 	-- 1.0m - 99.9m 
	elseif (min >= 1e5) then 	fontString:SetFormattedText("%dk", min/1e3) 	-- 100k - 999k
	elseif (min >= 1e3) then 	fontString:SetFormattedText("%.1fk", min/1e3) 	-- 1.0k - 99.9k
	elseif (min > 0) then 		fontString:SetText(min) 						-- 1 - 999
	else 						fontString:SetText("")
	end 
end 



-- Main Styling Function
local Style = function(self, unit, id, ...)

	-- Frame
	-----------------------------------------------------------

	self:SetSize(329, 70)
	self:Place("BOTTOMLEFT", 145, 85)

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


	-- Bars
	-----------------------------------------------------------

	-- health
	local health = content:CreateStatusBar(self)
	health:SetFrameLevel(health:GetFrameLevel() + 3) -- raise it above the power/mana frames
	health:SetSize(289, 30)
	health:Place("BOTTOMLEFT", 20, 20)
	health:SetStatusBarTexture(getPath("hp_cap_bar"))
	health:SetStatusBarColor(self.colors.General.Health[1], self.colors.General.Health[2], self.colors.General.Health[3], .85)
	health:SetSparkColor( 255/255,  27/255,   0/255 )
	health:SetSparkMap(barMap)
	health.frequent = 1/120
	self.Health = health

	-- health case 
	local healthBg = health:CreateTexture()
	healthBg:SetDrawLayer("BACKGROUND", -1)
	healthBg:SetSize(329, 70)
	healthBg:SetPoint("CENTER", 0, 0)
	healthBg:SetTexture(getPath("hp_cap_case"))
	healthBg:SetVertexColor(unpack(self.colors.General.Overlay)) --assume global artwork color?
	self.HealthBG = healthBg

	-- health bar backdrop
	local healthBg = health:CreateTexture()
	healthBg:SetDrawLayer("BACKGROUND", -2)
	healthBg:SetSize(289, 30)
	healthBg:SetPoint("CENTER", 0, 0)
	healthBg:SetTexture(getPath("hp_cap_bar"))
	healthBg:SetVertexColor( 0, 0, 0, .25 ) 
	self.HealthBG = healthBg
	
	-- health value text
	local healthVal = health:CreateFontString()
	healthVal:SetPoint("LEFT", 20, 3)
	healthVal:SetDrawLayer("OVERLAY")
	healthVal:SetFontObject(GameFontNormal)
	healthVal:SetFont(GameFontNormal:GetFont(), 14, "OUTLINE")
	healthVal:SetJustifyH("CENTER")
	healthVal:SetJustifyV("MIDDLE")
	healthVal:SetShadowOffset(0, 0)
	healthVal:SetShadowColor(0, 0, 0, 0)
	healthVal:SetTextColor( 240/255, 240/255, 240/255, .5)
	self.Health.Value = healthVal
	self.Health.Value.Override = OverrideValue
	
	-- mana orb 
	local mana = content:CreateOrb(self)
	mana:SetSize(85, 85)
	mana:Place("RIGHT", health, "LEFT", -12, 26) -- 8, 26
	mana:SetStatusBarTexture(getPath("pw_orb_bar4"), getPath("pw_orb_bar3"), getPath("pw_orb_bar3"))
	mana:SetStatusBarColor(unpack(self.colors.Power.MANA))
	self.Mana = mana

	-- mana backdrop
	local manaBg = mana:CreateTexture()
	manaBg:SetDrawLayer("BACKGROUND", -2)
	manaBg:SetSize(85, 85)
	manaBg:SetPoint("CENTER", 0, 0)
	manaBg:SetTexture(getPath("pw_orb_bar3"))
	manaBg:SetVertexColor(  22/255,  26/255, 22/255, .82) 
	self.ManaBG = manaBg

	-- mana shade
	local manaFg2 = mana:GetOverlay():CreateTexture()
	manaFg2:SetDrawLayer("BORDER", -1)
	manaFg2:SetSize(85, 85)
	manaFg2:SetPoint("CENTER", 0, 0)
	manaFg2:SetTexture(getPath("shade_circle"))
	manaFg2:SetVertexColor(  0, 0, 0, 1) 
	self.ManaFG2 = manaFg2
	
	-- mana overlay case
	local manaFg = mana:GetOverlay():CreateTexture()
	manaFg:SetDrawLayer("BORDER")
	manaFg:SetSize(150, 150)
	manaFg:SetPoint("CENTER", 0, 0)
	manaFg:SetTexture(getPath("pw_orb_case"))
	manaFg:SetVertexColor( 188/255, 205/255, 188/255, 1) 
	self.ManaFG = manaFg
	
	-- mana value text
	local manaVal = mana:GetOverlay():CreateFontString()
	manaVal:SetPoint("CENTER", 2, 0)
	manaVal:SetDrawLayer("OVERLAY")
	manaVal:SetFontObject(GameFontNormal)
	manaVal:SetFont(GameFontNormal:GetFont(), 14, "OUTLINE")
	manaVal:SetJustifyH("CENTER")
	manaVal:SetJustifyV("MIDDLE")
	manaVal:SetShadowOffset(0, 0)
	manaVal:SetShadowColor(0, 0, 0, 0)
	manaVal:SetTextColor( 240/255, 240/255, 240/255, .4)
	self.Mana.Value = manaVal
	self.Mana.Value.Override = OverrideValue

	-- power
	local power = content:CreateStatusBar(self)
	power:SetSize(90, 105)
	power:Place("RIGHT", health, "LEFT", -6, 47)
	power:SetStatusBarTexture(getPath("pw_crystal_bar"))
	power:SetOrientation("UP")
	power:SetSparkMap(crystalMap2)
	power.HideMana = true 
	self.Power = power

	-- power backdrop
	local powerBg = power:CreateTexture()
	powerBg:SetDrawLayer("BACKGROUND", -2)
	powerBg:SetSize(100, 115)
	powerBg:SetPoint("CENTER", 0, 0)
	powerBg:SetTexture(getPath("pw_crystal_back"))
	powerBg:SetVertexColor(1, 1, 1, .85) 
	self.PowerBG = powerBg

	-- power bar backdrop
	local powerBg2 = power:CreateTexture()
	powerBg2:SetDrawLayer("BACKGROUND", -1)
	powerBg2:SetSize(90, 105)
	powerBg2:SetPoint("CENTER", 0, 0)
	powerBg2:SetTexture(getPath("pw_crystal_back"))
	powerBg2:SetVertexColor(0, 0, 0, .25) 
	self.PowerBG2 = powerBg2

	-- power overlay art
	local powerFg = power:CreateTexture()
	powerFg:SetSize(118, 57)
	powerFg:SetPoint("BOTTOM", 6, -24)
	powerFg:SetDrawLayer("ARTWORK")
	powerFg:SetTexture(getPath("pw_crystal_case"))
	powerFg:SetVertexColor(unpack(self.colors.General.Overlay))
	self.PowerFG = powerFg

	-- power value text
	local powerVal = power:CreateFontString()
	powerVal:SetPoint("CENTER", 0, -12)
	powerVal:SetDrawLayer("OVERLAY")
	powerVal:SetFontObject(GameFontNormal)
	powerVal:SetFont(GameFontNormal:GetFont(), 14, "OUTLINE")
	powerVal:SetJustifyH("CENTER")
	powerVal:SetJustifyV("MIDDLE")
	powerVal:SetShadowOffset(0, 0)
	powerVal:SetShadowColor(0, 0, 0, 0)
	powerVal:SetTextColor( 240/255, 240/255, 240/255, .4)
	self.Power.Value = powerVal
	self.Power.Value.Override = OverrideValue

	
end 

UnitFramePlayer.OnEvent = function(self, event, ...)
	if (event == "PLAYER_LEVEL_UP") then 
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

UnitFramePlayer.OnInit = function(self)
	local playerFrame = self:SpawnUnitFrame("player", "UICenter", Style)

	self.frame = playerFrame
end 

UnitFramePlayer.OnEnable = function(self)
	self:RegisterEvent("PLAYER_LEVEL_UP", "OnEvent")
end 
