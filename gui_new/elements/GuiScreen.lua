-- 
-- CoursePlay - Gui - Screen
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

CpGuiScreen = {}
CpGuiScreen._mt = Class(CpGuiScreen)

function CpGuiScreen:new(custom_mt)	
	if custom_mt == nil then
        custom_mt = CpGuiScreen._mt
    end
    local self = setmetatable({}, custom_mt)	
    
    self.texts = {}
    
	return self
end

function CpGuiScreen:onOpen()
    g_depthOfFieldManager:setBlurState(true)
end

function CpGuiScreen:onClose()
    g_depthOfFieldManager:setBlurState(false)
    
end

function CpGuiScreen:onCreate()
    self.gui_headerLocationSep_1:setVisible(false)
    self.gui_headerLocationSep_2:setVisible(false)
end

function CpGuiScreen:onClickClose()
	courseplay.guiManager:closeActiveGui()
end


-- function CpGuiScreen:setPage(num, text)
--     local goToPage = num or 1
--     if goToPage ~= self.currentPage and goToPage > 0 and goToPage < 4 then
--         self["gui_headerLocationText_" .. goToPage]:setText(text)
--         if self.currentPage ~= nil then
--             if goToPage > self.currentPage then
--                 self["gui_headerLocationSep_" .. goToPage]:setVisible(true)
--             end
--             if goToPage < self.currentPage then
--                 self["gui_headerLocationSep_" .. (goToPage + 1)]:setVisible(false)
--                 self["gui_headerLocationText_" .. (goToPage + 1)]:setText("")
--             end
--         end
--         self.currentPage = goToPage        
--     end
-- end

function CpGuiScreen:setPage(page)
    if page.parentPage == nil then
        self.gui_headerLocationText_1:setText(page.pageHeader)
    else

    end
end