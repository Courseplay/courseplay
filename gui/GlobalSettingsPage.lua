
-- This and VehicleSettingsPage has everything common except the list of settings. I tried to derive them
-- from a common SettingsPage class but I believe that this does not work due to the way the Giant's GUI
-- framework works.

---@class GlobalSettingsPage
GlobalSettingsPage = {};

local GlobalSettingsPage_mt = Class(GlobalSettingsPage, TabbedMenuFrameElement);

GlobalSettingsPage.CONTROLS = {
    CONTAINER = "container"
}

function GlobalSettingsPage:new(target, mt)
   local self = TabbedMenuFrameElement:new(target, GlobalSettingsPage_mt);
    self.returnScreenName = "";
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
	CpGuiUtil.bindSetting(courseplay.globalSettings, element, 'GlobalSettingsPage')
end;

function GlobalSettingsPage:copyAttributes(src) 
    GlobalSettingsPage:superClass().copyAttributes(self, src)

    self.ui = src.ui
    self.i18n = src.i18n
end

function GlobalSettingsPage:initialize()
end

function GlobalSettingsPage:onClickOk()
	for _, setting in pairs(courseplay.globalSettings) do
		if setting.getGuiElement and setting:hasGuiElement() then 
			setting:setToIx(setting:getGuiElement():getState())
		end
	end
end

function GlobalSettingsPage:onClickReset()
	for _, setting in pairs(courseplay.globalSettings) do
		if setting.getGuiElement and setting:hasGuiElement() then 
			setting:getGuiElement():setState(setting:getGuiElementState(), false)
		end
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
    for _, setting in pairs(courseplay.globalSettings) do
		if setting.getGuiElement and setting:hasGuiElement() then 
			local element = setting:getGuiElement()
			if element then 
				local state = setting:getGuiElementState()
				if state then 
					element:setState(state, false)
				else 
					courseplay.info('GlobalSettingsPage: can\'t find GUI element state for  %s', setting.name)
				end
			else 
				courseplay.info('GlobalSettingsPage: can\'t find GUI element for  %s', setting.name)
			end
		end
	end
end
