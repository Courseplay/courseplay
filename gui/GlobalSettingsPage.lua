---@class GlobalSettingsPage
GlobalSettingsPage = {};

local GlobalSettingsPage_mt = Class(GlobalSettingsPage, TabbedMenuFrameElement);

GlobalSettingsPage.CONTROLS = {
    CONTAINER = "container"
}

function GlobalSettingsPage:new(target)
	print("NEWGLOBALSETTINGS")
    local self = TabbedMenuFrameElement:new(target, GlobalSettingsPage_mt);
    self.returnScreenName = "";
	self.settings = courseplay.globalSettings
	print('over')
    self:registerControls(GlobalSettingsPage.CONTROLS)
    return self;	
end

function GlobalSettingsPage:onFrameOpen()
    GlobalSettingsPage:superClass().onFrameOpen(self);
    FocusManager:setFocus(self.backButton);
    self:updateMyGUISettings();
    self.callBackParent.activePageID = self.callBackParentWithID;
end;

function GlobalSettingsPage:onFrameClose()
    GlobalSettingsPage:superClass().onFrameClose(self);
end;

function GlobalSettingsPage:onCreateGlobalSettingsPage(element)
	---@type SettingList
    local setting = self.settings[element.name]
	if setting then
		setting:setGuiElement(element)
		element.labelElement.text = setting:getLabel()
		element.toolTipText = setting:getToolTip()
		element:setTexts(setting:getGuiElementTexts())
		element:setState(setting:getGuiElementState())
	else
		courseplay.info('GlobalSettingsPage: can\'t find setting %s', element.name)
	end
end;

function GlobalSettingsPage:copyAttributes(src) 
    GlobalSettingsPage:superClass().copyAttributes(self, src)

    self.ui = src.ui
    self.i18n = src.i18n
end

function GlobalSettingsPage:initialize()
end

function GlobalSettingsPage:onClickOk()
	for _, setting in pairs(self.settings) do
		setting:setToIx(setting:getGuiElement():getState())
	end
end

function GlobalSettingsPage:onClickReset()
	for _, setting in pairs(self.settings) do
		setting:getGuiElement():setState(setting:getGuiElementState(), false)
	end
end

--- Get the frame's main content element's screen size.
function GlobalSettingsPage:getMainElementSize()
    return self.container.size
end

--- Get the frame's main content element's screen position.
function GlobalSettingsPage:getMainElementPosition()
    return self.container.absPosition
end

function GlobalSettingsPage:updateToolTipBoxVisibility(box)
    local hasText = box.text ~= nil and box.text ~= ""
    box:setVisible(hasText)
end

function GlobalSettingsPage:updateMyGUISettings()
    for _, setting in pairs(self.settings) do
		setting:getGuiElement():setState(setting:getGuiElementState(), false)
    end
end
