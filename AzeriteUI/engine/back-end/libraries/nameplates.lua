local LibNamePlate = CogWheel:Set("LibNamePlate", 20)
if (not LibNamePlate) then	
	return
end

local LibClientBuild = CogWheel("LibClientBuild")
assert(LibClientBuild, "LibNamePlate requires LibClientBuild to be loaded.")

local LibEvent = CogWheel("LibEvent")
assert(LibEvent, "LibNamePlate requires LibEvent to be loaded.")

local LibFrame = CogWheel("LibFrame")
assert(LibFrame, "LibNamePlate requires LibFrame to be loaded.")

local LibStatusBar = CogWheel("LibStatusBar")
assert(LibStatusBar, "LibNamePlate requires LibStatusBar to be loaded.")

-- Embed event functionality into this
LibEvent:Embed(LibNamePlate)
LibFrame:Embed(LibNamePlate)
LibStatusBar:Embed(LibNamePlate)

-- Lua API
local _G = _G
local ipairs = ipairs
local math_ceil = math.ceil
local math_floor = math.floor
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_find = string.find
local table_insert = table.insert
local table_remove = table.remove
local table_sort = table.sort
local table_wipe = table.wipe
local tonumber = tonumber
local tostring = tostring
local unpack = unpack

-- WoW API
local GetNamePlateForUnit = _G.C_NamePlate.GetNamePlateForUnit
local CreateFrame = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local IsLoggedIn = _G.IsLoggedIn
local UnitClass = _G.UnitClass
local UnitClassification = _G.UnitClassification
local UnitExists = _G.UnitExists
local UnitHealth = _G.UnitHealth
local UnitHealthMax = _G.UnitHealthMax
local UnitIsFriend = _G.UnitIsFriend
local UnitIsPlayer = _G.UnitIsPlayer
local UnitIsTapDenied = _G.UnitIsTapDenied
local UnitIsTrivial = _G.UnitIsTrivial
local UnitIsUnit = _G.UnitIsUnit
local UnitLevel = _G.UnitLevel
local UnitName = _G.UnitName
local UnitReaction = _G.UnitReaction
local UnitThreatSituation = _G.UnitThreatSituation

-- WoW Frames & Objects
local WorldFrame = _G.WorldFrame

-- Plate Registries
LibNamePlate.allPlates = LibNamePlate.allPlates or {}
LibNamePlate.visiblePlates = LibNamePlate.visiblePlates or {}
LibNamePlate.castData = LibNamePlate.castData or {}
LibNamePlate.alphaLevels = LibNamePlate.alphaLevels or {}

LibNamePlate.elements = LibNamePlate.elements or {} -- global element registry
LibNamePlate.callbacks = LibNamePlate.callbacks or {} -- global frame and element callback registry
LibNamePlate.unitEvents = LibNamePlate.unitEvents or {} -- global frame unitevent registry
LibNamePlate.frequentUpdates = LibNamePlate.frequentUpdates or {} -- global element frequent update registry
LibNamePlate.frequentUpdateFrames = LibNamePlate.frequentUpdateFrames or {} -- global frame frequent update registry
LibNamePlate.frameElements = LibNamePlate.frameElements or {} -- per unitframe element registry
LibNamePlate.frameElementsEnabled = LibNamePlate.frameElementsEnabled or {} -- per unitframe element enabled registry
LibNamePlate.scriptHandlers = LibNamePlate.scriptHandlers or {} -- tracked library script handlers
LibNamePlate.scriptFrame = LibNamePlate.scriptFrame -- library script frame, will be created on demand later on

-- Modules that embed this
LibNamePlate.embeds = LibNamePlate.embeds or {}

-- We parent our update frame to the WorldFrame, 
-- as we need it to run even if the user has hidden the UI.
LibNamePlate.frame = LibNamePlate.frame or CreateFrame("Frame", nil, WorldFrame)

-- When parented to the WorldFrame, setting the strata to TOOLTIP 
-- will cause its updates to run close to last in the update cycle. 
LibNamePlate.frame:SetFrameStrata("TOOLTIP") 

-- internal switch to track enabled state
-- Looks weird. But I want it referenced up here.
LibNamePlate.isEnabled = LibNamePlate.isEnabled or false 

-- This will be updated later on by the library,
-- we just need a value of some sort here as a fallback.
LibNamePlate.SCALE = LibNamePlate.SCALE or 768/1080

-- We need this one
local UICenter = LibFrame:GetFrame()

-- Speed shortcuts
local allPlates = LibNamePlate.allPlates
local visiblePlates = LibNamePlate.visiblePlates
local alphaLevels = LibNamePlate.alphaLevels

local elements = LibNamePlate.elements
local callbacks = LibNamePlate.callbacks
local unitEvents = LibNamePlate.unitEvents
local frequentUpdates = LibNamePlate.frequentUpdates
local frequentUpdateFrames = LibNamePlate.frequentUpdateFrames
local frameElements = LibNamePlate.frameElements
local frameElementsEnabled = LibNamePlate.frameElementsEnabled
local scriptHandlers = LibNamePlate.scriptHandlers
local scriptFrame = LibNamePlate.scriptFrame

-- This will be true if forced updates are needed on all plates
-- All plates will be updated in the next frame cycle 
local FORCEUPDATE = false

-- Frame level constants and counters
local FRAMELEVEL_TARGET = 126
local FRAMELEVEL_IMPORTANT = 124 -- rares, bosses, etc
local FRAMELEVEL_CURRENT, FRAMELEVEL_MIN, FRAMELEVEL_MAX, FRAMELEVEL_STEP = 21, 21, 125, 2
local FRAMELEVEL_TRIVAL_CURRENT, FRAMELEVEL_TRIVIAL_MIN, FRAMELEVEL_TRIVIAL_MAX, FRAMELEVEL_TRIVIAL_STEP = 1, 1, 20, 2

-- Opacity Settings
alphaLevels[0] = 0 						-- Not visible. Not configurable by modules. 
alphaLevels[1] = alphaLevels[1] or 1 	-- For the current target, if any
alphaLevels[2] = alphaLevels[2] or .7 	-- For players when not having a target, also for World Bosses when not targeted
alphaLevels[3] = alphaLevels[3] or .35 	-- For non-targeted players when having a target
alphaLevels[4] = alphaLevels[4] or .25 	-- For non-targeted trivial mobs
alphaLevels[5] = alphaLevels[5] or .15 	-- For non-targeted NPCs 

-- Update and fading frequencies
local THROTTLE = 1/30 -- global update limit, no elements can go above this
local FADE_IN = 3/4 -- time in seconds to fade in
local FADE_OUT = 1/20 -- time in seconds to fade out

-- Color Table Utility
local hex = function(r, g, b)
	return ("|cff%02x%02x%02x"):format(math_floor(r*255), math_floor(g*255), math_floor(b*255))
end
local prepare = function(...)
	local tbl
	if (select("#", ...) == 1) then
		local old = ...
		if (old.r) then 
			tbl = {}
			tbl[1] = old.r or 1
			tbl[2] = old.g or 1
			tbl[3] = old.b or 1
		else
			tbl = { unpack(old) }
		end
	else
		tbl = { ... }
	end
	if (#tbl == 3) then
		tbl.colorCode = hex(unpack(tbl))
	end
	return tbl
end

-- Color Table
local Colors = {

	normal = prepare(229/255, 178/255, 38/255),
	highlight = prepare(250/255, 250/255, 250/255),
	title = prepare(255/255, 234/255, 137/255),

	dead = prepare(73/255, 25/255, 9/255),
	disconnected = prepare(120/255, 120/255, 120/255),
	tapped = prepare(161/255, 141/255, 120/255),

	class = {
		DEATHKNIGHT 	= prepare( 176/255,  31/255,  79/255 ), -- slightly more blue, less red, to stand out from angry mobs better
		DEMONHUNTER 	= prepare( 163/255,  48/255, 201/255 ),
		DRUID 			= prepare( 255/255, 125/255,  10/255 ),
		HUNTER 			= prepare( 191/255, 232/255, 115/255 ), -- slightly more green and yellow, to stand more out from friendly players/npcs
		MAGE 			= prepare( 105/255, 204/255, 240/255 ),
		MONK 			= prepare(   0/255, 255/255, 150/255 ),
		PALADIN 		= prepare( 255/255, 130/255, 226/255 ), -- less pink, more purple
		--PALADIN 		= prepare( 245/255, 140/255, 186/255 ), -- original 
		PRIEST 			= prepare( 220/255, 235/255, 250/255 ), -- tilted slightly towards blue, and somewhat toned down. chilly.
		ROGUE 			= prepare( 255/255, 225/255,  95/255 ), -- slightly more orange than Blizz, to avoid the green effect when shaded with black
		SHAMAN 			= prepare(  32/255, 122/255, 222/255 ), -- brighter, to move it a bit away from the mana color
		WARLOCK 		= prepare( 148/255, 130/255, 201/255 ),
		WARRIOR 		= prepare( 199/255, 156/255, 110/255 ),
		UNKNOWN 		= prepare( 195/255, 202/255, 217/255 )
	},
	debuff = {
		none 			= prepare( 204/255,   0/255,   0/255 ),
		Magic 			= prepare(  51/255, 153/255, 255/255 ),
		Curse 			= prepare( 204/255,   0/255, 255/255 ),
		Disease 		= prepare( 153/255, 102/255,   0/255 ),
		Poison 			= prepare(   0/255, 153/255,   0/255 ),
		[""] 			= prepare(   0/255,   0/255,   0/255 )
	},
	quest = {
		red = prepare(204/255, 26/255, 26/255),
		orange = prepare(255/255, 128/255, 64/255),
		yellow = prepare(229/255, 178/255, 38/255),
		green = prepare(89/255, 201/255, 89/255),
		gray = prepare(120/255, 120/255, 120/255)
	},
	reaction = {
		[1] 			= prepare( 205/255,  46/255,  36/255 ), -- hated
		[2] 			= prepare( 205/255,  46/255,  36/255 ), -- hostile
		[3] 			= prepare( 192/255,  68/255,   0/255 ), -- unfriendly
		[4] 			= prepare( 249/255, 158/255,  35/255 ), -- neutral 
		[5] 			= prepare(  64/255, 131/255,  38/255 ), -- friendly
		[6] 			= prepare(  64/255, 131/255,  69/255 ), -- honored
		[7] 			= prepare(  64/255, 131/255, 104/255 ), -- revered
		[8] 			= prepare(  64/255, 131/255, 131/255 ), -- exalted
		civilian 		= prepare(  64/255, 131/255,  38/255 )  -- used for friendly player nameplates
	},
	threat = {
		[0] 			= prepare( 175/255, 165/255, 155/255 ), -- gray, low on threat
		[1] 			= prepare( 255/255, 128/255,  64/255 ), -- light yellow, you are overnuking 
		[2] 			= prepare( 255/255,  64/255,  12/255 ), -- orange, tanks that are losing threat
		[3] 			= prepare( 255/255,   0/255,   0/255 )  -- red, you're securely tanking, or totally fucked :) 
	}
}

-- Utility Functions
----------------------------------------------------------
-- Syntax check 
local check = function(value, num, ...)
	assert(type(num) == "number", ("Bad argument #%d to '%s': %s expected, got %s"):format(2, "Check", "number", type(num)))
	for i = 1,select("#", ...) do
		if type(value) == select(i, ...) then 
			return 
		end
	end
	local types = string_join(", ", ...)
	local name = string_match(debugstack(2, 2, 0), ": in function [`<](.-)['>]")
	error(("Bad argument #%d to '%s': %s expected, got %s"):format(num, name, types, type(value)), 3)
end

-- NamePlate Template
----------------------------------------------------------
local NamePlate = LibNamePlate:CreateFrame("Frame")
local NamePlate_MT = { __index = NamePlate }

-- Methods we don't wish to expose to the modules
--------------------------------------------------------------------------
local IsEventRegistered = NamePlate_MT.__index.IsEventRegistered
local RegisterEvent = NamePlate_MT.__index.RegisterEvent
local RegisterUnitEvent = NamePlate_MT.__index.RegisterUnitEvent
local UnregisterEvent = NamePlate_MT.__index.UnregisterEvent
local UnregisterAllEvents = NamePlate_MT.__index.UnregisterAllEvents

NamePlate.UpdateAlpha = function(self)
	local unit = self.unit
	if (not UnitExists(unit)) then
		return 
	end
	local alphaLevel = 0
	if visiblePlates[self] then
		if (self.OverrideAlpha) then 
			return self:OverrideAlpha(unit)
		end 
		if UnitIsUnit(unit, "player") then 
			alphaLevel = 1 -- personal resource display
		elseif UnitExists("target") then
			if UnitIsUnit(unit, "target") then
				alphaLevel = 1
			elseif UnitIsTrivial(unit) then 
				alphaLevel = 5
			elseif UnitIsPlayer(unit) then
				alphaLevel = 3
			elseif UnitIsFriend("player", unit) then
				alphaLevel = 5
			else
				local level = UnitLevel(unit)
				local classificiation = UnitClassification(unit)
				if (classificiation == "worldboss") or (classificiation == "rare") or (classificiation == "rareelite") or (level and level < 1) then
					alphaLevel = 2
				else
					alphaLevel = 3
				end	
			end
		elseif UnitIsTrivial(unit) then 
			alphaLevel = 4
		elseif UnitIsPlayer(unit) then
			alphaLevel = 2
		elseif UnitIsFriend("player", unit) then
			alphaLevel = 5
		else
			local level = UnitLevel(unit)
			local classificiation = UnitClassification(unit)
			if (classificiation == "worldboss") or (classificiation == "rare") or (classificiation == "rareelite") or (level and level < 1) then
				alphaLevel = 1
			else
				alphaLevel = 2
			end	
		end
	end
	self.targetAlpha = alphaLevels[alphaLevel]
	if (self.PostUpdateAlpha) then 
		self:PostUpdateAlpha(unit, self.targetAlpha, alphaLevel)
	end 
end

NamePlate.UpdateFrameLevel = function(self)
	local unit = self.unit
	if (not UnitExists(unit)) then
		return
	end
	if visiblePlates[self] then
		if (self.OverrideFrameLevel) then 
			return self:OverrideFrameLevel(unit)
		end 
		local level = UnitLevel(unit)
		local classificiation = UnitClassification(unit)
		local isTarget = UnitIsUnit(unit, "target")
		local isImportant = (classificiation == "worldboss") or (classificiation == "rare") or (classificiation == "rareelite") or (level and level < 1)
		if isTarget then
			-- We're placing targets at an elevated frame level, 
			-- as we want that frame visible above everything else. 
			if self:GetFrameLevel() ~= FRAMELEVEL_TARGET then
				self:SetFrameLevel(FRAMELEVEL_TARGET)
			end
		elseif isImportant then 
			-- We're also elevating rares and bosses to almost the same level as our target, 
			-- as we want these frames to stand out above all the others to make Legion rares easier to see.
			-- Note that this doesn't actually make it easier to click, as we can't raise the secure uniframe itself, 
			-- so it only affects the visible part created by us. 
			if (self:GetFrameLevel() ~= FRAMELEVEL_IMPORTANT) then
				self:SetFrameLevel(FRAMELEVEL_IMPORTANT)
			end
		else
			-- If the current nameplate isn't a rare, boss or our target, 
			-- we return it to its original framelevel, if the framelevel has been changed.
			if (self:GetFrameLevel() ~= self.frameLevel) then
				self:SetFrameLevel(self.frameLevel)
			end
		end
		if (self.PostUpdateFrameLevel) then 
			self:PostUpdateFrameLevel(unit, isTarget, isImportant)
		end 
	end
end

NamePlate.OnShow = function(self)
	local unit = self.unit
	if not UnitExists(unit) then
		return
	end

	-- setup player classbars
	-- setup raid targets

	if self.Health then 
		self.Health:Show()
	end

	if self.Auras then 
		self.Auras:Hide()
	end 

	if self.Cast then 
		self.Cast:Hide()
	end 
	--[[
	]]

	self:SetAlpha(0) -- set the actual alpha to 0
	self.currentAlpha = 0 -- update stored alpha value
	self:Show() -- make the fully transparent frame visible

	-- this will trigger the fadein 
	visiblePlates[self] = self.baseFrame 

	-- must be called after the plate has been added to visiblePlates
	self:UpdateFrameLevel() 

	for element in pairs(elements) do
		self:EnableElement(element, unit)
	end
	self:UpdateAllElements()

	if (self.PostUpdate) then 
		self:PostUpdate()
	end 
end

NamePlate.OnHide = function(self)
	visiblePlates[self] = false -- this will trigger the fadeout and hiding

	for element in pairs(elements) do
		self:DisableElement(element, unit)
	end
end

NamePlate.HandleBaseFrame = function(self, baseFrame)
	local unitframe = baseFrame.UnitFrame
	if unitframe then
		unitframe:Hide()
		unitframe:HookScript("OnShow", function(unitframe) unitframe:Hide() end) 
	end
	self.baseFrame = baseFrame
end

NamePlate.HookScripts = function(self, baseFrame)
	baseFrame:HookScript("OnHide", function(baseFrame) self:OnHide() end)
end

-- Create the sizer frame that handles nameplate positioning
-- *Blizzard changed nameplate format and also anchoring points in Legion,
--  so naturally we're using a different function for this too. Speed!
NamePlate.CreateSizer = function(self, baseFrame)
	local sizer = self:CreateFrame()
	sizer.plate = self
	sizer:SetPoint("BOTTOMLEFT", WorldFrame, "BOTTOMLEFT", 0, 0)
	sizer:SetPoint("TOPRIGHT", baseFrame, "CENTER", 0, 0)
	sizer:SetScript("OnSizeChanged", function(self, width, height)
		local plate = self.plate
		plate:Hide()
		plate:SetPoint("TOP", WorldFrame, "BOTTOMLEFT", width, height)
		plate:Show()
	end)
end

local OnNamePlateEvent = function(frame, event, ...)
	if (frame:IsVisible() and callbacks[frame] and callbacks[frame][event]) then 
		local events = callbacks[frame][event]
		local isUnitEvent = unitEvents[event]
		for i = 1, #events do
			if isUnitEvent then 
				events[i](frame, event, ...)
			else 
				events[i](frame, event, frame.unit, ...)
			end 
		end
	end 
end

NamePlate.RegisterEvent = function(self, event, func, unitless)
	if (frequentUpdateFrames[self] and event ~= "UNIT_PORTRAIT_UPDATE" and event ~= "UNIT_MODEL_CHANGED") then 
		return 
	end
	if (not callbacks[self]) then
		callbacks[self] = {}
	end
	if (not callbacks[self][event]) then
		callbacks[self][event] = {}
	end
	
	local events = callbacks[self][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not IsEventRegistered(self, event)) then
		if unitless then 
			RegisterEvent(self, event)
		else 
			unitEvents[event] = true
			RegisterUnitEvent(self, event)
		end 
	end
end

NamePlate.UnregisterEvent = function(self, event, func)
	-- silently fail if the event isn't even registered
	if not callbacks[self] or not callbacks[self][event] then
		return
	end

	local events = callbacks[self][event]

	if #events > 0 then
		-- find the function's id 
		for i = #events, 1, -1 do
			if events[i] == func then
				table_remove(events, i)
				--events[i] = nil -- remove the function from the event's registry
				if #events == 0 then
					UnregisterEvent(self, event) 
				end
			end
		end
	end
end

NamePlate.UnregisterAllEvents = function(self)
	if not callbacks[self] then 
		return
	end
	for event, funcs in pairs(callbacks[self]) do
		for i = #funcs, 1, -1 do
			table_remove(funcs, i)
			--funcs[i] = nil
		end
	end
	UnregisterAllEvents(self)
end

NamePlate.UpdateAllElements = function(self, event, ...)
	local unit = self.unit
	if (not UnitExists(unit)) then 
		return 
	end
	if (self.PreUpdate) then
		self:PreUpdate(event, unit, ...)
	end
	if (frameElements[self]) then
		for element in pairs(frameElementsEnabled[self]) do
			-- Will run the registered Update function for the element, 
			-- which isually is the "Proxy" method in my elements. 
			-- We cannot direcly access the ForceUpdate method, 
			-- as that is meant for in-module updates to that unique
			-- instance of the element, and doesn't exist on the template element itself. 
			elements[element].Update(self, "Forced", self.unit)
		end
	end
	if (self.PostUpdate) then
		self:PostUpdate(event, unit, ...)
	end
end

NamePlate.DisableAllElements = function(self, event, ...)
	if (not UnitExists(unit)) then 
		return 
	end
	if (self.PreUpdate) then
		self:PreUpdate(event, unit, ...)
	end
	if (frameElements[self]) then
		for element in pairs(frameElementsEnabled[self]) do
			-- Will run the registered Update function for the element, 
			-- which isually is the "Proxy" method in my elements. 
			-- We cannot direcly access the ForceUpdate method, 
			-- as that is meant for in-module updates to that unique
			-- instance of the element, and doesn't exist on the template element itself. 
			elements[element].Update(self, "Forced", self.unit)
		end
	end
	if (self.PostUpdate) then
		self:PostUpdate(event, unit, ...)
	end
end

NamePlate.EnableElement = function(self, element)
	if (not frameElements[self]) then
		frameElements[self] = {}
		frameElementsEnabled[self] = {}
	end

	-- don't double enable
	if frameElementsEnabled[self][element] then 
		return 
	end 

	-- upvalues ftw
	local frameElements = frameElements[self]
	local frameElementsEnabled = frameElementsEnabled[self]
	
	-- avoid duplicates
	local found
	for i = 1, #frameElements do
		if (frameElements[i] == element) then
			found = true
			break
		end
	end
	if (not found) then
		-- insert the element into the list
		table_insert(frameElements, element)
	end

	-- attempt to enable the element
	if elements[element].Enable(self, self.unit) then
		-- success!
		frameElementsEnabled[element] = true
	end
end

NamePlate.DisableElement = function(self, element)
	-- silently fail if the element hasn't been enabled for the frame
	if ((not frameElementsEnabled[self]) or (not frameElementsEnabled[self][element])) then
		return
	end
	
	elements[element].Disable(self, self.unit)

	for i = #frameElements[self], 1, -1 do
		if (frameElements[self][i] == element) then
			table_remove(frameElements[self], i)
			--frameElements[self][i] = nil
		end
	end
	
	frameElementsEnabled[self][element] = nil
	
	if (frequentUpdates[self] and frequentUpdates[self][element]) then
		-- remove the element's frequent update entry
		frequentUpdates[self][element].elapsed = nil
		frequentUpdates[self][element].hz = nil
		frequentUpdates[self][element] = nil
		
		-- Remove the frame object's frequent update entry
		-- if no elements require it anymore.
		local count = 0
		for i,v in pairs(frequentUpdates[self]) do
			count = count + 1
		end
		if (count == 0) then
			frequentUpdates[self] = nil
		end
		
		-- Disable the entire script handler if no elements
		-- on any frames require frequent updates. 
		count = 0
		for i,v in pairs(frequentUpdates) do
			count = count + 1
		end
		if (count == 0) then
			if LibNamePlate:GetScript("OnUpdate") then
				LibNamePlate:SetScript("OnUpdate", nil)
			end
		end
	end
end

NamePlate.EnableFrequentUpdates = function(self, element, frequency)
	if (not frequentUpdates[self]) then
		frequentUpdates[self] = {}
	end
	frequentUpdates[self][element] = { elapsed = 0, hz = tonumber(frequency) or .5 }
	--if (not LibUnitFrame:GetScript("OnUpdate")) then
	--	LibUnitFrame:SetScript("OnUpdate", OnUpdate)
	--end
end

-- This is where a name plate is first created, 
-- but it hasn't been assigned a unit (Legion) or shown yet.
LibNamePlate.CreateNamePlate = function(self, baseFrame, name)
	local plate = setmetatable(self:CreateFrame("Frame", "CG_" .. (name or baseFrame:GetName()), WorldFrame), NamePlate_MT)
	plate.frameLevel = FRAMELEVEL_CURRENT -- storing the framelevel
	plate.targetAlpha = 0
	plate.currentAlpha = 0
	plate.colors = Colors
	plate:Hide()
	plate:SetFrameStrata("BACKGROUND")
	plate:SetAlpha(plate.currentAlpha)
	plate:SetFrameLevel(plate.frameLevel)
	plate:SetScale(LibNamePlate.SCALE)
	plate:HandleBaseFrame(baseFrame) -- hide and reference the baseFrame and original blizzard objects
	plate:CreateSizer(baseFrame) -- create the sizer that positions the nameplate
	plate:HookScripts(baseFrame) -- let baseframe hiding trigger plate fade-out

	-- Since constantly updating frame levels can cause quite the performance drop, 
	-- we're just giving each frame a set frame level when they spawn. 
	-- We can still get frames overlapping, but in most cases we avoid it now.
	-- Targets, bosses and rares have an elevated frame level, 
	-- but when a nameplate returns to "normal" status, its previous stored level is used instead.
	FRAMELEVEL_CURRENT = FRAMELEVEL_CURRENT + FRAMELEVEL_STEP
	if (FRAMELEVEL_CURRENT > FRAMELEVEL_MAX) then
		FRAMELEVEL_CURRENT = FRAMELEVEL_MIN
	end

	allPlates[baseFrame] = plate

	plate:SetScript("OnEvent", OnNamePlateEvent)

	self:ForAllEmbeds("PostCreateNamePlate", plate, baseFrame)

	return plate
end

-- register a widget/element
LibNamePlate.RegisterElement = function(self, elementName, enableFunc, disableFunc, updateFunc, version)
	check(elementName, 1, "string")
	check(enableFunc, 2, "function")
	check(disableFunc, 3, "function")
	check(updateFunc, 4, "function")
	check(version, 5, "number", "nil")

	-- Does an old version of the element exist?
	local old = elements[elementName]
	local needUpdate
	if old then
		if old.version then 
			if version then 
				if version <= old.version then 
					return 
				end 
				-- A more recent version is being registered
				needUpdate = true 
			else 
				return 
			end 
		else 
			if version then 
				-- A more recent version is being registered
				needUpdate = true 
			else 
				-- Two unversioned. just follow first come first served, 
				-- to allow the standalone addon to trumph. 
				return 
			end 
		end  
		return 
	end 

	-- Create our new element 
	local new = {
		Enable = enableFunc,
		Disable = disableFunc,
		Update = updateFunc,
		version = version
	}

	-- Change the pointer to the new element
	-- (doesn't change what table 'old' still points to)
	elements[elementName] = new 

	-- Postupdate existing frames embedding this if it exists
	if needUpdate then 
		-- Iterate all frames for it
		for unitFrame, element in pairs(frameElementsEnabled) do 
			if (element == elementName) then 
				-- Run the old disable method, 
				-- to get rid of old events and onupdate handlers.
				if old.Disable then 
					old.Disable(unitFrame)
				end 

				-- Run the new enable method
				if new.Enable then 
					new.Enable(unitFrame, unitFrame.unit, true)
				end 
			end 
		end 
	end 
end

-- NamePlate Handling
----------------------------------------------------------
local hasSetBlizzardSettings, hasQueuedSettingsUpdate

-- Leave any settings changes to the frontend modules
LibNamePlate.UpdateNamePlateOptions = function(self)
	if InCombatLockdown() then 
		hasQueuedSettingsUpdate = true 
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		return 
	end 
	hasQueuedSettingsUpdate = nil
	self:ForAllEmbeds("PostUpdateNamePlateOptions")
end

LibNamePlate.UpdateAllScales = function(self)
	local oldScale = LibNamePlate.SCALE
	local scale = UICenter:GetEffectiveScale()
	if scale then
		SCALE = scale
	end
	if (oldScale ~= LibNamePlate.SCALE) then
		for baseFrame, plate in pairs(allPlates) do
			if plate then
				plate:SetScale(LibNamePlate.SCALE)
			end
		end
	end
end

-- NamePlate Event Handling
----------------------------------------------------------
LibNamePlate.OnEvent = function(self, event, ...)
	if (event == "NAME_PLATE_CREATED") then
		self:CreateNamePlate((...)) -- local namePlateFrameBase = ...

	elseif (event == "NAME_PLATE_UNIT_ADDED") then
		local unit = ...
		local baseFrame = GetNamePlateForUnit(unit)
		local plate = baseFrame and allPlates[baseFrame] 
		if plate then
			plate.unit = unit
			plate:OnShow(unit)

		end

	elseif (event == "NAME_PLATE_UNIT_REMOVED") then
		local unit = ...
		local baseFrame = GetNamePlateForUnit(unit)
		local plate = baseFrame and allPlates[baseFrame] 
		if plate then
			plate.unit = nil
			plate:OnHide()
		end

	elseif (event == "PLAYER_TARGET_CHANGED") then
		for baseFrame, plate in pairs(allPlates) do
			plate:UpdateAlpha()
			plate:UpdateFrameLevel()
		end	
		
	elseif (event == "VARIABLES_LOADED") then
		self:UpdateNamePlateOptions()
	
	elseif (event == "PLAYER_ENTERING_WORLD") then
		self:ForAllEmbeds("PreUpdateNamePlateOptions")

		if (not hasSetBlizzardSettings) then
			if _G.C_NamePlate then
				self:UpdateNamePlateOptions()
			else
				self:RegisterEvent("ADDON_LOADED", "OnEvent")
			end
			hasSetBlizzardSettings = true
		end
		self:UpdateAllScales()
		self.frame:SetScript("OnUpdate", function(_, ...) self:OnUpdate(...) end)

	elseif (event == "PLAYER_REGEN_ENABLED") then 
		if hasQueuedSettingsUpdate then 
			self:UpdateNamePlateOptions()
		end 

	elseif (event == "DISPLAY_SIZE_CHANGED") then
		self:UpdateNamePlateOptions()
		self:UpdateAllScales()

	elseif (event == "UI_SCALE_CHANGED") then
		self:UpdateAllScales()

	elseif (event == "ADDON_LOADED") then
		local addon = ...
		if (addon == "Blizzard_NamePlates") then
			hasSetBlizzardSettings = true
			self:UpdateNamePlateOptions()
			self:UnregisterEvent("ADDON_LOADED")
		end
	end
end

LibNamePlate.SetScript = function(self, scriptHandler, script)
	scriptHandlers[scriptHandler] = script
	if (scriptHandler == "OnUpdate") then
		if (not scriptFrame) then
			scriptFrame = CreateFrame("Frame", nil, LibFrame:GetFrame())
		end
		if script then 
			scriptFrame:SetScript("OnUpdate", function(self, ...) 
				script(LibNamePlate, ...) 
			end)
		else
			scriptFrame:SetScript("OnUpdate", nil)
		end
	end
end

LibNamePlate.GetScript = function(self, scriptHandler)
	return scriptHandlers[scriptHandler]
end

LibNamePlate.OnUpdate = function(self, elapsed)

	-- Throttle the updates, to increase the performance. 
	self.elapsed = (self.elapsed or 0) + elapsed
	if (self.elapsed < THROTTLE) then
		return
	end

	-- We need the full value since the last set of updates
	local elapsed = self.elapsed

	for frame, frequentElements in pairs(frequentUpdates) do
		for element, frequency in pairs(frequentElements) do
			if frequency.hz then
				frequency.elapsed = frequency.elapsed + elapsed
				if (frequency.elapsed >= frequency.hz) then
					elements[element].Update(frame, "FrequentUpdate", frame.unit, elapsed) 
					frequency.elapsed = 0
				end
			else
				elements[element].Update(frame, "FrequentUpdate", frame.unit)
			end
		end
	end

	for plate, baseFrame in pairs(visiblePlates) do
		if baseFrame then
			plate:UpdateAlpha()
		else
			plate.targetAlpha = 0
		end
		if (plate.currentAlpha ~= plate.targetAlpha) then

			local difference
			if (plate.targetAlpha > plate.currentAlpha) then
				difference = plate.targetAlpha - plate.currentAlpha
			else
				difference = plate.currentAlpha - plate.targetAlpha
			end

			local step_in = elapsed/(FADE_IN * difference)
			local step_out = elapsed/(FADE_OUT * difference)

			if (plate.targetAlpha > plate.currentAlpha) then
				if (plate.targetAlpha > plate.currentAlpha + step_in) then
					plate.currentAlpha = plate.currentAlpha + step_in -- fade in
				else
					plate.currentAlpha = plate.targetAlpha -- fading done
				end
			elseif (plate.targetAlpha < plate.currentAlpha) then
				if (plate.targetAlpha < plate.currentAlpha - step_out) then
					plate.currentAlpha = plate.currentAlpha - step_out -- fade out
				else
					plate.currentAlpha = plate.targetAlpha -- fading done
				end
			else
				plate.currentAlpha = plate.targetAlpha -- fading done
			end
			plate:SetAlpha(plate.currentAlpha)
		end

		if ((plate.currentAlpha == 0) and (plate.targetAlpha == 0)) then
			visiblePlates[plate] = nil
			plate:Hide()
			if plate.Health then 
				plate.Health:SetValue(0, true)
			end 
			if plate.Cast then 
				plate.Cast:SetValue(0, true)
			end 
		end
	end	

	self.elapsed = 0
end 

LibNamePlate.Enable = function(self)
	if self.enabled then 
		return
	end 

	-- Only call this once 
	self:UnregisterAllEvents()

	-- Detection, showing and hidding
	self:RegisterEvent("NAME_PLATE_CREATED", "OnEvent")
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED", "OnEvent")
	self:RegisterEvent("NAME_PLATE_UNIT_REMOVED", "OnEvent")

	-- Updates
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnEvent")

	-- Scale Changes
	self:RegisterEvent("DISPLAY_SIZE_CHANGED", "OnEvent")
	self:RegisterEvent("UI_SCALE_CHANGED", "OnEvent")

	self.enabled = true
end 

LibNamePlate.StartNamePlateEngine = function(self)
	if LibNamePlate.enabled then 
		return
	end 
	if IsLoggedIn() then 
		-- Should do some initial parsing of already created nameplates here (?)
		-- *Only really needed if the modules enable it after PLAYER_ENTERING_WORLD, which they shouldn't anyway. 
		return LibNamePlate:Enable()
	else 
		LibNamePlate:UnregisterAllEvents()
		LibNamePlate:RegisterEvent("PLAYER_ENTERING_WORLD", "Enable")
	end 
end 

-- Kill off remnant events from prior library versions, just in case
LibNamePlate:UnregisterAllEvents()

-- Module embedding
local embedMethods = {
	StartNamePlateEngine = true,
	UpdateNamePlateOptions = true
}

LibNamePlate.GetEmbeds = function(self)
	return pairs(self.embeds)
end 

-- Iterate all embedded modules for the given method name or function
-- Silently fail if nothing exists. We don't want an error here. 
LibNamePlate.ForAllEmbeds = function(self, method, ...)
	for target in pairs(self.embeds) do 
		if (target) then 
			if (type(method) == "string") then
				if target[method] then
					target[method](target, ...)
				end
			else
				func(target, ...)
			end
		end 
	end 
end 

LibNamePlate.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibNamePlate.embeds) do
	LibNamePlate:Embed(target)
end