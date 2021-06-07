-- 
-- CoursePlay - Gui - Main
-- 
-- @Interface: 1.6.0.0 b9166
-- @Author: LS-Modcompany / kevink98
-- @Date: 19.07.2020
-- @Version: 1.0.0.0
-- 
-- @Changelog:
--		
-- 	v1.0.0.0 (kevink98):
-- 		- initial fs19
-- 
-- Notes:
-- 
-- 
-- ToDo:
--
--

CpGuiMain = {}
CpGuiMain.xmlFilename = courseplay.path .. "gui_new/screens/Main.xml"

CpGuiMain._mt = Class(CpGuiMain)

CpGuiMain.selectedMode = 5
CpGuiMain.defaultMode = 5
CpGuiMain.defaultPage = "steering"

GuiManager.guiClass.main = CpGuiMain

GuiManager.BUTTONS = {}
GuiManager.BUTTONS.STEERING = "steering"
GuiManager.BUTTONS.COURSEMANAGER = "courseManager"
GuiManager.BUTTONS.DRIVERS = "drivers"
GuiManager.BUTTONS.DRIVERSSEARCH = "driversSearch"
GuiManager.BUTTONS.SETTINGS = "settings"

--GuiManager.BUTTONS.TEMPO = "tempo"
--GuiManager.BUTTONS.SETTINGSVEHICLE = "vehiclesettings"
--GuiManager.BUTTONS.SETTINGSFIELDS = "settingsFields"
--GuiManager.BUTTONS.FRONTLADER = "frontlader"
--GuiManager.BUTTONS.SILO = "silo"
GuiManager.BUTTONS.SETTINGS = "settings"

function CpGuiMain:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiMain._mt
    end
    local self = setmetatable({}, custom_mt)
	
    self.dialogPosition = {0, 0}

    self.pageFunctions = CpGuiPageFunctions:new(self)
    self.lastPageIndex = self.defaultPage

	return self
end

function CpGuiMain:onLoad(xmlFile, baseKey)
    self:loadDisabledPagesByModes(xmlFile,baseKey)
end

function CpGuiMain:loadDisabledPagesByModes(xmlFile,baseKey)
    self.disabledPagesByModes = {}
    
    local baseKey = string.format("%s.DisabledPagesByModes",baseKey)
    local i = 0
    while true do 
        local key = string.format("%s.DisabledPageByModes(%d)",baseKey,i)
        if not hasXMLProperty(xmlFile, key) then
			break
		end
        local pageName = getXMLString(xmlFile,string.format("%s#name", key))
        local disabledModesStr = getXMLString(xmlFile,string.format("%s#value", key))
        self.disabledPagesByModes[pageName] = {StringUtil.getVectorFromString(disabledModesStr)}
        i = i + 1
    end
end

function CpGuiMain:onCreate() 
    --- TODO: moves this to guiTemplate btn toolTips. The same as "cpMainCategorie_Steering"! 
    self.languages = {}
    self.languages[GuiManager.BUTTONS.STEERING] = courseplay:loc("COURSEPLAY_PAGE_TITLE_CP_CONTROL")
    self.languages[GuiManager.BUTTONS.COURSEMANAGER] = courseplay:loc("COURSEPLAY_PAGE_TITLE_MANAGE_COURSES")
    self.languages[GuiManager.BUTTONS.DRIVERS] = courseplay:loc("COURSEPLAY_PAGE_TITLE_COMBI_MODE")
    --self.languages[GuiManager.BUTTONS.FILLSETTINGS] = courseplay:loc("COURSEPLAY_PAGE_TITLE_COMBI_MODE")
    self.languages[GuiManager.BUTTONS.DRIVERSSEARCH] = courseplay:loc("COURSEPLAY_PAGE_TITLE_MANAGE_COMBINES")
    --self.languages[GuiManager.BUTTONS.TEMPO] = courseplay:loc("COURSEPLAY_PAGE_TITLE_SPEEDS")
    --self.languages[GuiManager.BUTTONS.VEHICLESETTINGS] = courseplay:loc("COURSEPLAY_PAGE_TITLE_DRIVING_SETTINGS")
    --self.languages[GuiManager.BUTTONS.FIELDSETTINGS] = courseplay:loc("COURSEPLAY_MODESPECIFIC_SETTINGS")
    self.languages[GuiManager.BUTTONS.SETTINGS] = courseplay:loc("COURSEPLAY_PAGE_TITLE_GENERAL_SETTINGS")    
end

function CpGuiMain:onOpen() 
    self.gui_dialog.position = self.dialogPosition
    self.pageFunctions:setPageByName(self.lastPageIndex)
    CpGuiMain.getModeButton(self,self.selectedMode):setActive(true)
end

function CpGuiMain:onClose() 
    
end


function CpGuiMain:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    
end

function CpGuiMain:keyEvent(unicode, sym, modifier, isDown, eventUsed)
   
end

function CpGuiMain:update(dt)
	
end

function CpGuiMain:draw()
	
end

function CpGuiMain:setData(vehicle)
    self.vehicle = vehicle

    for _,page in pairs(self.pageFunctions.pages) do
        if page.classGui.setVehicle ~= nil then
            page.classGui:setVehicle(vehicle)
        end
    end
    CpGuiMain.validateModeButtons(self.vehicle)
end

function CpGuiMain:setGuiMoverValues(target, pos)
    if target == "gui_dialog" then
        self.dialogPosition = pos
    end
end


function CpGuiMain:saveXmlSettings(xml, key)    
    setXMLFloat(xml, key .. '.main#posX', self.dialogPosition[1])
    setXMLFloat(xml, key .. '.main#posY', self.dialogPosition[2])
end

function CpGuiMain:loadXmlSettings(xml, key)    
    if hasXMLProperty(xml, key .. '.main#posX') then
        self.dialogPosition[1] = getXMLFloat(xml, key .. '.main#posX')
        self.dialogPosition[2] = getXMLFloat(xml, key .. '.main#posY')
    end
end



function CpGuiMain:onClose()
    courseplay.guiManager:onCloseCpMainGui()
end

--- Displays button toolTip.
function CpGuiMain:onEnableHelp(button, para)
    if button.toolTip ~="" then
        self.gui_helpText:setText(courseplay:loc(button.toolTip),true)
    else 
        self.gui_helpText:setText(string.format("Missing text for %s!", para), true)
    end
end

--- Resets button toolTip.
function CpGuiMain:onDisableHelp(button, para)
    self.gui_helpText:setText("")
end

function CpGuiMain:onOpenCourseManager()
    courseplay.guiManager:openGui("cp_courseManager")
end

function CpGuiMain:onOpenSettings()
    self:onClose()
    courseplay:openAdvancedSettingsDialog(self.vehicle)
    --courseplay.guiManager:openGui("cp_settings")
end

function CpGuiMain:onClickOpenPage(btn, site)
    self.lastPageIndex = self.pageFunctions:setPageByName(site)
end

function CpGuiMain:resetPageToDefault()
    self.lastPageIndex = self.pageFunctions:setPageByName(self.defaultMode)
end

function CpGuiMain:onClickSelectMode(btn,mode)
    mode = tonumber(mode)
    if mode ~= self.selectedMode then 
        CpGuiMain.getModeButton(self, self.selectedMode):setActive(false)
        CpGuiMain.getModeButton(self, mode):setActive(true)
        self.selectedMode = mode
        self:validatePageButtons()
        self:resetPageToDefault()
    end
end

--- TODO: moves this into a setting: DriverModeSetting!

--- Updates the mode button availability on: opening of the hud or attach/detach of an implement.
function CpGuiMain.validateModeButtons(vehicle)
    local mainCpGui = courseplay.guiManager.mainCpGui
    if not mainCpGui then 
        return
    end
    for i=1,courseplay.NUM_MODES do 
        --- Is the mode valid ?
        local valid = courseplay:getIsToolCombiValidForCpMode(vehicle,i)
        local btn = CpGuiMain.getModeButton(mainCpGui,i)
    --    courseplay.guiManager.mainCpGui[buttonKey]:setDisabled(not valid)
        btn:setDisabled(not valid)
        if mainCpGui.selectedMode == i then 
            --- Check if the current selectedMode still is valid, else switch to the default mode.
            if not valid then 
                btn:setActive(false)
                mainCpGui.selectedMode = mainCpGui.defaultMode
                CpGuiMain.getModeButton(mainCpGui, mainCpGui.defaultMode):setActive(true)
                --- Make sure the page button gets reset, as the page might not be valid for this mode.
                CpGuiMain.resetPageToDefault(mainCpGui)
            end
        end
    end
    CpGuiMain.validatePageButtons(mainCpGui)
end

function CpGuiMain.getModeButton(mainCpGui,i)
    local buttonKey = string.format("mode%d",i) 
    return courseplay.guiManager.mainCpGui[buttonKey]
end

function CpGuiMain:validatePageButtons()
    for _,page in pairs(self.pageFunctions.pages) do
        local disabled = self:isPageForModeDisabled(page)
        self[page.buttonId]:setVisible(not disabled)
    end
end

function CpGuiMain:isPageForModeDisabled(page)
    for _,mode in pairs(self.disabledPagesByModes[page.id]) do 
        if mode and mode == self.selectedMode then 
            return true
        end
    end
end


