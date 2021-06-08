-- 
-- CoursePlay - Gui - CourseManager
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

CpCourseManager = {}
CpCourseManager.xmlFilename = courseplay.path .. "gui_new/screens/CourseManager.xml"

CpCourseManager._mt = Class(CpCourseManager)

GuiManager.guiClass.courseManager = CpCourseManager

function CpCourseManager:new(target, custom_mt)
    if custom_mt == nil then
        custom_mt = CpCourseManager._mt
    end
    local self = setmetatable({}, custom_mt)
    
    self.dialogPosition = {0, 0}
    self.pdaPosition = {0, 0}
    self.pdaSize = {0, 0}
    self.pdaZoomFactor = 0
    

	return self
end

function CpCourseManager:onCreate() 
    
    
end

function CpCourseManager:onOpen() 
    g_depthOfFieldManager:setBlurState(true)
    self.gui_dialog.position = self.dialogPosition

    if self.pdaSize[1] ~= 0 then
        self.gui_ingameMap.size = self.pdaSize
        self.gui_ingameMap.overlayElement.size = self.pdaSize
    end
    if self.pdaPosition[0] ~= 0 then
        self.gui_ingameMap.position = self.pdaPosition
    end    
    if self.pdaZoomFactor ~= 0 then
        self.gui_ingameMap.zoomFactor = self.pdaZoomFactor
    end
end

function CpCourseManager:onClose() 
    g_depthOfFieldManager:setBlurState(false)
    courseplay.guiManager:openGui("cp_main")
    
end


function CpCourseManager:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
    
end

function CpCourseManager:keyEvent(unicode, sym, modifier, isDown, eventUsed)
   
end

function CpCourseManager:update(dt)
	
end

function CpCourseManager:draw()
	
end

function CpCourseManager:setData()
    
end

function CpCourseManager:setGuiValue(target, subTarget, val)
    if val == nil then return end
    if target == "gui_ingameMap" then
        if subTarget == "size" then
            self.pdaSize = val
        elseif subTarget == "zoomFactor" then
            self.pdaZoomFactor = val
        elseif subTarget == "position" then
            self.pdaPosition = val
        end
    end
end


function CpCourseManager:saveXmlSettings(xml, key)	--save PDA position too ?    
    setXMLFloat(xml, key .. '.courseManager#posX', self.dialogPosition[1])
    setXMLFloat(xml, key .. '.courseManager#posY', self.dialogPosition[2])
end

function CpCourseManager:loadXmlSettings(xml, key)    
    if hasXMLProperty(xml, key .. '.courseManager#posX') then  
        self.dialogPosition[1] = getXMLFloat(xml, key .. '.courseManager#posX')
        self.dialogPosition[2] = getXMLFloat(xml, key .. '.courseManager#posY')
    end
end
function CpCourseManager:raiseDirtyFlag()
    self.isDirty = true
end


