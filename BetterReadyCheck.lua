-----------------------------------------------------------------------------------------------
-- Client Lua Script for BetterReadyCheck
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- BetterReadyCheck Module Definition
-----------------------------------------------------------------------------------------------
local NAME = "BetterReadyCheck"

local BetterReadyCheck = Apollo.GetPackage("Gemini:Addon-1.1").tPackage:NewAddon(NAME, true, {}, "Gemini:Hook-1.0") 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local ktVersion = {nMajor = 1, nMinor = 0, nPatch = 0}

local ktDefaultSettings = {
	tVersion = {
		nMajor = ktVersion.nMajor,
		nMinor = ktVersion.nMinor,
		nPatch = ktVersion.nPatch
	},
	bReadyCheckSpamFix = true,
	bEnableReadyCheckSound = true,
	sReadyCheckSound = "PlayUIQueuePopsAdventure"
}

local ktGroupFrameAddons = {
	GroupFrame = "OnGroupMemberFlags", -- Carbine
	VikingGroupFrame = "OnGroupMemberFlags"
}
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function BetterReadyCheck:OnInitialize()
	self.settings = copyTable(ktDefaultSettings)
	
	self.xmlDoc = XmlDoc.CreateFromFile("BetterReadyCheck.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function BetterReadyCheck:OnDocLoaded()
	if self.xmlDoc == nil or not self.xmlDoc:IsLoaded() then
		Apollo.AddAddonErrorText(self, "XmlDoc not loaded.")
	end
	
	Apollo.RegisterEventHandler("Group_ReadyCheck",	"OnGroupReadyCheck", self)
	
	Apollo.RegisterSlashCommand("betterreadycheck", "OnSlashCommand", self)
	Apollo.RegisterSlashCommand("brc", "OnSlashCommand", self)
	
	self.bGroupFrameHooked = self:InstallGroupFrameHook()
end

function BetterReadyCheck:OnSave(eLevel)
	if (eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character) then
		return
	end
	
	self.settings.tVersion = copyTable(ktVersion)
	return self.settings
end

function BetterReadyCheck:OnRestore(eLevel, tData)
	if tData ~= nil then
		self.settings = mergeTables(self.settings, tData)
	end
end

function BetterReadyCheck:OnSlashCommand(sCommand, sParam)
	self:ToggleOptionsWindow()
end

function BetterReadyCheck:OnConfigure(sCommand, sArgs)
	self:ToggleOptionsWindow()
end

-----------------------------------------------------------------------------------------------
-- BetterReadyCheck Functions
-----------------------------------------------------------------------------------------------
function BetterReadyCheck:OnGroupReadyCheck(nMemberIdx, sMessage)
	if self.settings.bEnableReadyCheckSound == true then
		Sound.Play(Sound[self.settings.sReadyCheckSound])
	end
end

-----------------------------------------------------------------------------------------------
-- Hook Functions
-----------------------------------------------------------------------------------------------
function BetterReadyCheck:InstallGroupFrameHook()
	local tGroupFrame, func
	for addonName, funcName in pairs(ktGroupFrameAddons) do
		tGroupFrame = Apollo.GetAddon(addonName)
		
		if tGroupFrame ~= nil then
			func = funcName
			break
		end
	end
	
	if tGroupFrame == nil then
		return false
	end
	self.tGroupFrame = tGroupFrame;
	
	self:RawHook(tGroupFrame, func, "Hook_OnGroupMemberFlags")
	
	return true
end

function BetterReadyCheck:Hook_OnGroupMemberFlags(luaCaller, nMemberIdx, bIsFromPromotion, tChangedFlags)
	-- This ensure that tChangedFlags.bReady is never set, so that it can never get to the state that it spams
	if self.settings.bReadyCheckSpamFix == true and tChangedFlags ~= nil and tChangedFlags.bReady == true then
		tChangedFlags.bReady = nil
	end
	
	-- Call the original one
	self.hooks[self.tGroupFrame].OnGroupMemberFlags(luaCaller, nMemberIdx, bIsFromPromotion, tChangedFlags)
end

-----------------------------------------------------------------------------------------------
-- Options Functions
-----------------------------------------------------------------------------------------------
function BetterReadyCheck:ToggleOptionsWindow()
	self.bOptionsOpen = not self.bOptionsOpen
	
	if not self.wndOptions then
		if not self.xmlDocoptions then
			self.xmlDocOptions = XmlDoc.CreateFromFile("Options.xml")
		end
		self.wndOptions = Apollo.LoadForm(self.xmlDocOptions, "OptionsForm", nil, self)
		self.wndOptionsList = Apollo.LoadForm(self.xmlDocOptions, "OptionsList", self.wndOptions:FindChild("ContentFrame"), self)
	end
	
	if self.bOptionsOpen then
		self:SetOptionValues()
		self.wndOptions:ToFront()
		local nScreenWidth, nScreenHeight = Apollo.GetScreenSize()
		local nLeft, nTop, nRight, nBottom = self.wndOptions:GetRect()
		local nWidth, nHeight = nRight - nLeft, nBottom - nTop
		
		if self.settings.tOptionsWindowPos and self.settings.tOptionsWindowPos[1] then
			self.wndOptions:Move(round(nScreenWidth * self.settings.tOptionsWindowPos[1]), round(nScreenHeight * self.settings.tOptionsWindowPos[2]), nWidth, nHeight)
		else
			self.wndOptions:Move(round((nScreenWidth / 2) - (nWidth / 2)), round((nScreenHeight / 2) - (nHeight / 2)), nWidth, nHeight)
		end
	end
	self.wndOptions:Show(self.bOptionsOpen, false)
end

function BetterReadyCheck:OnOptionsWindowClosed(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	self:ToggleOptionsWindow()
end

function BetterReadyCheck:OnOptionsWindowHide(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	if self.wndOptions then
		self.wndOptionsList:Destroy()
		self.wndOptionsList = nil
		self.wndOptions:Destroy()
		self.wndOptions = nil
	end
end

function BetterReadyCheck:OnOptionsWindowMove(wndHandler, wndControl, nOldLeft, nOldTop, nOldRight, nOldBottom)
	local nScreenWidth, nScreenHeight = Apollo.GetScreenSize()
	local nPosLeft, nPosTop = self.wndOptions:GetPos()
	self.settings.tOptionsWindowPos = {}
	self.settings.tOptionsWindowPos[1], self.settings.tOptionsWindowPos[2] = nPosLeft / nScreenWidth, nPosTop / nScreenHeight
end

function BetterReadyCheck:SetOptionValues()
	self.wndOptionsList:FindChild("ReadySpamFix"):FindChild("EnableButton"):SetCheck(self.bGroupFrameHooked and self.settings.bReadyCheckSpamFix)
	self.wndOptionsList:FindChild("ReadySpamFix"):FindChild("Mask"):Show(not self.bGroupFrameHooked)
	self.wndOptionsList:FindChild("ReadyCheckSoundEnable"):FindChild("EnableButton"):SetCheck(self.settings.bEnableReadyCheckSound)
	self.wndOptionsList:FindChild("ReadyCheckSound"):FindChild("DropdownButton"):SetText(self.settings.sReadyCheckSound)
	self.wndOptionsList:FindChild("ReadyCheckSound"):FindChild("PreviewButton"):SetData(self.settings.sReadyCheckSound)
	local soundListContainer = self.wndOptionsList:FindChild("ReadyCheckSound"):FindChild("DropdownContainer"):FindChild("ListContainer")
	soundListContainer:GetParent():SetData(self.SetSoundItemControl)
	for sSoundName, nSoundId in pairs(Sound) do
		if type(nSoundId) == "number" then
			local listItem = Apollo.LoadForm(self.xmlDocOptions, "SoundListItem", soundListContainer, self)
			listItem:SetData(sSoundName)
			listItem:FindChild("Label"):SetText(sSoundName)
			listItem:FindChild("PreviewButton"):SetData(sSoundName)
		end
	end
	soundListContainer:ArrangeChildrenVert()
	soundListContainer:EnsureChildVisible(true)
end

function BetterReadyCheck:OnReadySpamFixClick(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl then
		return
	end
	
	self.settings.bReadyCheckSpamFix = wndHandler:IsChecked()
end

function BetterReadyCheck:OnReacyCheckSoundEnableClick(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl then
		return
	end
	
	self.settings.bEnableReadyCheckSound = wndHandler:IsChecked()
end

function BetterReadyCheck:OnSoundDropdownClick(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl then
		return
	end
	
	wndHandler:GetParent():FindChild("DropdownContainer"):Show(wndHandler:IsChecked())
end

function BetterReadyCheck:OnDropdownShow(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	local wndButton = wndControl:GetParent():FindChild("DropdownButton")
	wndButton:SetCheck(true)
	wndButton:FindChild("DropdownArrow"):SetRotation(180)
	
	self.wndOptionsList:SetStyle("Escapable", false)
end

function BetterReadyCheck:OnDropdownHide(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	local wndButton = wndControl:GetParent():FindChild("DropdownButton")
	wndButton:SetCheck(false)
	wndButton:FindChild("DropdownArrow"):SetRotation(0)
	wndHandler:GetData()(self)
	
	self.wndOptionsList:SetStyle("Escapable", true)
end

function BetterReadyCheck:OnDropdownMouseEnter(wndHandler)
	wndHandler:GetParent():FindChild("DropdownContainer"):SetStyle("CloseOnExternalClick", false)
end

function BetterReadyCheck:OnDropdownMouseExit(wndHandler)
	wndHandler:GetParent():FindChild("DropdownContainer"):SetStyle("CloseOnExternalClick", true)
end

function BetterReadyCheck:SetSoundItemControl()
	self.wndOptionsList:FindChild("ReadyCheckSound"):FindChild("DropdownButton"):SetText(self.settings.sReadyCheckSound)
	self.wndOptionsList:FindChild("ReadyCheckSound"):FindChild("Selector:PreviewButton"):SetData(self.settings.sReadyCheckSound)
end

function BetterReadyCheck:OnSoundListItemSelect(wndHandler, wndControl, eMouseButton)
	if wndHandler ~= wndControl then
		return
	end
	
	local wndDropdown = wndHandler:GetParent():GetParent()
	self.settings.sReadyCheckSound = wndHandler:FindChild("Label"):GetText()
	
	wndDropdown:Close()
end

function BetterReadyCheck:OnPreviewSoundClick(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	local sSoundName = wndHandler:GetData()
	if sSoundName == nil then
		sSoundName = wndHandler:GetParent():GetData()
	end

	Sound.Play(Sound[sSoundName])
end

function BetterReadyCheck:OnReloadBtnClick(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	RequestReloadUI()
end

function BetterReadyCheck:OnResetBtnClick(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end
	
	self.settings = copyTable(ktDefaultSettings)
	RequestReloadUI()
end

-----------------------------------------------------------------------------------------------
-- Helper Functions
-----------------------------------------------------------------------------------------------
function copyTable(orig)
	local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[copyTable(orig_key)] = copyTable(orig_value)
        end
        setmetatable(copy, copyTable(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function mergeTables(t1, t2)
    for k, v in pairs(t2) do
    	if type(v) == "table" then
			if t1[k] then
	    		if type(t1[k] or false) == "table" then
	    			mergeTables(t1[k] or {}, t2[k] or {})
	    		else
	    			t1[k] = v
	    		end
			else
				t1[k] = {}
    			mergeTables(t1[k] or {}, t2[k] or {})
			end
    	else
    		t1[k] = v
    	end
    end
    return t1
end
