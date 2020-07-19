-- 
-- CoursePlay - Gui - PageSelector
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

CpGuiPageSelector = {}
CpGuiPageSelector._mt = Class(CpGuiPageSelector, CpGuiElement)


function CpGuiPageSelector:new(gui, custom_mt)	
	if custom_mt == nil then
        custom_mt = CpGuiPageSelector._mt
    end
	local self = CpGuiElement:new(gui, custom_mt)
	self.name = "pageSelector"
	
	self.skipFirstElement = true
	    
	return self
end

function CpGuiPageSelector:loadTemplate(templateName, xmlFile, key)
	CpGuiPageSelector:superClass().loadTemplate(self, templateName, xmlFile, key)

	if xmlFile ~= nil then
		self.currentPage = courseplay.guiManager:getTemplateValueXML(xmlFile, "pageNameOnOpen", key, nil)
	end

	self:loadOnCreate()
end


function CpGuiPageSelector:copy(src)
	CpGuiPageSelector:superClass().copy(self, src)

	self:copyOnCreate()
end

function CpGuiPageSelector:delete()
	CpGuiPageSelector:superClass().delete(self)
end

function CpGuiPageSelector:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	return CpGuiPageSelector:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function CpGuiPageSelector:keyEvent(unicode, sym, modifier, isDown, eventUsed)
	CpGuiPageSelector:superClass().keyEvent(self, unicode, sym, modifier, isDown, eventUsed)
end

function CpGuiPageSelector:update(dt)
	CpGuiPageSelector:superClass().update(self, dt)	
end

function CpGuiPageSelector:draw(index)
	self.drawPosition[1], self.drawPosition[2] = courseplay.guiManager:calcDrawPos(self, index)	
		
	CpGuiPageSelector:superClass().draw(self)
end

function CpGuiPageSelector:onOpen()
	CpGuiPageSelector:superClass().onOpen(self)
	if self.currentPage == nil then
		self:openPage(self:findFirstPageName())
	else
		self:openPage(self.currentPage)
	end
end

function CpGuiPageSelector:findFirstPageName()
	if self.currentPage == nil then
		local skipFirstElement = self.skipFirstElement
		for _, page in pairs(self.elements) do
			if skipFirstElement then
				skipFirstElement = false
			else
				return page.pageName
			end
		end
	end
end

function CpGuiPageSelector:openPage(pageName)
	local skipFirstElement = self.skipFirstElement
	local activePageIndx = -1
	for k, page in pairs(self.elements) do
		if skipFirstElement then
			skipFirstElement = false			
		else
			if page.pageName == pageName then
				page:setVisible(true)
				self.currentPage = page.pageName
				activePageIndx = k - 1
				self.gui:setPage(page)
			else
				page:setVisible(false)
			end
		end
	end
	
	if self.skipFirstElement then
		for _,buttons in pairs(self.elements) do
			for k, button in pairs(buttons.elements) do
				button:setSelected(k == activePageIndx)
			end
			break
		end
	end
end