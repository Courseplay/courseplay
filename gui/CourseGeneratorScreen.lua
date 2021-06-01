
---@class CourseGeneratorScreen
CourseGeneratorScreen = {}

local CourseGeneratorScreen_mt = Class(CourseGeneratorScreen, ScreenElement)

CourseGeneratorScreen.SHOW_NOTHING = 0
CourseGeneratorScreen.SHOW_FULL_MAP = 1
CourseGeneratorScreen.SHOW_SELECTED_FIELD = 2

-- these are needed to be able to access those screen elements with self.<id>
CourseGeneratorScreen.CONTROLS = {
	fieldSelector = 'fieldSelector',
	startingLocation = 'startingLocation',
	rowDirection = 'rowDirection',
	manualRowAngle = 'manualRowAngle',
	workWidth = 'workWidth',
	autoWidth = 'autoWidth',
	islandBypassMode = 'islandBypassMode',
	headlandDirection = 'headlandDirection',
	headlandCornerType = 'headlandCornerType',
	headlandOverlapPercent = 'headlandOverlapPercent',
	headlandPasses = 'headlandPasses',
	startOnHeadland = 'startOnHeadland',
	numberOfRowsPerLand = 'numberOfRowsPerLand',
	ingameMap = 'ingameMap',
	mapCursor = 'mapCursor'
}

function CourseGeneratorScreen:new(vehicle)
	local self = ScreenElement:new(nil, CourseGeneratorScreen_mt)
	-- needed for onClickBack to work.
	self.returnScreenName = "";
	self.state = CourseGeneratorScreen.SHOW_NOTHING
	self.vehicle = vehicle
	self.settings = vehicle.cp.courseGeneratorSettings
	self.directions = {}
	-- map to look up gui element state from angle
	self.directionToState = {}
	local i = 1
	-- manual direction settings
	for gameAngleDeg = 0, 180, 5 do
		table.insert( self.directions, { compassAngleDeg = courseGenerator.getCompassAngleDeg( gameAngleDeg ), gameAngleDeg = gameAngleDeg })
		self.directionToState[ gameAngleDeg ] = i
		i = i + 1
	end
	self.zoomStep = 1
	self:registerControls(CourseGeneratorScreen.CONTROLS)
	return self
end

function CourseGeneratorScreen:setVehicle( vehicle )
	self.vehicle = vehicle
end

--- function to override the standard icon sizes so map symbols like field numbers don't look too big
-- when the maximum zoom level is higher than the standard one.
function CourseGeneratorScreen:updateMap()
	self.ingameMap.iconZoom = 0.3 + (self.zoomMax / 2 - self.zoomMin) * self.mapZoom
end

function CourseGeneratorScreen:showCourse()
	if self.vehicle.Waypoints and #self.vehicle.Waypoints > 0 and self.coursePlot then
		self.coursePlot:setWaypoints( self.vehicle.Waypoints )
		self.coursePlot:setStartPosition(self.vehicle.Waypoints[1].cx, self.vehicle.Waypoints[1].cz)
		self.coursePlot:setStopPosition(self.vehicle.Waypoints[#self.vehicle.Waypoints].cx, self.vehicle.Waypoints[#self.vehicle.Waypoints].cz)
	end
end

function CourseGeneratorScreen:onCreate()
	self.ingameMap:setIngameMap(g_currentMission.hud.ingameMap)
	-- fix icon sizes at higher zoom level
	self.ingameMap.updateMap = Utils.appendedFunction(self.ingameMap.updateMap, self.updateMap)
	self.ingameMap:registerActionEvents()
	self.ingameMap:setTerrainSize(g_currentMission.terrainSize)
	self.ingameMap.mapCenterX = -0.15
	self.ingameMap.mapCenterY = 0
	self.ingameMap.zoomMax = 4
	self.ingameMap.mapZoom = 0.6
	self.ingameMap:zoom(0)
end

-- bind GUI elements to settings
function CourseGeneratorScreen:onCreateElement(element)
	CpGuiUtil.bindSetting(self.settings, element, 'CourseGeneratorScreen')
end

function CourseGeneratorScreen:onOpen()

	g_currentMission.isPlayerFrozen = true

	self.settings.selectedField:refresh()
	-- work width not set
	if self.settings.workWidth:is(0) then
		self.settings.workWidth:setToDefault()
	end

	CourseGeneratorScreen:superClass().onOpen(self)
	if not self.coursePlot then
			self.coursePlot = CoursePlot:new(
				self.ingameMap.absPosition[ 1 ], self.ingameMap.absPosition[ 2 ],
				self.ingameMap.size[1], self.ingameMap.size[2],
				g_currentMission.terrainSize)
			self.coursePlot:setVisible(true)
	end
	if self.vehicle.Waypoints then
		self:showCourse()
	else
		local x, _, z = getWorldTranslation(self.vehicle.rootNode)
		self.coursePlot:setStartPosition(x, z)
	end
	self.state = CourseGeneratorScreen.SHOW_FULL_MAP

	self.numberOfRowsPerLand:setVisible(self.settings.centerMode:is(courseGenerator.CENTER_MODE_LANDS))
	self.manualRowAngle:setVisible( self.settings.rowDirection:is(courseGenerator.ROW_DIRECTION_MANUAL))
	self:setStartingLocationLabel(self.settings.startOnHeadland:is(courseGenerator.HEADLAND_START_ON_HEADLAND))
	self:setHeadlandFields()
end


function CourseGeneratorScreen:generate()
	local status, ok = courseGenerator.generate(self.vehicle)

	if not status then
		-- show message if there was an exception
		g_gui:showInfoDialog({text=courseplay:loc('COURSEPLAY_COULDNT_GENERATE_COURSE')})
		return
	end

	if not ok then
		-- show message if the generated course may have issues due to the selected track direction
		g_gui:showInfoDialog({text=courseplay:loc('COURSEPLAY_COURSE_SUBOPTIMAL')})
	end
	-- update number of headland passes in case we ended up generating less
	self:setHeadlandProperties()
	self.settings.headlandPasses:updateGuiElement()
	self:showCourse()
end

function CourseGeneratorScreen:onClickActivate()
	self:generate()
end

function CourseGeneratorScreen:onClose()
	g_currentMission.isPlayerFrozen = false
	if self.vehicle then
		self.vehicle.cp.hud.reloadPage[ 8 ] = true
		self.vehicle = nil
	end
	if self.coursePlot then
		self.coursePlot:delete()
		self.coursePlot = nil
	end
	self.ingameMap:onClose()
	CourseGeneratorScreen:superClass().onClose(self)
end

function CourseGeneratorScreen:onClickSelectedField( state )
	self.settings.selectedField:setFromGuiElement()
end

function CourseGeneratorScreen:onClickWidth( state )
	self.settings.workWidth:setFromGuiElement()
end

function CourseGeneratorScreen:onOpenAutoWidth(element)
	local autoWidth = courseplay:getWorkWidth(self.vehicle)
	if autoWidth > 0 then
		element:setVisible(true)
	else
		element:setVisible(false)
	end
end

function CourseGeneratorScreen:onClickAutoWidth(state)
	self.settings.workWidth:setToDefault()
end

function CourseGeneratorScreen:onScrollWidth(element, isDown, isUp, button)
	local eventUsed = false
	if isDown and button == Input.MOUSE_BUTTON_WHEEL_UP then
		eventUsed = true
		self.settings.workWidth:setNext()
	end
	if isDown and button == Input.MOUSE_BUTTON_WHEEL_DOWN then
		eventUsed = true
		self.settings.workWidth:setPrevious()
	end
	return eventUsed
end

function CourseGeneratorScreen:onClickStartingLocation( state )
	self.settings.startingLocation:setFromGuiElement()
	if self.settings.startingLocation:is(courseGenerator.STARTING_LOCATION_SELECT_ON_MAP) and
		self.settings.startingLocation:getSelectedPosition() == nil then
		-- make sure there's a position, just use the vehicle pos
		local x, _, z = getWorldTranslation(self.vehicle.rootNode)
		self.settings.startingLocation:setSelectedPosition(x, z)
	end
end

-----------------------------------------------------------------------------------------------------
-- Row direction
function CourseGeneratorScreen:onClickRowDirection( state )
	self.settings.rowDirection:setFromGuiElement()
	self.manualRowAngle:setVisible( self.settings.rowDirection:is(courseGenerator.ROW_DIRECTION_MANUAL))
end

-----------------------------------------------------------------------------------------------------
-- Manual row angle

function CourseGeneratorScreen:onClickManualRowAngle( state )
	self.settings.manualRowAngle:setFromGuiElement()
end

function CourseGeneratorScreen:onScrollManualRowAngle(element, isDown, isUp, button)
	local eventUsed = false
	if isDown and button == Input.MOUSE_BUTTON_WHEEL_UP then
		self.settings.manualRowAngle:setNext()
	end
	if isDown and button == Input.MOUSE_BUTTON_WHEEL_DOWN then
		self.settings.manualRowAngle:setPrevious()
	end
	return eventUsed
end

function CourseGeneratorScreen:onClickIslandBypassMode( state )
	self.settings.islandBypassMode:setFromGuiElement()
end

-----------------------------------------------------------------------------------------------------
-- Number of rows to skip
function CourseGeneratorScreen:onClickRowsToSkip( state )
	self.settings.rowsToSkip:setFromGuiElement()
end

-----------------------------------------------------------------------------------------------------
-- Multiple tools

function CourseGeneratorScreen:onClickMultiTools( state )
	self.settings.multiTools:setFromGuiElement()
end

-----------------------------------------------------------------------------------------------------
-- Headland mode
function CourseGeneratorScreen:setHeadlandProperties()
	-- headland properties only if we in normal headland mode
	if self.settings.headlandMode:is(courseGenerator.HEADLAND_MODE_TWO_SIDE) then
		-- force headland turn maneuver for two side mode
		self.settings.headlandCornerType:set(courseGenerator.HEADLAND_CORNER_TYPE_SHARP)
	end
end

function CourseGeneratorScreen:setHeadlandFields()
	local headlandFieldsVisible = self.settings.headlandMode:is(courseGenerator.HEADLAND_MODE_NORMAL)
		or self.settings.headlandMode:is(courseGenerator.HEADLAND_MODE_TWO_SIDE)
  self.headlandDirection:setVisible(self.settings.headlandMode:is(courseGenerator.HEADLAND_MODE_NORMAL)
	  or self.settings.headlandMode:is(courseGenerator.HEADLAND_MODE_NARROW_FIELD))
	self.headlandPasses:setVisible(headlandFieldsVisible)
	self.startOnHeadland:setVisible(headlandFieldsVisible)
	-- force headland turn maneuver for two side mode
	self.headlandCornerType:setVisible(headlandFieldsVisible and
		self.settings.headlandMode:is(courseGenerator.HEADLAND_MODE_NORMAL))
	self.headlandOverlapPercent:setVisible(headlandFieldsVisible)
end

function CourseGeneratorScreen:onClickHeadlandMode( state )
	self.settings.headlandMode:setFromGuiElement()
	self:setHeadlandProperties()
	self:setHeadlandFields()
end
-----------------------------------------------------------------------------------------------------
-- Headland passes

function CourseGeneratorScreen:onClickHeadlandPasses( state )
	self.settings.headlandPasses:setFromGuiElement()
end

-----------------------------------------------------------------------------------------------------
-- Headland direction
function CourseGeneratorScreen:onClickHeadlandDirection( state )
	self.settings.headlandDirection:setFromGuiElement()
end

-----------------------------------------------------------------------------------------------------
-- Headland first
function CourseGeneratorScreen:onClickStartOnHeadland( state )
	self.settings.startOnHeadland:setFromGuiElement()
	self:setStartingLocationLabel(self.settings.startOnHeadland:is(courseGenerator.HEADLAND_START_ON_HEADLAND))
end

function CourseGeneratorScreen:setStartingLocationLabel(startOnHeadland)
	self.startingLocation:setLabel(self.settings.startingLocation:getLabel(startOnHeadland))
end

-----------------------------------------------------------------------------------------------------
-- Headland corner
function CourseGeneratorScreen:onClickHeadlandCornerType(state)
	self.settings.headlandCornerType:setFromGuiElement()
end

function CourseGeneratorScreen:onOpenHeadlandOverlapPercent( element, parameter )
	self.settings.headlandOverlapPercent:setGuiElement(element)
	element:setTexts(self.settings.headlandOverlapPercent:getGuiElementTexts())
	element:setState(self.settings.headlandOverlapPercent:getGuiElementState())
end

function CourseGeneratorScreen:onClickHeadlandOverlapPercent(state)
	self.settings.headlandOverlapPercent:setFromGuiElement()
end


-- this is called when the dynamic map gui element is rendered
function CourseGeneratorScreen:draw()
	CourseGeneratorScreen:superClass().draw(self)

	if self.coursePlot then
		self.coursePlot:setPosition(self.ingameMap.absPosition[ 1 ], self.ingameMap.absPosition[ 2 ])
		self.coursePlot:setSize(self.ingameMap.size[1], self.ingameMap.size[2])
		self.coursePlot:draw()
	end
	if self.settings.showSeedCalculator:is(true) then
		self:drawSeedCalculator(self.ingameMap.absPosition[ 1 ],self.ingameMap.absPosition[2]+0.025)
	end
end

function CourseGeneratorScreen:onClickCenterMode(state)
	self.settings.centerMode:setFromGuiElement()
	self.settings.numberOfRowsPerLand:getGuiElement():setVisible(self.settings.centerMode:is(courseGenerator.CENTER_MODE_LANDS))
end

function CourseGeneratorScreen:onClickNumberOfRowsPerLand(state)
	self.settings.numberOfRowsPerLand:setFromGuiElement()
end

function CourseGeneratorScreen:onClickShowSeedCalculator(state)
	self.settings.showSeedCalculator:setFromGuiElement()
end

---a very basic and simple seed calculator in the course generator
function CourseGeneratorScreen:drawSeedCalculator(xPos,yPos)
	-- do have a valid field selected ?
	local currentFieldNumber = self.vehicle.cp.courseGeneratorSettings.selectedField:get()
	if currentFieldNumber ~= 0 then 
		local fieldAreaHa = courseplay.fields.fieldData[currentFieldNumber].areaHa
		local fieldAreaSqm = courseplay.fields.fieldData[currentFieldNumber].areaSqm
		setTextBold(true)
		local textFontSize = 0.02
		local shadowOffset = textFontSize * 0.03
		--shadow color
		local rShadow,gShadow,bShadow,aShadow = 1, 0, 0, 0.8
		--text color
		local r,g,b,a = 1, 0.2, 0, 1
		-- draw shadow
		setTextColor(rShadow,gShadow,bShadow,aShadow)
		renderText(self.ingameMap.absPosition[ 1 ]+shadowOffset,self.ingameMap.absPosition[ 2 ]-shadowOffset,textFontSize,string.format("Field size: %.2f Ha",fieldAreaHa))
		-- draw field size at the bottom
		setTextColor(r,g,b,a)
		renderText(self.ingameMap.absPosition[ 1 ],self.ingameMap.absPosition[ 2 ],textFontSize,string.format("Field size: %.2f Ha",fieldAreaHa))
		-- draw all the sprayTypes and fruitType  
		for _,sprayType in pairs(g_sprayTypeManager:getSprayTypes()) do
			local litersPerSecond = sprayType.litersPerSecond
			-- calculate totalLiters in liters per hour, not sure why 36000 is needed instead of 3600
			local totalLiters = litersPerSecond*fieldAreaHa* 36000
			local name = sprayType.fillType.title
			-- draw shadow
			setTextColor(rShadow,gShadow,bShadow,aShadow)
			renderText(xPos+shadowOffset,yPos-shadowOffset,textFontSize,string.format("%s : %d %s",name,math.ceil(totalLiters),g_i18n:getText("unit_liter")))
			--draw text
			setTextColor(r,g,b,a)
			renderText(xPos,yPos,textFontSize,string.format("%s : %d %s",name,math.ceil(totalLiters),g_i18n:getText("unit_liter")))
			yPos = yPos+0.025
		end
		for _,fruitType in pairs(g_fruitTypeManager:getFruitTypes()) do
			if fruitType.allowsSeeding then
				local seedUsagePerSqm = fruitType.seedUsagePerSqm
				local totalSeedUsage = seedUsagePerSqm*fieldAreaSqm
				local name = fruitType.fillType.title
				-- draw shadow
				setTextColor(rShadow,gShadow,bShadow,aShadow)
				renderText(xPos+shadowOffset,yPos-shadowOffset,textFontSize,string.format("%s : %d %s",name,math.ceil(totalSeedUsage),g_i18n:getText("unit_liter")))
				-- draw text
				setTextColor(r,g,b,a)
				renderText(xPos,yPos,textFontSize,string.format("%s : %d %s",name,math.ceil(totalSeedUsage),g_i18n:getText("unit_liter")))
				yPos = yPos+0.025
			end        
		end
	end
end


function CourseGeneratorScreen:isOverElement( x, y, element )
	if x < element.absPosition[ 1 ] or x > element.absPosition[ 1 ] + element.size[ 1 ] or
		y < element.absPosition[ 2 ] or y > element.absPosition[ 2 ] + element.size[ 2 ] then
		return false
	else
		return true
	end
end

function CourseGeneratorScreen:onClickMap(element, posX, posZ)

	if self.settings.startingLocation:is(courseGenerator.STARTING_LOCATION_SELECT_ON_MAP) then
		self.settings.startingLocation:setSelectedPosition(posX, posZ)
		self.coursePlot:setStartPosition(posX, posZ)
	end

	local fieldNum = courseplay.fields:getFieldNumForPosition(posX, posZ)
	if fieldNum > 0 then
		-- clicked on a field, set it as selected
		self.settings.selectedField:set(fieldNum)
		self.settings.selectedField:updateGuiElement()
	end
end

function CourseGeneratorScreen:zoom(isDown, isUp, button, eventUsed)
	local eventUsed = false
	if isDown and button == Input.MOUSE_BUTTON_WHEEL_UP then
		eventUsed = true
		self.ingameMap:zoom(self.zoomStep)
	end
	if isDown and button == Input.MOUSE_BUTTON_WHEEL_DOWN then
		eventUsed = true
		self.ingameMap:zoom(-self.zoomStep)
	end
	return eventUsed
end

function CourseGeneratorScreen:keyEvent(unicode, sym, modifier, isDown, eventUsed)
end

function CourseGeneratorScreen:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	if CourseGeneratorScreen:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed) then
		eventUsed = true
	end

	if self:isOverElement(posX, posY, self.workWidth) then
		return self:onScrollWidth(self.width, isDown, isUp, button)
	end
	if self:isOverElement(posX, posY, self.manualRowAngle) then
		return self:onScrollManualRowAngle(self.width, isDown, isUp, button)
	end

	if button == Input.MOUSE_BUTTON_WHEEL_UP or button == Input.MOUSE_BUTTON_WHEEL_DOWN then
		self:zoom(isDown, isUp, button, eventUsed)
	end

	return eventUsed
end

-- It is ugly to have a courseplay member function in this file but the current HUD implementations seems to be able to
-- use callbacks only if they are in the courseplay class.
function courseplay:openAdvancedCourseGeneratorSettings( vehicle )
	--- Prevent Dialog from locking up mouse and keyboard when closing it.
	courseplay:lockContext(false);
	g_courseGeneratorScreen = CourseGeneratorScreen:new(vehicle)
	g_gui:loadProfiles( self.path .. "gui/guiProfiles.xml" )
	g_gui:loadGui( self.path .. "gui/CourseGeneratorScreen.xml", "CourseGeneratorScreen", g_courseGeneratorScreen)
	g_courseGeneratorScreen:setVehicle( vehicle )
	g_gui:showGui( 'CourseGeneratorScreen' )
end

