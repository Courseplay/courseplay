
VehicleSettingsPage = {};

local VehicleSettingsPage_mt = Class(VehicleSettingsPage, TabbedMenuFrameElement);

VehicleSettingsPage.CONTROLS = {
    CONTAINER = "container"
}

function VehicleSettingsPage:new(target, custom_mt)
    local self = TabbedMenuFrameElement:new(target, VehicleSettingsPage_mt);
    self.returnScreenName = "";
    self.settingElements = {};
    self:registerControls(VehicleSettingsPage.CONTROLS)
    return self;	
end;

function VehicleSettingsPage:onFrameOpen()
    VehicleSettingsPage:superClass().onFrameOpen(self);
    FocusManager:setFocus(self.backButton);
    self:updateMyGUISettings();    
    self.callBackParent.activePageID = self.callBackParentWithID;
end;

function VehicleSettingsPage:onFrameClose()
    VehicleSettingsPage:superClass().onFrameClose(self);
end;

function VehicleSettingsPage:onCreateVehicleSettingsPage(element)
    self.settingElements[element.name] = element;
--[[    local setting = AutoDrive.settings[element.name];
	element.labelElement.text = g_i18n:getText(setting.text);
	element.toolTipText = g_i18n:getText(setting.tooltip);

    local labels = {};
    for i = 1, #setting.texts, 1 do
        if setting.translate == true then
            labels[i] = g_i18n:getText(setting.texts[i]);
        else 
            labels[i] = setting.texts[i];
        end;
    end;	
    element:setTexts(labels);]]
end;

function VehicleSettingsPage:copyAttributes(src) 
    VehicleSettingsPage:superClass().copyAttributes(self, src)

    self.ui = src.ui
    self.i18n = src.i18n
end

function VehicleSettingsPage:initialize()
end

--- Get the frame's main content element's screen size.
function VehicleSettingsPage:getMainElementSize()
    return self.container.size
end

--- Get the frame's main content element's screen position.
function VehicleSettingsPage:getMainElementPosition()
    return self.container.absPosition
end

function VehicleSettingsPage:updateToolTipBoxVisibility(box)
    local hasText = box.text ~= nil and box.text ~= ""
    box:setVisible(hasText)
end

function VehicleSettingsPage:updateMyGUISettings()
    for settingName, settingElement in pairs(self.settingElements) do
        if AutoDrive.settings[settingName] ~= nil then
            local setting = AutoDrive.settings[settingName];
            if setting ~= nil and setting.isVehicleSpecific and g_currentMission.controlledVehicle ~= nil then
                setting = g_currentMission.controlledVehicle.ad.settings[settingName];
            end;
            self:updateGUISettings(settingName, setting.current);
        end;
    end;
end;

function VehicleSettingsPage:updateGUISettings(settingName, index)
    self.settingElements[settingName]:setState(index, false);
end;