
local LibClientBuild = CogWheel("LibClientBuild")
assert(LibClientBuild, "ExtraPower requires LibClientBuild to be loaded.")

-- Lua API
local _G = _G
local math_floor = math.floor
local pairs = pairs
local tonumber = tonumber
local tostring = tostring
local unpack = unpack

-- WoW API
local UnitIsConnected = _G.UnitIsConnected
local UnitIsDeadOrGhost = _G.UnitIsDeadOrGhost
local UnitIsTapDenied = _G.UnitIsTapDenied 
local UnitPlayerControlled = _G.UnitPlayerControlled
local UnitPower = _G.UnitPower
local UnitPowerMax = _G.UnitPowerMax
local UnitPowerType = _G.UnitPowerType

-- WoW Client Constants
local ENGINE_801 = LibClientBuild:IsBuild("8.0.1")


-- Number abbreviations
---------------------------------------------------------------------	
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

local UpdateValue = function(element, unit, min, max, powerType, powerID, disconnected, dead, tapped)
	local value = element.Value or element:IsObjectType("FontString") and element 
	if value then
		if (min == 0 or max == 0) and (not value.showAtZero) then
			value:SetText("")
		else
			if value.showDeficit then
				if value.showPercent then
					if value.showMaximum then
						value:SetFormattedText("%s / %s - %d%%", short(max - min), short(max), math_floor(min/max * 100))
					else
						value:SetFormattedText("%s / %d%%", short(max - min), math_floor(min/max * 100))
					end
				else
					if value.showMaximum then
						value:SetFormattedText("%s / %s", short(max - min), short(max))
					else
						value:SetFormattedText("%s", short(max - min))
					end
				end
			else
				if value.showPercent then
					if value.showMaximum then
						value:SetFormattedText("%s / %s - %d%%", short(min), short(max), math_floor(min/max * 100))
					else
						value:SetFormattedText("%s / %d%%", short(min), math_floor(min/max * 100))
					end
				else
					if value.showMaximum then
						value:SetFormattedText("%s / %s", short(min), short(max))
					else
						value:SetFormattedText("%s", short(min))
					end
				end
			end
		end
	end
end 

local UpdateColor = function(element, unit, min, max, powerType, powerID, disconnected, dead, tapped)
	if element.OverrideColor then
		return element:OverrideColor(unit, min, max, powerType, powerID, disconnected, dead, tapped)
	end
	local self = element._owner
	local r, g, b
	if disconnected then
		r, g, b = unpack(self.colors.disconnected)
	elseif dead then
		r, g, b = unpack(self.colors.dead)
	elseif tapped then
		r, g, b = unpack(self.colors.tapped)
	else
		r, g, b = unpack(powerType and self.colors.power[powerType] or self.colors.power.UNUSED)
	end
	element:SetStatusBarColor(r, g, b)
end 

local Update = function(self, event, unit)
	if (not unit) or (unit ~= self.unit) then 
		return 
	end 

	local element = self.ExtraPower
	if element.PreUpdate then
		element:PreUpdate(unit)
	end

	local powerID, powerType = UnitPowerType(unit)

	-- Check if the element is exclusive to a certain power type
	if element.exclusiveResource then 

		-- If the new powertype isn't the one tracked, 
		-- we hide the element.
		if (powerType ~= element.exclusiveResource) then 
			element.powerType = powerType
			element:Clear()
			element:Hide()
			return 

		-- If the previous powertype wasn't the one tracked, 
		-- but the current one is, we need to show the element again. 
		elseif (element.powerType ~= element.exclusiveResource) then 
			element.powerType = powerType
			element:Show()
		end 

	-- Check if the min should be hidden on a certain resource type
	elseif element.ignoredResource then 

		-- If the new powertype is the one ignored, 
		-- we hide the element.
		if (powerType == element.ignoredResource) then 
			element.powerType = powerType
			element:Clear()
			element:Hide()
			return

		-- If the previous powertype was the ignored type, 
		-- but the current is something else, 
		-- we need to show the element again. 
		elseif (element.powerType == element.ignoredResource) then 
			element:Show()
		end  
	end 

	if (element.powerType ~= powerType) then
		element:Clear()
		element.powerType = powerType
	end

	local disconnected = not UnitIsConnected(unit)
	local dead = UnitIsDeadOrGhost(unit)
	local min = dead and 0 or UnitPower(unit, powerID)
	local max = dead and 0 or UnitPowerMax(unit, powerID)
	local tapped = (not UnitPlayerControlled(unit)) and UnitIsTapDenied(unit)

	element:SetMinMaxValues(0, max)
	element:SetValue(min)
	element:UpdateColor(unit, min, max, powerType, powerID, disconnected, dead, tapped)
	element:UpdateValue(unit, min, max, powerType, powerID, disconnected, dead, tapped)
			
	if element.PostUpdate then
		return element:PostUpdate(unit, min, max, powerType, powerID)
	end	
end 

local Proxy = function(self, ...)
	return (self.ExtraPower.Override or Update)(self, ...)
end 

local ForceUpdate = function(element)
	return Proxy(element._owner, "Forced", element._owner.unit)
end

local Enable = function(self)
	local element = self.ExtraPower
	if element then
		element._owner = self
		element.ForceUpdate = ForceUpdate

		local unit = self.unit
		if element.frequent and ((unit == "player") or (unit == "pet")) then 
			self:RegisterEvent("UNIT_POWER_FREQUENT", Proxy)
		else 
			if ENGINE_801 then 
				self:RegisterEvent("UNIT_POWER_UPDATE", Proxy)
			else 
				self:RegisterEvent("UNIT_POWER", Proxy)
			end 
		end 

		self:RegisterEvent("UNIT_POWER_BAR_SHOW", Proxy)
		self:RegisterEvent("UNIT_POWER_BAR_HIDE", Proxy)
		self:RegisterEvent("UNIT_DISPLAYPOWER", Proxy)
		self:RegisterEvent("UNIT_CONNECTION", Proxy)
		self:RegisterEvent("UNIT_MAXPOWER", Proxy)
		self:RegisterEvent("UNIT_FACTION", Proxy)

		if (not element.UpdateColor) then 
			element.UpdateColor = UpdateColor
		end 

		if (not element.UpdateValue) then 
			element.UpdateValue = UpdateValue
		end 

		return true
	end
end 

local Disable = function(self)
	local element = self.ExtraPower
	if element then
		element:Hide()

		self:UnregisterEvent("UNIT_POWER_FREQUENT", Proxy)
		self:UnregisterEvent("UNIT_POWER", Proxy)
		self:UnregisterEvent("UNIT_POWER_BAR_SHOW", Proxy)
		self:UnregisterEvent("UNIT_POWER_BAR_HIDE", Proxy)
		self:UnregisterEvent("UNIT_POWER_UPDATE", Proxy)
		self:UnregisterEvent("UNIT_DISPLAYPOWER", Proxy)
		self:UnregisterEvent("UNIT_CONNECTION", Proxy)
		self:UnregisterEvent("UNIT_MAXPOWER", Proxy)
		self:UnregisterEvent("UNIT_FACTION", Proxy)

	end
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (CogWheel("LibUnitFrame", true)), (CogWheel("LibNamePlate", true)) }) do 
	Lib:RegisterElement("ExtraPower", Enable, Disable, Proxy, 3)
end 
