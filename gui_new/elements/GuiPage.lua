CpGuiPage = {}

-- 
-- CoursePlay - Gui - Text
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

CpGuiPage = {}
local CpGuiPage_mt = Class(CpGuiPage, CpGuiElement)

function CpGuiPage:new(gui, mainGui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPage_mt
    end
	
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "guiPage"
    self.gui = gui
    self.mainGui = mainGui
    gui.guiPage = self
	
	return self
end

function CpGuiPage:loadTemplate(templateName, xmlFile, key)
	CpGuiPage:superClass().loadTemplate(self, templateName, xmlFile, key)
    
    if xmlFile ~= nil then
        local guiClassName = getXMLString(xmlFile, string.format("%s#gui", key))
        local pageId = getXMLString(xmlFile, string.format("%s#pageId", key))
        local buttonId = getXMLString(xmlFile, string.format("%s#buttonId", key))
        
        if self.gui.pageFunctions ~= nil then
            local guiClass = _G[guiClassName]
            self.gui.pageFunctions:registerPage(pageId, guiClass, buttonId, self)
        else
            print("Do not implement pageFunctions")
        end
    end

	self:loadOnCreate()
end

function CpGuiPage:copy(src)
	CpGuiPage:superClass().copy(self, src)
	
	self:copyOnCreate()
end

function CpGuiPage:delete()
	CpGuiPage:superClass().delete(self)
end

function CpGuiPage:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	CpGuiPage:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function CpGuiPage:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	CpGuiPage:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiPage:update(dt)
	CpGuiPage:superClass().update(self, dt)
end

function CpGuiPage:draw(index)
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)

	CpGuiPage:superClass().draw(self)
end

function CpGuiPage:onOpen()
	if self.callback_onOpen ~= nil then
		self.gui[self.callback_onOpen](self.gui, self, self.parameter)
	end
	CpGuiPage:superClass().onOpen(self)
end



CpGuiPageFunctions = {}
local CpGuiPageFunctions_mt = Class(CpGuiPageFunctions)

function CpGuiPageFunctions:new(gui, custom_mt)
    if custom_mt == nil then
        custom_mt = CpGuiPageFunctions_mt
    end
	local self = setmetatable({}, custom_mt)
        
    self.gui = gui

    self.pages = {}
    self.pagesById = {}

	return self
end

function CpGuiPageFunctions:registerPage(id, class, buttonId, parentElement)
    if self.pagesById[id] ~= nil then
		print(string.format("Page id %s already exist.", id))
		return
	end

    local page = {}
    page.id = id
    page.buttonId = buttonId
    page.classGui = class:new(self.gui)    

    local xmlFile = loadXMLFile("Temp", page.classGui.xmlFilename)
    parentElement.mainGui:loadFromXMLRec(xmlFile, "GUI", parentElement, page.classGui)    
    page.guiElement = parentElement.elements[#parentElement.elements]

    table.insert(self.pages, page)
    self.pagesById[page.id] = page
end

function CpGuiPageFunctions:setPage(pageIndex)
    for id,page in pairs(self.pages) do
        page.guiElement:setVisible(id == pageIndex)
        self.gui[page.buttonId]:setActive(id == pageIndex, false)
    end
end

function CpGuiPageFunctions:setPageByName(pageName)
    local pageId = 0
    local counter = 0
    for id,page in pairs(self.pages) do
        page.guiElement:setVisible(page.id == pageName)
        self.gui[page.buttonId]:setActive(page.id == pageName, false)

        if page.id == pageName then
            pageId = id
        end

        counter = counter + 1
    end
    return pageId
end