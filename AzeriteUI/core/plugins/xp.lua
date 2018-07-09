
-- Lua API
local _G = _G
local math_floor = math.floor
local math_min = math.min
local tonumber = tonumber
local tostring = tostring

-- WoW API
local GetRestState = _G.GetRestState
local GetTimeToWellRested = _G.GetTimeToWellRested
local GetXPExhaustion = _G.GetXPExhaustion
local IsResting = _G.IsResting
local UnitXP = _G.UnitXP
local UnitXPMax = _G.UnitXPMax


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


local UpdateValue = function(element, min, max)
	if element.OverrideValue then
		return element:OverrideValue(unit, min, max)
	end

	local value = element.Value or element:IsObjectType("FontString") and element 
	value:SetFormattedText(short(min))

	if element.colorValue then 
		local color = element._owner.colors[restedLeft and "rested" or "xp"] 
		value:SetTextColor(color[1], color[2], color[3])
	end 

end 

local Update = function(self, event, ...)
	local element = self.XP
	if element.PreUpdate then
		element:PreUpdate()
	end

	local resting = IsResting()
	local restState, restedName, mult = GetRestState()
	local restedLeft, restedTimeLeft = GetXPExhaustion(), GetTimeToWellRested()
	local min, max = UnitXP("player"), UnitXPMax("player")

	if element:IsObjectType("StatusBar") then 
		element:SetMinMaxValues(0, max)
		element:SetValue(min)

		if element.colorXP then 
			local color = self.colors[restedLeft and "rested" or "xp"] 
			element:SetStatusBarColor(color[1], color[2], color[3])
		end 
	end 

	if element.Value then 
		element:UpdateValue(min, max)
	end 

	if element.Rested then
		element.Rested:SetMinMaxValues(0, max)
		element.Rested:SetValue(math_min(max, min + (restedLeft or 0)))
		
		if element.colorRested then 
			element.Rested:SetStatusBarColor()
		end 
	end 

	if element.PostUpdate then 
		element:PostUpdate(min, max)
	end 
	
end 

local Proxy = function(self, ...)
	return (self.XP.Override or Update)(self, ...)
end 

local ForceUpdate = function(element, ...)
	return Proxy(element._owner, "Forced", ...)
end

local Enable = function(self)
	local element = self.XP
	if element then
		element._owner = self
		element.ForceUpdate = ForceUpdate
		element.UpdateValue = UpdateValue

		self:RegisterEvent("PLAYER_ENTERING_WORLD", Proxy, true)
		self:RegisterEvent("PLAYER_LOGIN", Proxy, true)
		self:RegisterEvent("PLAYER_ALIVE", Proxy, true)
		self:RegisterEvent("PLAYER_LEVEL_UP", Proxy, true)
		self:RegisterEvent("PLAYER_XP_UPDATE", Proxy, true)
		self:RegisterEvent("PLAYER_FLAGS_CHANGED", Proxy, true)
		self:RegisterEvent("DISABLE_XP_GAIN", Proxy, true)
		self:RegisterEvent("ENABLE_XP_GAIN", Proxy, true)
		self:RegisterEvent("PLAYER_UPDATE_RESTING", Proxy, true)
	
		return true
	end
end 

local Disable = function(self)
	local element = self.XP
	if element then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD", Proxy)
		self:UnregisterEvent("PLAYER_LOGIN", Proxy)
		self:UnregisterEvent("PLAYER_ALIVE", Proxy)
		self:UnregisterEvent("PLAYER_LEVEL_UP", Proxy)
		self:UnregisterEvent("PLAYER_XP_UPDATE", Proxy)
		self:UnregisterEvent("PLAYER_FLAGS_CHANGED", Proxy)
		self:UnregisterEvent("DISABLE_XP_GAIN", Proxy)
		self:UnregisterEvent("ENABLE_XP_GAIN", Proxy)
		self:UnregisterEvent("PLAYER_UPDATE_RESTING", Proxy)
	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (CogWheel("LibUnitFrame", true)), (CogWheel("LibNamePlate", true)), (CogWheel("LibMinimap", true)) }) do 
	Lib:RegisterElement("XP", Enable, Disable, Proxy, 3)
end 
