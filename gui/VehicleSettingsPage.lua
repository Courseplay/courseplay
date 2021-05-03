---@class VehicleSettingsPage
VehicleSettingsPage = {};

local VehicleSettingsPage_mt = Class(VehicleSettingsPage, TabbedMenuFrameElement);

VehicleSettingsPage.CONTROLS = {
	CONTAINER = "container"
}

function VehicleSettingsPage:new(target, mt)
	local self = TabbedMenuFrameElement:new(target, VehicleSettingsPage_mt);
	self.returnScreenName = "";
	self:registerControls(VehicleSettingsPage.CONTROLS)
	return self;
end

function VehicleSettingsPage:onFrameOpen()
	VehicleSettingsPage:superClass().onFrameOpen(self);
	FocusManager:setFocus(self.backButton);
	self:updateMyGUISettings();
	self.callBackParent.activePageID = self.callBackParentWithID;
end;

function VehicleSettingsPage:onFrameClose()
	VehicleSettingsPage:superClass().onFrameClose(self);
end;

function VehicleSettingsPage:getSettings()	
	return g_currentMission.controlledVehicle.cp.settings
end

function VehicleSettingsPage:onCreateVehicleSettingsPage(element)
	CpGuiUtil.bindSetting(self:getSettings(), element, 'VehicleSettingsPage')
end;

function VehicleSettingsPage:copyAttributes(src)
	VehicleSettingsPage:superClass().copyAttributes(self, src)

	self.ui = src.ui
	self.i18n = src.i18n
end

function VehicleSettingsPage:initialize()
end

function VehicleSettingsPage:onClickOk()
	for _, setting in pairs(self:getSettings()) do
		if setting.getGuiElement and setting:getGuiElement() then
			setting:setToIx(setting:getGuiElement():getState())
		end
	end
end

function VehicleSettingsPage:onClickReset()
	for _, setting in pairs(self:getSettings()) do
		if setting.getGuiElement then
			setting:getGuiElement():setState(setting:getGuiElementState(), false)
		end
	end
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
	for _, setting in pairs(self:getSettings()) do
		if setting.getGuiElement and setting:getGuiElement() then
			setting:getGuiElement():setState(setting:getGuiElementState(), false)
		end
	end
end
