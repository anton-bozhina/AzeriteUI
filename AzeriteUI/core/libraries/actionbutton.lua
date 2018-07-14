local LibActionButton = CogWheel:Set("LibActionButton", 5)
if (not LibActionButton) then	
	return
end

local LibClientBuild = CogWheel("LibClientBuild")
assert(LibClientBuild, "LibActionButton requires LibClientBuild to be loaded.")

local LibMessage = CogWheel("LibMessage")
assert(LibMessage, "LibActionButton requires LibMessage to be loaded.")

local LibEvent = CogWheel("LibEvent")
assert(LibEvent, "LibActionButton requires LibEvent to be loaded.")

local LibFrame = CogWheel("LibFrame")
assert(LibFrame, "LibActionButton requires LibFrame to be loaded.")

local LibSound = CogWheel("LibSound")
assert(LibSound, "LibActionButton requires LibSound to be loaded.")

local LibTooltip = CogWheel("LibTooltip")
assert(LibTooltip, "LibActionButton requires LibTooltip to be loaded.")

local LibHook = CogWheel("LibHook")
assert(LibHook, "LibActionButton requires LibHook to be loaded.")

-- Embed library functionality into this
LibClientBuild:Embed(LibActionButton)
LibEvent:Embed(LibActionButton)
LibMessage:Embed(LibActionButton)
LibFrame:Embed(LibActionButton)
LibSound:Embed(LibActionButton)
LibTooltip:Embed(LibActionButton)
LibHook:Embed(LibActionButton)

-- Lua API
local _G = _G
local assert = assert
local debugstack = debugstack
local error = error
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_join = string.join
local string_match = string.match
local table_insert = table.insert
local type = type

-- WoW API
local CreateFrame = _G.CreateFrame


-- Library registries
LibActionButton.embeds = LibActionButton.embeds or {} -- modules embedding this library
LibActionButton.private = LibActionButton.private or {} -- private registry of various frames and elements
LibActionButton.callbacks = LibActionButton.callbacks or {} -- events registered by the elements
LibActionButton.buttons = LibActionButton.buttons or {}
LibActionButton.elements = LibActionButton.elements or {} -- registered module element templates
LibActionButton.elementPool = LibActionButton.elementPool or {} -- pool of element instances
LibActionButton.elementPoolEnabled = LibActionButton.elementPoolEnabled or {} -- per module registry of element having been enabled
LibActionButton.elementProxy = LibActionButton.elementProxy or {} -- event handler for a module's registered elements
LibActionButton.elementObjects = LibActionButton.elementObjects or {} -- pool of unique objects created by the elements
LibActionButton.embedMethods = LibActionButton.embedMethods or {} -- embedded module methods added by elements or modules
LibActionButton.embedMethodVersions = LibActionButton.embedMethodVersions or {} -- version registry for added module methods

-- We parent our update frame to the WorldFrame, 
-- as we need it to run even if the user has hidden the UI.
LibActionButton.frame = LibActionButton.frame or CreateFrame("Frame", nil, WorldFrame)


-- Speed shortcuts
local Private = LibActionButton.private -- renaming our shortcut to indicate that it's meant to be a library only thing
local Callbacks = LibActionButton.callbacks
local Elements = LibActionButton.elements
local ElementPool = LibActionButton.elementPool
local ElementPoolEnabled = LibActionButton.elementPoolEnabled
local ElementProxy = LibActionButton.elementProxy
local ElementObjects = LibActionButton.elementObjects


-- Button Prototypes
------------------------------------------------------
local Button = LibActionButton:CreateFrame("CheckButton")
local Button_MT = { __index = Button }


local PetActionButton = setmetatable({}, { __index = Button })
local PetActionButton_MT = { __index = PetActionButton }

local SpellButton = setmetatable({}, { __index = Button })
local SpellButton_MT = { __index = SpellButton }

local ItemButton = setmetatable({}, { __index = Button })
local ItemButton_MT = { __index = ItemButton }

local MacroButton = setmetatable({}, { __index = Button })
local MacroButton_MT = { __index = MacroButton }

local CustomButton = setmetatable({}, { __index = Button })
local CustomButton_MT = { __index = CustomButton }

local ExtraButton = setmetatable({}, { __index = Button })
local ExtraButton_MT = { __index = ExtraButton }

local StanceButton = setmetatable({}, { __index = Button })
local StanceButton_MT = { __index = StanceButton }

-- button type meta mapping 
-- *types are the same as used by the secure templates
local button_type_meta_map = {
	empty = Button_MT,
	action = ActionButton_MT,
	pet = PetActionButton_MT,
	spell = SpellButton_MT,
	item = ItemButton_MT,
	macro = MacroButton_MT,
	custom = CustomButton_MT,
	extra = ExtraButton_MT,
	stance = StanceButton_MT
}


-- Utility Functions
--------------------------------------------------------------------

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

-- Item Button API mapping
local getItemId = function(input) 
	return input:match("^item:(%d+)") 
end

-- Construct a unique button name
local nameFormatHelper = function()
end


-- Element Template
---------------------------------------------------------
local ElementHandler = LibActionButton:CreateFrame("Frame")
local ElementHandler_MT = { __index = ElementHandler }


-- Methods we don't wish to expose to the modules
--------------------------------------------------------------------------

local IsEventRegistered = ElementHandler_MT.__index.IsEventRegistered
local RegisterEvent = ElementHandler_MT.__index.RegisterEvent
local RegisterUnitEvent = ElementHandler_MT.__index.RegisterUnitEvent
local UnregisterEvent = ElementHandler_MT.__index.UnregisterEvent
local UnregisterAllEvents = ElementHandler_MT.__index.UnregisterAllEvents

local IsMessageRegistered = LibActionButton.IsMessageRegistered
local RegisterMessage = LibActionButton.RegisterMessage
local UnregisterMessage = LibActionButton.UnregisterMessage
local UnregisterAllMessages = LibActionButton.UnregisterAllMessages

local OnElementEvent = function(proxy, event, ...)
	if (Callbacks[proxy] and Callbacks[proxy][event]) then 
		local events = Callbacks[proxy][event]
		for i = 1, #events do
			events[i](proxy, event, ...)
		end
	end 
end

local OnElementUpdate = function(proxy, elapsed)
	for func,data in pairs(proxy.updates) do 
		data.elapsed = data.elapsed + elapsed
		if (data.elapsed > (data.hz or .2)) then
			func(proxy, data.elapsed)
			data.elapsed = 0
		end 
	end 
end 

ElementHandler.RegisterUpdate = function(proxy, func, throttle)
	if (not proxy.updates) then 
		proxy.updates = {}
	end 
	if (proxy.updates[func]) then 
		return 
	end 
	proxy.updates[func] = { hz = throttle, elapsed = throttle } -- set elapsed to throttle to trigger an instant initial update
	if (not proxy:GetScript("OnUpdate")) then 
		proxy:SetScript("OnUpdate", OnElementUpdate)
	end 
end 

ElementHandler.UnregisterUpdate = function(proxy, func)
	if (not proxy.updates) or (not proxy.updates[func]) then 
		return 
	end 
	proxy.updates[func] = nil
	local stillHasUpdates
	for func in pairs(self.updates) do 
		stillHasUpdates = true 
		break
	end 
	if (not stillHasUpdates) then 
		proxy:SetScript("OnUpdate", nil)
	end 
end 

ElementHandler.RegisterEvent = function(proxy, event, func)
	if (not Callbacks[proxy]) then
		Callbacks[proxy] = {}
	end
	if (not Callbacks[proxy][event]) then
		Callbacks[proxy][event] = {}
	end
	
	local events = Callbacks[proxy][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not IsEventRegistered(proxy, event)) then
		RegisterEvent(proxy, event)
	end
end

ElementHandler.RegisterMessage = function(proxy, event, func)
	if (not Callbacks[proxy]) then
		Callbacks[proxy] = {}
	end
	if (not Callbacks[proxy][event]) then
		Callbacks[proxy][event] = {}
	end
	
	local events = Callbacks[proxy][event]
	if (#events > 0) then
		for i = #events, 1, -1 do
			if (events[i] == func) then
				return
			end
		end
	end

	table_insert(events, func)

	if (not IsMessageRegistered(proxy, event)) then
		RegisterMessage(proxy, event)
	end
end 

ElementHandler.UnregisterEvent = function(proxy, event, func)
	-- silently fail if the event isn't even registered
	if not Callbacks[proxy] or not Callbacks[proxy][event] then
		return
	end

	local events = Callbacks[proxy][event]

	if #events > 0 then
		-- find the function's id 
		for i = #events, 1, -1 do
			if events[i] == func then
				events[i] = nil -- remove the function from the event's registry
				if #events == 0 then
					UnregisterEvent(proxy, event) 
				end
			end
		end
	end
end

ElementHandler.UnregisterMessage = function(proxy, event, func)
	-- silently fail if the event isn't even registered
	if not Callbacks[proxy] or not Callbacks[proxy][event] then
		return
	end

	local events = Callbacks[proxy][event]

	if #events > 0 then
		-- find the function's id 
		for i = #events, 1, -1 do
			if events[i] == func then
				events[i] = nil -- remove the function from the event's registry
				if #events == 0 then
					UnregisterMessage(proxy, event) 
				end
			end
		end
	end
end

ElementHandler.UnregisterAllEvents = function(proxy)
	if not Callbacks[proxy] then 
		return
	end
	for event, funcs in pairs(Callbacks[proxy]) do
		for i = #funcs, 1, -1 do
			funcs[i] = nil
		end
	end
	UnregisterAllEvents(proxy)
end

ElementHandler.UnregisterAllMessages = function(proxy)
	if not Callbacks[proxy] then 
		return
	end
	for event, funcs in pairs(Callbacks[proxy]) do
		for i = #funcs, 1, -1 do
			funcs[i] = nil
		end
	end
	UnregisterAllMessages(proxy)
end

ElementHandler.CreateOverlayFrame = function(proxy, frameType)
	check(frameType, 1, "string", "nil")
	return LibActionButton:SyncMinimap(true) and Private.MapOverlay:CreateFrame(frameType or "Frame")
end 

ElementHandler.CreateBorderFrame = function(proxy, frameType)
	check(frameType, 1, "string", "nil")
	return LibActionButton:SyncMinimap(true) and Private.MapBorder:CreateFrame(frameType or "Frame")
end 

ElementHandler.CreateBorderText = function(proxy)
	return LibActionButton:SyncMinimap(true) and Private.MapBorder:CreateFontString()
end 

ElementHandler.CreateBorderTexture = function(proxy)
	return LibActionButton:SyncMinimap(true) and Private.MapBorder:CreateTexture()
end 

ElementHandler.CreateContentTexture = function(proxy)
	return LibActionButton:SyncMinimap(true) and Private.MapContent:CreateTexture()
end 

ElementHandler.CreateBackdropTexture = function(proxy)
	return LibActionButton:SyncMinimap(true) and Private.MapVisibility:CreateTexture()
end 

-- Return or create the library default tooltip
ElementHandler.GetTooltip = function(proxy)
	return LibActionButton:GetTooltip("CG_ActionButtonTooltip") or LibActionButton:CreateTooltip("CG_ActionButtonTooltip")
end


-- Button API Mapping
-----------------------------------------------------------

--- Generic Button API mapping
Button.HasAction						= function(self) return nil end
Button.GetActionText					= function(self) return "" end
Button.GetTexture						= function(self) return nil end
Button.GetCharges						= function(self) return nil end
Button.GetCount							= function(self) return 0 end
Button.GetCooldown						= function(self) return 0, 0, 0 end
Button.IsAttack							= function(self) return nil end
Button.IsEquipped						= function(self) return nil end
Button.IsCurrentlyActive				= function(self) return nil end
Button.IsAutoRepeat						= function(self) return nil end
Button.IsUsable							= function(self) return nil end
Button.IsConsumableOrStackable 			= function(self) return nil end
Button.IsUnitInRange					= function(self, unit) return nil end
Button.IsInRange						= function(self)
	local unit = self:GetAttribute("unit")
	if (unit == "player") then
		unit = nil
	end
	local val = self:IsUnitInRange(unit)
	
	-- map 1/0 to true false, since the return values are inconsistent between actions and spells
	if val == 1 then val = true elseif val == 0 then val = false end
	
	-- map nil to true, to avoid marking spells with no range as out of range
	if val == nil then val = true end

	return val
end
Button.GetTooltip 						= function(self) return LibActionButton:GetTooltip("CG_ActionButtonTooltip") or 
																LibActionButton:CreateTooltip("CG_ActionButtonTooltip") end 
Button.SetTooltip						= function(self) return nil end
Button.GetSpellId						= function(self) return nil end
Button.GetLossOfControlCooldown 		= function(self) return 0, 0 end



-- Spell Button API mapping
SpellButton.HasAction					= function(self) return true end
SpellButton.GetActionText				= function(self) return "" end
SpellButton.GetTexture					= function(self) return GetSpellTexture(self.action_by_state) end
SpellButton.GetCharges					= function(self) return GetSpellCharges(self.action_by_state) end
SpellButton.GetCount					= function(self) return GetSpellCount(self.action_by_state) end
SpellButton.GetCooldown					= function(self) return GetSpellCooldown(self.action_by_state) end
SpellButton.IsAttack					= function(self) return IsAttackSpell(FindSpellBookSlotBySpellID(self.action_by_state), "spell") end -- needs spell book id as of 4.0.1.13066
SpellButton.IsEquipped					= function(self) return nil end
SpellButton.IsCurrentlyActive			= function(self) return IsCurrentSpell(self.action_by_state) end
SpellButton.IsAutoRepeat				= function(self) return IsAutoRepeatSpell(FindSpellBookSlotBySpellID(self.action_by_state), "spell") end -- needs spell book id as of 4.0.1.13066
SpellButton.IsUsable					= function(self) return IsUsableSpell(self.action_by_state) end
SpellButton.IsConsumableOrStackable		= function(self) return IsConsumableSpell(self.action_by_state) end
SpellButton.IsUnitInRange				= function(self, unit) return IsSpellInRange(FindSpellBookSlotBySpellID(self.action_by_state), "spell", unit) end -- needs spell book id as of 4.0.1.13066
SpellButton.SetTooltip					= function(self) return (not GameTooltip:IsForbidden()) and GameTooltip:SetSpellByID(self.action_by_state) end
SpellButton.GetSpellId					= function(self) return self.action_by_state end


ItemButton.HasAction					= function(self) return true end
ItemButton.GetActionText				= function(self) return "" end
ItemButton.GetTexture					= function(self) return GetItemIcon(self.action_by_state) end
ItemButton.GetCharges					= function(self) return nil end
ItemButton.GetCount						= function(self) return GetItemCount(self.action_by_state, nil, true) end
ItemButton.GetCooldown					= function(self) return GetItemCooldown(getItemId(self.action_by_state)) end
ItemButton.IsAttack						= function(self) return nil end
ItemButton.IsEquipped					= function(self) return IsEquippedItem(self.action_by_state) end
ItemButton.IsCurrentlyActive			= function(self) return IsCurrentItem(self.action_by_state) end
ItemButton.IsAutoRepeat					= function(self) return nil end
ItemButton.IsUsable						= function(self) return IsUsableItem(self.action_by_state) end
ItemButton.IsConsumableOrStackable		= function(self) 
	local stackSize = select(8, GetItemInfo(self.action_by_state)) -- salvage crates and similar don't register as consumables
	return IsConsumableItem(self.action_by_state) or (stackSize and (stackSize > 1))
end
ItemButton.IsUnitInRange				= function(self, unit) return IsItemInRange(self.action_by_state, unit) end
ItemButton.SetTooltip					= function(self) return (not GameTooltip:IsForbidden()) and GameTooltip:SetHyperlink(self.action_by_state) end
ItemButton.GetSpellId					= function(self) return nil end


--- Macro Button API mapping
MacroButton.HasAction					= function(self) return true end
MacroButton.GetActionText				= function(self) return (GetMacroInfo(self.action_by_state)) end
MacroButton.GetTexture					= function(self) return (select(2, GetMacroInfo(self.action_by_state))) end
MacroButton.GetCharges					= function(self) return nil end
MacroButton.GetCount					= function(self) return 0 end
MacroButton.GetCooldown					= function(self) return 0, 0, 0 end
MacroButton.IsAttack					= function(self) return nil end
MacroButton.IsEquipped					= function(self) return nil end
MacroButton.IsCurrentlyActive			= function(self) return nil end
MacroButton.IsAutoRepeat				= function(self) return nil end
MacroButton.IsUsable					= function(self) return nil end
MacroButton.IsConsumableOrStackable		= function(self) return nil end
MacroButton.IsUnitInRange				= function(self, unit) return nil end
MacroButton.SetTooltip					= function(self) return nil end
MacroButton.GetSpellId					= function(self) return nil end

--- Pet Button
PetActionButton.HasAction				= function(self) return GetPetActionInfo(self.id) end
PetActionButton.GetCooldown				= function(self) return GetPetActionCooldown(self.id) end
PetActionButton.IsCurrentlyActive		= function(self) return select(4, GetPetActionInfo(self.id)) end
PetActionButton.IsAutoRepeat			= function(self) return nil end -- select(7, GetPetActionInfo(self.id))
PetActionButton.SetTooltip				= function(self) 
	if (not self.tooltipName) then
		return
	end
	if GameTooltip:IsForbidden() then
		return
	end

	GameTooltip:SetText(self.tooltipName, 1.0, 1.0, 1.0)

	if self.tooltipSubtext then
		GameTooltip:AddLine(self.tooltipSubtext, "", 0.5, 0.5, 0.5)
	end

	-- We need an extra :Show(), or the tooltip will get the wrong height if it has a subtext
	return GameTooltip:Show() 

	-- This isn't good enough, as it don't work for the generic attack/defense and so on
	--return GameTooltip:SetPetAction(self.id) 
end
PetActionButton.IsAttack				= function(self) return nil end
PetActionButton.IsUsable				= function(self) return GetPetActionsUsable() end
PetActionButton.GetActionText			= function(self)
	local name, _, isToken = GetPetActionInfo(self.id)
	return isToken and _G[name] or name
end
PetActionButton.GetTexture				= function(self)
	local name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = GetPetActionInfo(self.id)
	return isToken and _G[texture] or texture
end

--- Stance Button
StanceButton.HasAction 					= function(self) return GetShapeshiftFormInfo(self.id) end
StanceButton.GetCooldown 				= function(self) return GetShapeshiftFormCooldown(self.id) end
StanceButton.GetActionText 				= function(self) return select(2,GetShapeshiftFormInfo(self.id)) end
StanceButton.GetTexture 				= function(self) return GetShapeshiftFormInfo(self.id) end
StanceButton.IsCurrentlyActive 			= function(self) return select(3,GetShapeshiftFormInfo(self.id)) end
StanceButton.IsUsable 					= function(self) return select(4,GetShapeshiftFormInfo(self.id)) end
StanceButton.SetTooltip					= function(self) return (not GameTooltip:IsForbidden()) and GameTooltip:SetShapeshift(self.id) end



-- Spawn a new button
LibActionButton.CreateActionButton = function(self, parent, buttonType, buttonID, buttonTemplate, ...)

	
	local button
	if (buttonType == "pet") then
		button = setmetatable(LibActionButton:CreateFrame("CheckButton", name , header, "PetActionButtonTemplate"), Button_MT)
		button:UnregisterAllEvents()
		button:SetScript("OnEvent", nil)
		button:SetScript("OnUpdate", nil)
		button:SetScript("OnDragStart", nil)
		button:SetScript("OnReceiveDrag", nil)
		
	elseif (buttonType == "stance") then
		button = setmetatable(LibActionButton:CreateFrame("CheckButton", name , header, "StanceButtonTemplate"), Button_MT)
		button:UnregisterAllEvents()
		button:SetScript("OnEvent", nil)
		
	--elseif (buttonType == "extra") then
		--button = setmetatable(LibActionButton:CreateFrame("CheckButton", name , header, "ExtraActionButtonTemplate"), Button_MT)
		--button:UnregisterAllEvents()
		--button:SetScript("OnEvent", nil)
	
	else
		button = setmetatable(LibActionButton:CreateFrame("CheckButton", name , header, "SecureActionButtonTemplate"), Button_MT)
		button:RegisterForDrag("LeftButton", "RightButton")
		
		local cast_on_down = GetCVarBool("ActionButtonUseKeyDown")
		if cast_on_down then
			button:RegisterForClicks("AnyDown")
		else
			button:RegisterForClicks("AnyUp")
		end
	end

	-- Add any methods from the optional template.
	if buttonTemplate then
		for name, method in pairs(buttonTemplate) do
			-- Do not allow this to overwrite existing methods,
			-- also make sure it's only actual functions we inherit.
			if (type(method) == "function") and (not button[name]) then
				button[name] = method
			end
		end
	end
	
	-- Call the post create method if it exists, 
	-- and pass along any remaining arguments.
	-- This is a good place to add styling.
	if button.PostCreate then
		button:PostCreate(...)
	end

end


-- Register a button type.
-- We're using the RegisterElement name mainly for semantic reasons, 
-- to keep it in consistent with the other cogwheel libraries utilizing templates or elements.
-- Not quite sure what the functions other than enableFunc will actually do. Will get back to this! 
LibActionButton.RegisterElement = function(self, elementName, enableFunc, disableFunc, updateFunc, spawnFunc, version)
	check(elementName, 1, "string")
	check(enableFunc, 2, "function")
	check(disableFunc, 3, "function", "nil")
	check(updateFunc, 4, "function", "nil")
	check(version, 5, "number", "nil")
	
	-- Does an old version of the element exist?
	local old = Elements[elementName]
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
	Elements[elementName] = new 

	-- Postupdate existing frames embedding this if it exists
	if needUpdate then 
		-- iterate all frames for it
		for module, element in pairs(ElementPoolEnabled) do 
			if (element == elementName) then 
				-- Run the old disable method, 
				-- to get rid of old events and onupdate handlers
				if old.Disable then 
					old.Disable(module)
				end 

				-- Run the new enable method
				if new.Enable then 
					new.Enable(module, "Update", true)
				end 
			end 
		end 
	end 
end

-- Module embedding
local embedMethods = {
	CreateActionButton = true
}

LibActionButton.Embed = function(self, target)
	for method in pairs(embedMethods) do
		target[method] = self[method]
	end
	self.embeds[target] = true
	return target
end

-- Upgrade existing embeds, if any
for target in pairs(LibActionButton.embeds) do
	LibActionButton:Embed(target)
end
