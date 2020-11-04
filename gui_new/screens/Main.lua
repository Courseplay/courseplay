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

GuiManager.guiClass.main = CpGuiMain

GuiManager.BUTTONS = {}
GuiManager.BUTTONS.STARTSTOP = "startstop"
GuiManager.BUTTONS.KURSMANAGER = "kursmanager"
GuiManager.BUTTONS.ABFAHRER = "abfahrer"
GuiManager.BUTTONS.FILLSETTINGS = "fillsettings"
GuiManager.BUTTONS.DRESCHER = "drescher"
GuiManager.BUTTONS.TEMPO = "tempo"
GuiManager.BUTTONS.VEHICLESETTINGS = "vehiclesettings"
GuiManager.BUTTONS.FIELDSETTINGS = "fieldsettings"
--GuiManager.BUTTONS.FRONTLADER = "frontlader"
--GuiManager.BUTTONS.SILO = "silo"
GuiManager.BUTTONS.SETTINGS = "settings"

function CpGuiMain:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiMain._mt
    end
    local self = setmetatable({}, custom_mt)
	
    self.dialogPosition = {0, 0}

	return self
end

function CpGuiMain:onCreate() 
    
    self.languages = {}
    self.languages[GuiManager.BUTTONS.STARTSTOP] = courseplay:loc("COURSEPLAY_PAGE_TITLE_CP_CONTROL")
    self.languages[GuiManager.BUTTONS.KURSMANAGER] = courseplay:loc("COURSEPLAY_PAGE_TITLE_MANAGE_COURSES")
    self.languages[GuiManager.BUTTONS.ABFAHRER] = courseplay:loc("COURSEPLAY_PAGE_TITLE_COMBI_MODE")
    self.languages[GuiManager.BUTTONS.FILLSETTINGS] = courseplay:loc("COURSEPLAY_PAGE_TITLE_COMBI_MODE")
    self.languages[GuiManager.BUTTONS.DRESCHER] = courseplay:loc("COURSEPLAY_PAGE_TITLE_MANAGE_COMBINES")
    self.languages[GuiManager.BUTTONS.TEMPO] = courseplay:loc("COURSEPLAY_PAGE_TITLE_SPEEDS")
    self.languages[GuiManager.BUTTONS.VEHICLESETTINGS] = courseplay:loc("COURSEPLAY_PAGE_TITLE_DRIVING_SETTINGS")
    self.languages[GuiManager.BUTTONS.FIELDSETTINGS] = courseplay:loc("COURSEPLAY_MODESPECIFIC_SETTINGS")
    self.languages[GuiManager.BUTTONS.SETTINGS] = courseplay:loc("COURSEPLAY_PAGE_TITLE_GENERAL_SETTINGS")    
end

function CpGuiMain:onOpen() 
    self.gui_dialog.position = self.dialogPosition

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

function CpGuiMain:setData(site)
    
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

    
function CpGuiMain:onEnableHelp(button, para)
    self.gui_helpText:setText(self.languages[para])        
end

function CpGuiMain:onDisableHelp(button, para)
    self.gui_helpText:setText("")    
end






function CpGuiMain:onOpenCourseManager()
    courseplay.guiManager:openGui("cp_courseManager")
end

function CpGuiMain:onOpenSettings()
    --courseplay.guiManager:openGui("cp_settings")
end


