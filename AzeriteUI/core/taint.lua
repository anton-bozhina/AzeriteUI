local LibModule = CogWheel("LibModule")
if (not LibModule) then 
	return 
end

---------------------------------------------------------------
-- UIDropDown taints
-- Source: https://www.townlong-yak.com/bugs/afKy4k-HonorFrameLoadTaint

if UIDropDownMenu_InitializeHelper then 
	if ((UIDROPDOWNMENU_VALUE_PATCH_VERSION or 0) < 2) then 
		UIDROPDOWNMENU_VALUE_PATCH_VERSION = 2 
		hooksecurefunc("UIDropDownMenu_InitializeHelper", function() 
			if UIDROPDOWNMENU_VALUE_PATCH_VERSION ~= 2 then 
				return 
			end 
			for i=1, UIDROPDOWNMENU_MAXLEVELS do 
				for j=1, UIDROPDOWNMENU_MAXBUTTONS do 
					local b = _G["DropDownList" .. i .. "Button" .. j] 
					if not (issecurevariable(b, "value") or b:IsShown()) then 
						b.value = nil 
						repeat 
							j, b["fx" .. j] = j+1 
						until issecurevariable(b, "value") 
					end 
				end 
			end 
		end) 
	end 
end

---------------------------------------------------------------
-- Various Blizzard Bugs
-- All credits to the individual authors. 
-- Source: https://www.wowace.com/projects/blizzbugssuck
if (not LibModule:IsAddOnEnabled("!BlizzBugsSuck")) then 

	-- Fix incorrect translations in the German localization
	if GetLocale() == "deDE" then
		-- Day one-letter abbreviation is using a whole word instead of one letter.
		-- Confirmed still bugged in 7.0.3.22293
		DAY_ONELETTER_ABBR = "%d d"
	end

	-- Fix error when shift-clicking header rows in the tradeskill UI.
	-- This is caused by the TradeSkillRowButtonTemplate's OnClick script
	-- failing to account for some rows being headers. Fix by ignoring
	-- modifiers when clicking header rows.
	-- New in 7.0
	do
		local frame = CreateFrame("Frame")
		frame:RegisterEvent("ADDON_LOADED")
		frame:SetScript("OnEvent", function(self, event, name)
			if name == "Blizzard_TradeSkillUI" then
				local old_OnClick = TradeSkillFrame.RecipeList.buttons[1]:GetScript("OnClick")
				local new_OnClick = function(self, button)
					if IsModifiedClick() and self.isHeader then
						return self:GetParent():GetParent():OnHeaderButtonClicked(self, self.tradeSkillInfo, button)
					end
					old_OnClick(self, button)
				end
				for i = 1, #TradeSkillFrame.RecipeList.buttons do
					TradeSkillFrame.RecipeList.buttons[i]:SetScript("OnClick", new_OnClick)
				end
				self:UnregisterAllEvents()
			end
		end)
	end

	-- Fix error when mousing over the Nameplate Motion Type dropdown in
	-- Interface Options > Names panel if the current setting isn't listed.
	-- Happens if the user had previously selected the Spreading Nameplates
	-- option, which was removed from the game in 7.0.
	do
		local OnEnter = InterfaceOptionsNamesPanelUnitNameplatesMotionDropDown:GetScript("OnEnter")
		InterfaceOptionsNamesPanelUnitNameplatesMotionDropDown:SetScript("OnEnter", function(self)
			if self.tooltip then
				OnEnter(self)
			end
		end)
	end

	-- Fix missing bonus effects on shipyard map in non-English locales
	-- Problem is caused by Blizzard checking a localized API value
	-- against a hardcoded English string.
	-- New in 6.2, confirmed still bugged in 7.0.3.22293
	if GetLocale() ~= "enUS" then
		local frame = CreateFrame("Frame")
		frame:RegisterEvent("ADDON_LOADED")
		frame:SetScript("OnEvent", function(self, event, name)
			if name == "Blizzard_GarrisonUI" then
				hooksecurefunc("GarrisonShipyardMap_SetupBonus", function(self, missionFrame, mission)
					if (mission.typePrefix == "ShipMissionIcon-Bonus" and not missionFrame.bonusRewardArea) then
						missionFrame.bonusRewardArea = true
						for id, reward in pairs(mission.rewards) do
							local posX = reward.posX or 0
							local posY = reward.posY or 0
							posY = posY * -1
							missionFrame.BonusAreaEffect:SetAtlas(reward.textureAtlas, true)
							missionFrame.BonusAreaEffect:ClearAllPoints()
							missionFrame.BonusAreaEffect:SetPoint("CENTER", self.MapTexture, "TOPLEFT", posX, posY)
							break
						end
					end
				end)
				self:UnregisterAllEvents()
			end
		end)
	end

	-- Fix InterfaceOptionsFrame_OpenToCategory not actually opening the category (and not even scrolling to it)
	-- Confirmed still broken in 6.2.2.20490 (6.2.2a)
	do
		local function get_panel_name(panel)
			local tp = type(panel)
			local cat = INTERFACEOPTIONS_ADDONCATEGORIES
			if tp == "string" then
				for i = 1, #cat do
					local p = cat[i]
					if p.name == panel then
						if p.parent then
							return get_panel_name(p.parent)
						else
							return panel
						end
					end
				end
			elseif tp == "table" then
				for i = 1, #cat do
					local p = cat[i]
					if p == panel then
						if p.parent then
							return get_panel_name(p.parent)
						else
							return panel.name
						end
					end
				end
			end
		end

		local function InterfaceOptionsFrame_OpenToCategory_Fix(panel)
			if doNotRun or InCombatLockdown() then return end
			local panelName = get_panel_name(panel)
			if not panelName then return end -- if its not part of our list return early
			local noncollapsedHeaders = {}
			local shownpanels = 0
			local mypanel
			local t = {}
			local cat = INTERFACEOPTIONS_ADDONCATEGORIES
			for i = 1, #cat do
				local panel = cat[i]
				if not panel.parent or noncollapsedHeaders[panel.parent] then
					if panel.name == panelName then
						panel.collapsed = true
						t.element = panel
						InterfaceOptionsListButton_ToggleSubCategories(t)
						noncollapsedHeaders[panel.name] = true
						mypanel = shownpanels + 1
					end
					if not panel.collapsed then
						noncollapsedHeaders[panel.name] = true
					end
					shownpanels = shownpanels + 1
				end
			end
			local Smin, Smax = InterfaceOptionsFrameAddOnsListScrollBar:GetMinMaxValues()
			if shownpanels > 15 and Smin < Smax then
				local val = (Smax/(shownpanels-15))*(mypanel-2)
				InterfaceOptionsFrameAddOnsListScrollBar:SetValue(val)
			end
			doNotRun = true
			InterfaceOptionsFrame_OpenToCategory(panel)
			doNotRun = false
		end

		hooksecurefunc("InterfaceOptionsFrame_OpenToCategory", InterfaceOptionsFrame_OpenToCategory_Fix)
	end

	-- Avoid taint from the UIFrameFlash usage of the chat frames.  More info here:
	-- http://forums.wowace.com/showthread.php?p=324936
	-- Fixed by embedding LibChatAnims
	do
		-- The library could be loaded after this, but that doesn't matter. 
		-- The important thing is that the original blizzard code causing the taint is replaced.
		if (not (LibStub and LibStub("LibChatAnims", true))) then
			local anims = {} -- Animation storage
			
			----------------------------------------------------
			-- Note, most of this code is simply replicated from
			-- Blizzard's FloatingChatFrame.lua file.
			-- The only real changes are the creation and use
			-- of animations vs the use of UIFrameFlash.
			--
			
			FCFDockOverflowButton_UpdatePulseState = function(self)
				local dock = self:GetParent()
				local shouldPulse = false
				for _, chatFrame in pairs(FCFDock_GetChatFrames(dock)) do
					local chatTab = _G[chatFrame:GetName().."Tab"]
					if ( not chatFrame.isStaticDocked and chatTab.alerting) then
						-- Make sure the rects are valid. (Not always the case when resizing the WoW client
						if ( not chatTab:GetRight() or not dock.scrollFrame:GetRight() ) then
							return false
						end
						-- Check if it's off the screen.
						local DELTA = 3 -- Chosen through experimentation
						if ( chatTab:GetRight() < (dock.scrollFrame:GetLeft() + DELTA) or chatTab:GetLeft() > (dock.scrollFrame:GetRight() - DELTA) ) then
							shouldPulse = true
							break
						end
					end
				end
			
				local tex = self:GetHighlightTexture()
				if shouldPulse then
					if not anims[tex] then
						anims[tex] = tex:CreateAnimationGroup()
			
						local fade1 = anims[tex]:CreateAnimation("Alpha")
						fade1:SetDuration(1)
						fade1:SetFromAlpha(0)
						fade1:SetToAlpha(1)
						fade1:SetOrder(1)
			
						local fade2 = anims[tex]:CreateAnimation("Alpha")
						fade2:SetDuration(1)
						fade2:SetFromAlpha(1)
						fade2:SetToAlpha(0)
						fade2:SetOrder(2)
					end
					tex:Show()
					tex:SetAlpha(0)
					anims[tex]:SetLooping("REPEAT")
					anims[tex]:Play()
			
					self:LockHighlight()
					self.alerting = true
				else
					if anims[tex] then
						anims[tex]:Stop()
					end
					self:UnlockHighlight()
					tex:SetAlpha(1)
					tex:Show()
					self.alerting = false
				end
			
				if self.list:IsShown() then
					FCFDockOverflowList_Update(self.list, dock)
				end
				return true
			end
			
			FCFDockOverflowListButton_SetValue = function(button, chatFrame)
				local chatTab = _G[chatFrame:GetName().."Tab"]
				button.chatFrame = chatFrame
				button:SetText(chatFrame.name)
			
				local colorTable = chatTab.selectedColorTable or DEFAULT_TAB_SELECTED_COLOR_TABLE
			
				if chatTab.selectedColorTable then
					button:GetFontString():SetTextColor(colorTable.r, colorTable.g, colorTable.b)
				else
					button:GetFontString():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
				end
			
				button.glow:SetVertexColor(colorTable.r, colorTable.g, colorTable.b)
			
				if chatTab.conversationIcon then
					button.conversationIcon:SetVertexColor(colorTable.r, colorTable.g, colorTable.b)
					button.conversationIcon:Show()
				else
					button.conversationIcon:Hide()
				end
			
				if chatTab.alerting then
					button.alerting = true
					if not anims[button.glow] then
						anims[button.glow] = button.glow:CreateAnimationGroup()
			
						local fade1 = anims[button.glow]:CreateAnimation("Alpha")
						fade1:SetDuration(1)
						fade1:SetFromAlpha(0)
						fade1:SetToAlpha(1)
						fade1:SetOrder(1)
			
						local fade2 = anims[button.glow]:CreateAnimation("Alpha")
						fade2:SetDuration(1)
						fade2:SetFromAlpha(1)
						fade2:SetToAlpha(0)
						fade2:SetOrder(2)
					end
					button.glow:Show()
					button.glow:SetAlpha(0)
					anims[button.glow]:SetLooping("REPEAT")
					anims[button.glow]:Play()
				else
					button.alerting = false
					if anims[button.glow] then
						anims[button.glow]:Stop()
					end
					button.glow:Hide()
				end
				button:Show()
			end
			
			FCF_StartAlertFlash = function(chatFrame)
				local chatTab = _G[chatFrame:GetName().."Tab"]
			
				if chatFrame.minFrame then
					if not anims[chatFrame.minFrame] then
						anims[chatFrame.minFrame] = chatFrame.minFrame.glow:CreateAnimationGroup()
			
						local fade1 = anims[chatFrame.minFrame]:CreateAnimation("Alpha")
						fade1:SetDuration(1)
						fade1:SetFromAlpha(0)
						fade1:SetToAlpha(1)
						fade1:SetOrder(1)
			
						local fade2 = anims[chatFrame.minFrame]:CreateAnimation("Alpha")
						fade2:SetDuration(1)
						fade2:SetFromAlpha(1)
						fade2:SetToAlpha(0)
						fade2:SetOrder(2)
					end
					chatFrame.minFrame.glow:Show()
					chatFrame.minFrame.glow:SetAlpha(0)
					anims[chatFrame.minFrame]:SetLooping("REPEAT")
					anims[chatFrame.minFrame]:Play()
					chatFrame.minFrame.alerting = true
				end
			
				if not anims[chatTab.glow] then
					anims[chatTab.glow] = chatTab.glow:CreateAnimationGroup()
			
					local fade1 = anims[chatTab.glow]:CreateAnimation("Alpha")
					fade1:SetDuration(1)
					fade1:SetFromAlpha(0)
					fade1:SetToAlpha(1)
					fade1:SetOrder(1)
			
					local fade2 = anims[chatTab.glow]:CreateAnimation("Alpha")
					fade2:SetDuration(1)
					fade2:SetFromAlpha(1)
					fade2:SetToAlpha(0)
					fade2:SetOrder(2)
				end
				chatTab.glow:Show()
				chatTab.glow:SetAlpha(0)
				anims[chatTab.glow]:SetLooping("REPEAT")
				anims[chatTab.glow]:Play()
				chatTab.alerting = true
			
				FCFTab_UpdateAlpha(chatFrame)
				FCFDockOverflowButton_UpdatePulseState(GENERAL_CHAT_DOCK.overflowButton)
			end
			
			FCF_StopAlertFlash = function(chatFrame)
				local chatTab = _G[chatFrame:GetName().."Tab"]
			
				if chatFrame.minFrame then
					if anims[chatFrame.minFrame] then
						anims[chatFrame.minFrame]:Stop()
					end
					chatFrame.minFrame.glow:Hide()
					chatFrame.minFrame.alerting = false
				end
			
				if anims[chatTab.glow] then
					anims[chatTab.glow]:Stop()
				end
				chatTab.glow:Hide()
				chatTab.alerting = false
			
				FCFTab_UpdateAlpha(chatFrame)
				FCFDockOverflowButton_UpdatePulseState(GENERAL_CHAT_DOCK.overflowButton)
			end
			
		end 
	end 


	-- Fix an issue where the PetJournal drag buttons (the pet icons in the ACTIVE team on the right
	-- pane of the PetJournal) cannot be clicked to link a pet into chat.
	-- The necessary code is already present, but the buttons are not registered for the correct click.
	-- Confirmed still bugged in 7.0.3.22293
	do
		local frame = CreateFrame("Frame")
		frame:RegisterEvent("ADDON_LOADED")
		frame:SetScript("OnEvent", function(self, event, name)
			if name == "Blizzard_Collections" then
				for i = 1, 3 do
					local button = _G["PetJournalLoadoutPet"..i]
					if button and button.dragButton then
						button.dragButton:RegisterForClicks("LeftButtonUp")
					end
				end
				self:UnregisterAllEvents()
			end
		end)
	end

	-- Fix a lua error when scrolling the in-game Addon list, where the mouse
	-- passes over a world object that activates GameTooltip.
	-- Caused because the FrameXML code erroneously assumes it exclusively owns the GameTooltip object
	-- Confirmed still bugged in 7.0.3.22293
	do
		local orig = AddonTooltip_Update
		_G.AddonTooltip_Update = function(owner, ...) 
			if AddonList and AddonList:IsMouseOver() then
				local id = owner and owner.GetID and owner:GetID()
				if id and id > 0 and id <= GetNumAddOns() then
					orig(owner, ...) 
					return
				end
			end
			--print("ADDON LIST FIX ACTIVATED") 
		end
	end


	-- Fix glitchy-ness of EnableAddOn/DisableAddOn API, which affects the stability of the default 
	-- UI's addon management list (both in-game and glue), as well as any addon-management addons.
	-- The problem is caused by broken defaulting logic used to merge AddOns.txt settings across 
	-- characters to those missing a setting in AddOns.txt, whereby toggling an addon for a single character 
	-- sometimes results in also toggling it for a different character on that realm for no obvious reason.
	-- The code below ensures each character gets an independent enable setting for each installed 
	-- addon in its AddOns.txt file, thereby avoiding the broken defaulting logic.
	-- Note the fix applies to each character the first time it loads there, and a given character 
	-- is not protected from the faulty logic on addon X until after the fix has run with addon X 
	-- installed (regardless of enable setting) and the character has logged out normally.
	-- Confirmed bugged in 6.2.3.20886
	do
		local player = UnitName("player")
		if player and #player > 0 then
			for i=1,GetNumAddOns() do 
				if GetAddOnEnableState(player, i) > 0 then  -- addon is enabled
					EnableAddOn(i, player)
				else
					DisableAddOn(i, player)
				end 
			end
		end
	end


end 


