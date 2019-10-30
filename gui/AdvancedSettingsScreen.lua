
AdvancedSettingsScreen = {};

local AdvancedSettingsScreen_mt = Class(AdvancedSettingsScreen, TabbedMenu);

AdvancedSettingsScreen.CONTROLS = {"vehicleSettingsPage", "globalSettingsPage"}


function AdvancedSettingsScreen:new(target, custom_mt)
    local self = TabbedMenu:new(nil, AdvancedSettingsScreen_mt, g_messageCenter,  g_i18n, g_gui.inputManager);
    self.returnScreenName = "";
    self.settingElements = {};

    self:registerControls(AdvancedSettingsScreen.CONTROLS)

    self.activePageID = 1;
    return self;	
end

function AdvancedSettingsScreen:onGuiSetupFinished()
    AdvancedSettingsScreen:superClass().onGuiSetupFinished(self)

    self:setupPages()
end

function AdvancedSettingsScreen:onOpen()
    AdvancedSettingsScreen:superClass().onOpen(self)

    self.inputDisableTime = 200
end

function AdvancedSettingsScreen:setupPages()
    local alwaysVisiblePredicate = self:makeIsAlwaysVisiblePredicate()

    local orderedPages = {
        { self.vehicleSettingsPage, alwaysVisiblePredicate, g_baseUIFilename, AdvancedSettingsScreen.TAB_UV.SETTINGS_VEHICLE, "vehicleSettingsPage" },
        { self.globalSettingsPage, alwaysVisiblePredicate, g_baseUIFilename, AdvancedSettingsScreen.TAB_UV.SETTINGS_GLOBAL, "GlobalSettingsPage" },
    }

    for i, pageDef in ipairs(orderedPages) do
        local page, predicate, uiFilename, iconUVs, name = unpack(pageDef)
        self:registerPage(page, i, predicate)

        page.callBackParent = self;
        page.callBackParentWithID = i;

        local normalizedUVs = getNormalizedUVs(iconUVs)
        self:addPageTab(page, uiFilename, normalizedUVs) -- use the global here because the value changes with resolution settings
    end
end

function AdvancedSettingsScreen:makeIsAlwaysVisiblePredicate()
    return function()
        return true
    end
end

--- Page tab UV coordinates for display elements.
AdvancedSettingsScreen.TAB_UV = {
    SETTINGS_VEHICLE = { 0, 209, 65, 65 },
	SETTINGS_GLOBAL = { 390, 148, 65, 65 },
}

function AdvancedSettingsScreen:onCreateAdvancedSettingsScreenGuiHeader(element)
	element.text = g_i18n:getText('gui_ad_Setting');
end

--- Define default properties and retrieval collections for menu buttons.
function AdvancedSettingsScreen:setupMenuButtonInfo()
	local onButtonBackFunction = self.clickBackCallback

	self.defaultMenuButtonInfo = {
		{ inputAction = InputAction.MENU_BACK, text = self.l10n:getText("button_back"), callback = onButtonBackFunction, showWhenPaused = true },
		{ inputAction = InputAction.MENU_ACCEPT, text = self.l10n:getText("button_ok"), callback = self.onClickOk, showWhenPaused = true},
		{ inputAction = InputAction.MENU_CANCEL, text = self.l10n:getText("button_reset"), callback = self.onClickReset, showWhenPaused = true }
	}

end

function AdvancedSettingsScreen:onClickBack()
    AdvancedSettingsScreen:superClass().onClickBack(self);
end

function AdvancedSettingsScreen:onClickOk()
    local page = self:getActivePage()
    if page == nil then
        return;
    end

	page:onClickOk()

    self:onClickBack();
end

function AdvancedSettingsScreen:onClickReset()
	local page = self:getActivePage()
	if page == nil then
		return;
	end

	page:onClickReset()
end

function AdvancedSettingsScreen:getActivePage()
    return self[AdvancedSettingsScreen.CONTROLS[self.activePageID]];
end

-- It is ugly to have a courseplay member function in this file but the current HUD implementations seems to be able to
-- use callbacks only if they are in the courseplay class.
function courseplay:openAdvancedSettingsDialog( vehicle )
	--- Prevent Dialog from locking up mouse and keyboard when closing it.
	self:lockContext(false);
	-- force reload screen so changes in XML do not require the entire game to be restarted, just reselect the screen
	g_AdvancedSettingsGui = nil

	if g_AdvancedSettingsGui == nil then
		g_gui:loadProfiles( self.path .. "gui/guiProfiles.xml" )
		g_AdvancedSettingsGui = {}
		g_AdvancedSettingsGui.globalSettingsPage = GlobalSettingsPage:new()
		g_gui:loadGui( self.path .. "gui/GlobalSettingsPage.xml", "GlobalSettingsFrame", g_AdvancedSettingsGui.globalSettingsPage, true)
		g_AdvancedSettingsGui.vehicleSettingsPage = VehicleSettingsPage:new()
		g_gui:loadGui( self.path .. "gui/VehicleSettingsPage.xml", "VehicleSettingsFrame", g_AdvancedSettingsGui.vehicleSettingsPage, true)
		g_AdvancedSettingsGui.mainScreen = AdvancedSettingsScreen:new()
		g_gui:loadGui( self.path .. "gui/AdvancedSettingsScreen.xml", "AdvancedSettingsScreen", g_AdvancedSettingsGui.mainScreen)
	end
	g_gui:showGui( 'AdvancedSettingsScreen' )
end