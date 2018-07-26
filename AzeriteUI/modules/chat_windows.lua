local ADDON = ...

local AzeriteUI = CogWheel("LibModule"):GetModule("AzeriteUI")
if (not AzeriteUI) then 
	return 
end

local ChatWindows = AzeriteUI:NewModule("ChatWindows", "LibEvent", "LibDB", "LibFrame", "LibChatWindow")
local Colors = CogWheel("LibDB"):GetDatabase("AzeriteUI: Colors")

-- Lua API
local _G = _G
local math_floor = math.floor
local string_len = string.len
local string_sub = string.sub 

-- WoW API
local FCF_SetWindowAlpha = _G.FCF_SetWindowAlpha
local FCF_SetWindowColor = _G.FCF_SetWindowColor
local FCF_Tab_OnClick = _G.FCF_Tab_OnClick
local IsShiftKeyDown = _G.IsShiftKeyDown
local UIFrameFadeRemoveFrame = _G.UIFrameFadeRemoveFrame
local UIFrameIsFading = _G.UIFrameIsFading
local UnitAffectingCombat = _G.UnitAffectingCombat
local VoiceChat_IsLoggedIn = _G.C_VoiceChat and _G.C_VoiceChat.IsLoggedIn

local alphaLocks = {}
local scaffolds = {}



-- Utility Functions
----------------------------------------------------------

-- Proxy function to get media from our local media folder
local getPath = function(fileName)
	return ([[Interface\AddOns\%s\media\%s]]):format(ADDON, fileName)
end 
	
ChatWindows.UpdateChatWindowAlpha = function(self, frame)
	local editBox = self:GetChatWindowCurrentEditBox(frame)
	local alpha
	if editBox:IsShown() then
		alpha = 0.25
	else
		alpha = 0
	end
	for index, value in pairs(CHAT_FRAME_TEXTURES) do
		if (not value:find("Tab")) then
			local object = _G[frame:GetName()..value]
			if object:IsShown() then
				UIFrameFadeRemoveFrame(object)
				object:SetAlpha(alpha)
			end
		end
	end
end 

-- Meant to update down button and scrollbar
ChatWindows.UpdateChatWindowButtons = function(self)
end 

ChatWindows.UpdateChatWindowScales = function(self)
	local scale = UIParent:GetEffectiveScale() / self:GetFrame("UICenter"):GetEffectiveScale()

	for _,frameName in self:GetAllChatWindows() do 
		local frame = _G[frameName]
		if frame then 
			local parent = frame:GetParent()
			local w,h = parent:GetSize()
			local point, anchor, rpoint, x, y = parent:GetPoint()

			frame:SetScale(scale)
			frame:SetSize(w, h)
			frame:ClearAllPoints()
			frame:SetPoint(point, anchor, rpoint, x/scale, y/scale)
		end 
	end 
end 

ChatWindows.UpdateChatWindowPositions = function(self)
end 

-- Meant to update the main window buttons
ChatWindows.UpdateMainWindowButtons = function(self)

	local show

	local frame = self:GetSelectedChatFrame()
	if frame and frame.isDocked then 
		local editBox = self:GetChatWindowEditBox(frame)
		show = editBox and editBox:IsShown()
	end 

	local channelButton = self:GetChatWindowChannelButton()
	local deafenButton = self:GetChatWindowVoiceDeafenButton()
	local muteButton =self:GetChatWindowVoiceMuteButton()
	local menuButton = self:GetChatWindowMenuButton()

	if show then 
		if channelButton then 
			channelButton:Show()
		end 
		if VoiceChat_IsLoggedIn() then 
			if deafenButton then 
				deafenButton:Show()
			end 
			if muteButton then 
				muteButton:Show()
			end 
		else 
			if deafenButton then 
				deafenButton:Hide()
			end 
			if muteButton then 
				muteButton:Hide()
			end 
		end 
		if menuButton then 
			menuButton:Show()
		end

	else
		if channelButton then 
			channelButton:Hide()
		end 
		if deafenButton then 
			deafenButton:Hide()
		end 
		if muteButton then 
			muteButton:Hide()
		end 
		if menuButton then 
			menuButton:Hide()
		end 
	end 

end

-- Temporary windows (like whisper windows, etc)
-- This overrides the normal PostCreateChatWindow
ChatWindows.PostCreateTemporaryChatWindow = function(self, frame, ...)
	local chatType, chatTarget, sourceChatFrame, selectWindow = ...

	self:PostCreateChatWindow(frame)
end 

ChatWindows.PostCreateChatWindow = function(self, frame)

	-- Window
	------------------------------

	frame:SetFading(5)
	frame:SetTimeVisible(15)
	frame:SetIndentedWordWrap(true)

	-- just lock all frames away from our important objects
	frame:SetClampRectInsets(-54, -54, -310, -330)

	FCF_SetWindowColor(frame, 0, 0, 0, 0)
	FCF_SetWindowAlpha(frame, 0, 1)
	FCF_UpdateButtonSide(frame)


	-- Tabs
	------------------------------

	-- strip away textures
	for tex in self:GetChatWindowTabTextures(frame) do 
		tex:SetTexture(nil)
		tex:SetAlpha(0)
	end 

	-- Take control of the tab's alpha changes
	-- and disable blizzard's own fading. 
	local tab = self:GetChatWindowTab(frame)
	tab:SetAlpha(1)
	tab.SetAlpha = UIFrameFadeRemoveFrame

	local tabText = self:GetChatWindowTabText(frame) 
	tabText:Hide()

	-- Hook all tab sizes to slightly smaller than ChatFrame1's chat
	hooksecurefunc(tabText, "Show", function() 
		-- Make it 2px smaller (before scaling), 
		-- but make 10px the minimum size.
		local font, size, style = ChatFrame1:GetFontObject():GetFont()
		size = math_floor(((size*10) + .5)/10)
		if (size + 2 >= 10) then 
			size = size - 2
		end 

		-- Stupid blizzard changing sizes by 0.0000001 and similar
		local ourFont, ourSize, ourStyle = tabText:GetFont()
		ourSize = math_floor(((ourSize*10) + .5)/10)

		-- Make sure the tabs keeps the same font as the frame, 
		-- and not some completely different size as it does by default. 
		if (ourFont ~= font) or (ourSize ~= size) or (style ~= ourStyle) then 
			tabText:SetFont(font, size, style)
		end 
	end)

	-- Toggle tab text visibility on hover
	tab:HookScript("OnEnter", function() tabText:Show() end)
	tab:HookScript("OnLeave", function() tabText:Hide() end)
	tab:HookScript("OnClick", function() 
		-- We need to hide both tabs and button frames here, 
		-- but it must depend on visible editBoxes. 
		local frame = self:GetSelectedChatFrame()
		local editBox = self:GetChatWindowCurrentEditBox(frame)
		if editBox then
			editBox:Hide() 
		end
		local buttonFrame = self:GetChatWindowButtonFrame(frame)
		if buttonFrame then
			buttonFrame:Hide() 
		end
	end)

	local anywhereButton = self:GetChatWindowClickAnywhereButton(frame)
	if anywhereButton then 
		anywhereButton:HookScript("OnEnter", function() tabText:Show() end)
		anywhereButton:HookScript("OnLeave", function() tabText:Hide() end)
		anywhereButton:HookScript("OnClick", function() 
			FCF_Tab_OnClick(_G[name]) -- click the tab to actually select this frame
			local editBox = self:GetChatWindowCurrentEditBox(frame)
			if editBox then
				editBox:Hide() -- hide the annoying half-transparent editBox 
			end
		end)
	end


	-- EditBox
	------------------------------

	-- strip away textures
	for tex in self:GetChatWindowEditBoxTextures(frame) do 
		tex:SetTexture(nil)
		tex:SetAlpha(0)
	end 

	local editBox = self:GetChatWindowEditBox(frame)
	editBox:Hide()
	editBox:SetAltArrowKeyMode(false) 
	editBox:SetHeight(45)
	editBox:ClearAllPoints()
	editBox:SetPoint("LEFT", frame, "LEFT", -15, 0)
	editBox:SetPoint("RIGHT", frame, "RIGHT", 15, 0)
	editBox:SetPoint("TOP", frame, "BOTTOM", 0, -1)

	-- do any editBox backdrop styling here

	-- make it auto-hide when focus is lost
	editBox:HookScript("OnEditFocusGained", function(self) self:Show() end)
	editBox:HookScript("OnEditFocusLost", function(self) self:Hide() end)

	-- hook editBox updates to our coloring method
	--hooksecurefunc("ChatEdit_UpdateHeader", function(...) self:UpdateEditBox(...) end)

	-- Avoid dying from having the editBox open in combat
	editBox:HookScript("OnTextChanged", function(self)
		local msg = self:GetText()
		local maxRepeats = UnitAffectingCombat("player") and 5 or 10
		if (string_len(msg) > maxRepeats) then
			local stuck = true
			for i = 1, maxRepeats, 1 do 
				if (string_sub(msg,0-i, 0-i) ~= string_sub(msg,(-1-i),(-1-i))) then
					stuck = false
					break
				end
			end
			if stuck then
				self:SetText("")
				self:Hide()
				return
			end
		end
	end)

	if (editBox:GetParent() ~= frame) then
		editBox:SetParent(frame)
	end

	hooksecurefunc(editBox, "SetParent", function(editBox, parent) 
		--if (parent == UIParent) then
		if (parent ~= frame) then
			editBox:SetParent(frame)
			--editBox:SetParent(self:GetFrame("UICenter"))
		end
	end)


	-- ButtonFrame
	------------------------------

	local buttonFrame = self:GetChatWindowButtonFrame(frame)
	buttonFrame:SetWidth(48)
	for tex in self:GetChatWindowButtonFrameTextures(frame) do 
		tex:SetTexture(nil)
		tex:SetAlpha(0)
	end

	editBox:HookScript("OnShow", function() 
		local frame = self:GetSelectedChatFrame()
		if frame then
			local buttonFrame = self:GetChatWindowButtonFrame(frame)
			if buttonFrame then
				buttonFrame:Show()
				buttonFrame:SetAlpha(1)
			end
			if frame.isDocked then
				self:UpdateMainWindowButtons(true)
			end
			self:UpdateChatWindowAlpha(frame)

			-- Hook all editbox chat sizes to the same as ChatFrame1
			local font, size, style = ChatFrame1:GetFontObject():GetFont()
			local ourFont, ourSize, ourStyle = editBox:GetFont()

			-- Stupid blizzard changing sizes by 0.0000001 and similar
			size = math_floor(((size*10) + .5)/10)
			ourSize = math_floor(((ourSize*10) + .5)/10)

			-- Make sure the editbox keeps the same font as the frame, 
			-- and not some completely different size as it does by default. 
			if (ourFont ~= font) or (ourSize ~= size) or (style ~= ourStyle) then 
				editBox:SetFont(font, size, style)
			end 

			local ourFont, ourSize, ourStyle = editBox.header:GetFont()
			ourSize = math_floor(((ourSize*10) + .5)/10)

			if (ourFont ~= font) or (ourSize ~= size) or (style ~= ourStyle) then 
				editBox.header:SetFont(font, size, style)
			end 
		end
	end)

	editBox:HookScript("OnHide", function() 
		local frame = self:GetSelectedChatFrame()
		if frame then
			local buttonFrame = self:GetChatWindowButtonFrame(frame)
			if buttonFrame then
				buttonFrame:Hide()
			end
			if frame.isDocked then
				self:UpdateMainWindowButtons(false)
			end
			self:UpdateChatWindowAlpha(frame)
		end
	end)

	hooksecurefunc(buttonFrame, "SetAlpha", function(buttonFrame, alpha)
		if alphaLocks[buttonFrame] then 
			return 
		else
			alphaLocks[buttonFrame] = true
			local frame = self:GetSelectedChatFrame()
			if UIFrameIsFading(frame) then
				UIFrameFadeRemoveFrame(frame)
			end	
			local editBox = self:GetChatWindowCurrentEditBox(frame)
			if editBox then 
				if editBox:IsShown() then
					buttonFrame:SetAlpha(1) 
				else
					buttonFrame:SetAlpha(0)
				end 
			end 
			alphaLocks[buttonFrame] = false
		end 
	end)
	buttonFrame:Hide()


	-- Frame specific buttons
	------------------------------

	local scrollToBottomButton = self:GetChatWindowScrollToBottomButton(frame)
	if scrollToBottomButton then 
		self:SetUpButton(scrollToBottomButton, 1.25, getPath("icon_chat_down"))
		scrollToBottomButton:SetPoint("BOTTOMRIGHT", frame.ResizeButton, "TOPRIGHT", -9, -11)
	end 

	local scrollBar = self:GetChatWindowScrollBar(frame)
	if scrollBar then 
		scrollBar:SetWidth(32)
	end

	local scrollThumb = self:GetChatWindowScrollBarThumbTexture(frame)
	if scrollThumb then 
		scrollThumb:SetWidth(32)
	end

	FCF_UpdateScrollbarAnchors(frame)

end 


ChatWindows.SetUpAlphaScripts = function(self)

	_G.CHAT_FRAME_BUTTON_FRAME_MIN_ALPHA = 0

	-- avoid mouseover alpha change, yet keep the background textures
	local alphaProxy = function(...) self:UpdateChatWindowAlpha(...) end
	
	hooksecurefunc("FCF_FadeInChatFrame", alphaProxy)
	hooksecurefunc("FCF_FadeOutChatFrame", alphaProxy)
	hooksecurefunc("FCF_SetWindowAlpha", alphaProxy)
	
end 

ChatWindows.SetUpScrollScripts = function(self)

	-- allow SHIFT + MouseWheel to scroll to the top or bottom
	hooksecurefunc("FloatingChatFrame_OnMouseScroll", function(self, delta)
		if delta < 0 then
			if IsShiftKeyDown() then
				self:ScrollToBottom()
			end
		elseif delta > 0 then
			if IsShiftKeyDown() then
				self:ScrollToTop()
			end
		end
	end)

	hooksecurefunc("FCF_UpdateScrollbarAnchors", function(self)
		if self.ScrollBar then
			self.ScrollBar:ClearAllPoints()
			self.ScrollBar:SetPoint("TOPLEFT", self, "TOPRIGHT", -13, -4)
	
			if self.ScrollToBottomButton and self.ScrollToBottomButton:IsShown() then
				self.ScrollBar:SetPoint("BOTTOM", self.ScrollToBottomButton, "TOP", -13, 5)
			
			elseif self.ResizeButton and self.ResizeButton:IsShown() then
				self.ScrollBar:SetPoint("BOTTOM", self.ResizeButton, "TOP", -13, 5)
			else
				self.ScrollBar:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", -13, 5)
			end
		end
	end)
	
end 

ChatWindows.SetUpMainFrames = function(self)

	-- Create a holder frame for our main chat window,
	-- which we'll use to move and size the window without 
	-- having to parent it to our upscaled master frame. 
	-- 
	-- The problem is that WoW renders chat to pixels 
	-- when the font is originally defined, 
	-- and any scaling later on is applied to that pixel font, 
	-- not to the original vector font. 
	local frame = self:CreateFrame("Frame")
	frame:SetPoint("LEFT", 85, 0)
	frame:SetSize(519, 196)

	self:HandleAllChatWindows()
	self:SetChatWindowAsSlaveTo(ChatFrame1, frame)

	FCF_SetWindowColor(ChatFrame1, 0, 0, 0, 0)
	FCF_SetWindowAlpha(ChatFrame1, 0, 1)
	FCF_UpdateButtonSide(ChatFrame1)

end 

ChatWindows.SetUpButton = function(self, button, sizeMod, texture)
	local normal = button:GetNormalTexture()
	normal:SetTexture(texture or getPath("point_block"))
	normal:SetVertexColor(Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3])
	normal:ClearAllPoints()
	normal:SetPoint("CENTER", 0, 0)
	normal:SetSize(64*sizeMod,64*sizeMod)

	local highlight = button:GetHighlightTexture()
	highlight:SetTexture(texture or getPath("point_block"))
	highlight:SetVertexColor(1,1,1,.075)
	highlight:ClearAllPoints()
	highlight:SetPoint("CENTER", 0, 0)
	highlight:SetSize(24*sizeMod,24*sizeMod)
	highlight:SetBlendMode("ADD")

	local pushed = button:GetPushedTexture()
	pushed:SetTexture(texture or getPath("point_block"))
	pushed:SetVertexColor(Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3])
	pushed:ClearAllPoints()
	pushed:SetPoint("CENTER", -1, -2)
	pushed:SetSize(64*sizeMod,64*sizeMod)

	local disabled = button:GetDisabledTexture()
	if disabled then 
		disabled:SetTexture(texture or getPath("point_block"))
		disabled:SetVertexColor(Colors.ui.stone[1], Colors.ui.stone[2], Colors.ui.stone[3])
		disabled:SetDesaturated(true)
		disabled:ClearAllPoints()
		disabled:SetPoint("CENTER", 0, 0)
		disabled:SetSize(64*sizeMod,64*sizeMod)
	end 

	local flash = button.Flash
	if flash then 
		flash:SetTexture(texture or getPath("point_block"))
		flash:SetVertexColor(1,1,1,.075)
		flash:ClearAllPoints()
		flash:SetPoint("CENTER", 0, 0)
		flash:SetSize(64*sizeMod,64*sizeMod)
		flash:SetBlendMode("ADD")
	end 

	button:HookScript("OnMouseDown", function() 
		highlight:SetPoint("CENTER", -1, -2) 
		if flash then 
			flash:SetPoint("CENTER", -1, -2) 
		end 
	end)

	button:HookScript("OnMouseUp", function() 
		highlight:SetPoint("CENTER", 0, 0) 
		if flash then 
			flash:SetPoint("CENTER", 0, 0) 
		end 
	end)
end 

ChatWindows.SetUpMainButtons = function(self)

	-- ChatFrame1 specific buttons
	local channelButton = self:GetChatWindowChannelButton()
	if channelButton then 
		self:SetUpButton(channelButton, 1.25)
	end 

	local deafenButton = self:GetChatWindowVoiceDeafenButton()
	if deafenButton then 
		self:SetUpButton(deafenButton, 1.25)
	end 

	local muteButton = self:GetChatWindowVoiceMuteButton()
	if muteButton then 
		self:SetUpButton(muteButton, 1.25)
	end 

	local menuButton = self:GetChatWindowMenuButton()
	if menuButton then 
		self:SetUpButton(menuButton, 1.25, getPath("config_button_bright"))
	end 
	
end 


ChatWindows.OnEvent = function(self, event, ...)
	self:UpdateMainWindowButtons()
end 

ChatWindows.OnInit = function(self)
	self:SetUpAlphaScripts()
	self:SetUpScrollScripts()
	self:SetUpMainFrames()
	self:SetUpMainButtons()
end 

ChatWindows.OnEnable = function(self)
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("VOICE_CHAT_LOGIN", "OnEvent")
	self:RegisterEvent("VOICE_CHAT_LOGOUT", "OnEvent")
	self:RegisterEvent("VOICE_CHAT_MUTED_CHANGED", "OnEvent")
	self:RegisterEvent("VOICE_CHAT_SILENCED_CHANGED", "OnEvent")
	self:RegisterEvent("VOICE_CHAT_DEAFENED_CHANGED", "OnEvent")
	self:RegisterEvent("VOICE_CHAT_CHANNEL_MEMBER_MUTE_FOR_ME_CHANGED", "OnEvent")
	self:RegisterEvent("VOICE_CHAT_CHANNEL_MEMBER_MUTE_FOR_ALL_CHANGED", "OnEvent")
	self:RegisterEvent("VOICE_CHAT_CHANNEL_MEMBER_SILENCED_CHANGED", "OnEvent")
end 
