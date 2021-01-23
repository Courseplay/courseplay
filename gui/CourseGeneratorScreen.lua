
---@class CourseGeneratorScreen
CourseGeneratorScreen = {}

local CourseGeneratorScreen_mt = Class(CourseGeneratorScreen, ScreenElement)

CourseGeneratorScreen.SHOW_NOTHING = 0
CourseGeneratorScreen.SHOW_FULL_MAP = 1
CourseGeneratorScreen.SHOW_SELECTED_FIELD = 2
CourseGeneratorScreen.WidthFormatString = '%.1f m'

-- these are needed to be able to access those screen elements with self.<id>
CourseGeneratorScreen.CONTROLS = {
	fieldSelector = 'fieldSelector',
	startingLocation = 'startingLocation',
	rowDirectionMode = 'rowDirectionMode',
	manualDirectionAngle = 'manualDirectionAngle',
	width = 'width',
	autoWidth = 'autoWidth',
	islandBypassMode = 'islandBypassMode',
	headlandDirection = 'headlandDirection',
	headlandCorners = 'headlandCorners',
	headlandOverlapPercent = 'headlandOverlapPercent',
	headlandPasses = 'headlandPasses',
	headlandFirst = 'headlandFirst',
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

function CourseGeneratorScreen:setFromGui(setting)
	if setting:getGuiElement() then
		setting:setToIx(setting:getGuiElement():getState())
	end
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
	print('CourseGeneratorScreen:onCreate()')
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

function CourseGeneratorScreen:onOpen()
	-- Make sure we always load the most up to date field data
	-- List of fields
	self.fields = {}
	for key, field in pairs( courseplay.fields.fieldData ) do
		table.insert( self.fields, { name = field.name, number = key })
	end
	table.sort( self.fields, function( a, b ) return a.number < b.number end )

	-- set up a reverse lookup table
	self.fieldToState = {}
	for i, f in ipairs( self.fields ) do
		self.fieldToState[ f.number ] = i
		i = i + 1
	end

	-- add the 'currently loaded course' option
	table.insert( self.fields, { name = courseplay:loc( 'COURSEPLAY_CURRENTLY_LOADED_COURSE' ), number = 0 })
	self.fieldToState[ 0 ] = #self.fields

	g_currentMission.isPlayerFrozen = true

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

end


function CourseGeneratorScreen:generate()
	-- save the selected field as generateCourse will reset it.
	-- this way we can regenerate the course with different settings without
	-- having to reselect the field or closing the GUI
	local selectedField = self.vehicle.cp.fieldEdge.selectedField.fieldNum
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
	
	self.vehicle.cp.fieldEdge.selectedField.fieldNum = selectedField
	-- update number of headland passes in case we ended up generating less 
	self:setHeadlandProperties()
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

-----------------------------------------------------------------------------------------------------
-- Field selector
function CourseGeneratorScreen:onOpenFieldSelector( element, parameter )
	local texts = {}
	if self.fields then
		for _, field in ipairs( self.fields ) do
			table.insert( texts, field.name )
		end
	end
	element:setTexts( texts )
	element:setState( self.fieldToState[ self.vehicle.cp.fieldEdge.selectedField.fieldNum ])
	end

function CourseGeneratorScreen:onClickFieldSelector( state )
	self:selectField( self.fields[ state ].number )
end

function CourseGeneratorScreen:selectField( fieldNum )
	self.vehicle.cp.fieldEdge.selectedField.fieldNum = fieldNum
end
-----------------------------------------------------------------------------------------------------
-- Working width
function CourseGeneratorScreen:onOpenWidth( element )
	local texts = {}
	self.minWidth, self.maxWidth = 1, 50
	local w = self.vehicle.cp.workWidth
	-- have at most 3 values in the text box around the selected
	if w > self.minWidth then table.insert( texts, string.format(CourseGeneratorScreen.WidthFormatString, w - 0.1)) end
	table.insert(texts, string.format(CourseGeneratorScreen.WidthFormatString, w))
	if w < self.maxWidth then table.insert( texts, string.format(CourseGeneratorScreen.WidthFormatString, w + 0.1)) end
	element:setTexts(texts)
	if w == self.minWidth then
		element:setState(1)
	else
		element:setState(2)
	end
end

function CourseGeneratorScreen:onClickWidth( state )
	if state == 1 then
		self.vehicle.cp.workWidth = MathUtil.clamp(self.vehicle.cp.workWidth - 0.1, self.minWidth, self.maxWidth)
	else
		self.vehicle.cp.workWidth = MathUtil.clamp(self.vehicle.cp.workWidth + 0.1, self.minWidth, self.maxWidth)
	end
	self:onOpenWidth(self.width)
end

function CourseGeneratorScreen:onOpenAutoWidth(element)
	local autoWidth = courseplay:getWorkWidth(self.vehicle)
	if autoWidth > 0 then
		element:setVisible(true)
		element:setText(string.format(CourseGeneratorScreen.WidthFormatString, courseplay:getWorkWidth(self.vehicle)))
	else
		element:setVisible(false)
	end
end

function CourseGeneratorScreen:onClickAutoWidth(state)
	local autoWidth = courseplay:getWorkWidth(self.vehicle)
	if autoWidth > 0 then
		self.vehicle.cp.workWidth = autoWidth
		self:onOpenWidth(self.width)
	end
end

function CourseGeneratorScreen:onScrollWidth(element, isDown, isUp, button)
	local eventUsed = false
	if isDown and button == Input.MOUSE_BUTTON_WHEEL_UP then
		eventUsed = true
		self.vehicle.cp.workWidth = MathUtil.clamp(self.vehicle.cp.workWidth + 0.1, self.minWidth, self.maxWidth)
		self:onOpenWidth(self.width)
	end
	if isDown and button == Input.MOUSE_BUTTON_WHEEL_DOWN then
		eventUsed = true
		self.vehicle.cp.workWidth = MathUtil.clamp(self.vehicle.cp.workWidth - 0.1, self.minWidth, self.maxWidth)
		self:onOpenWidth(self.width)
	end
	return eventUsed
end

-----------------------------------------------------------------------------------------------------
-- Starting location
function CourseGeneratorScreen:onOpenStartingLocation( element, parameter )
	self.startingLocationSetting = StartingLocationSetting(self.vehicle)
	element:setTexts(self.startingLocationSetting:getGuiElementTexts())

	-- force new course gen settings.
	if not self.vehicle.cp.isNewCourseGenSelected() or not self.vehicle.cp.hasStartingCorner then
		courseplay:setStartingCorner( self.vehicle, courseGenerator.STARTING_LOCATION_VEHICLE_POSITION )
		self.startingLocationSetting:set(courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION)
	end
	element:setState(self.startingLocationSetting:getGuiElementStateFromValue(self.vehicle.cp.startingCorner))
end

function CourseGeneratorScreen:onClickStartingLocation( state )
	courseplay:setStartingCorner(self.vehicle, self.startingLocationSetting:getValueFromGuiElementState(state))
	if self.vehicle.cp.startingCorner == courseGenerator.STARTING_LOCATION_SELECT_ON_MAP and
		not self.vehicle.cp.oldCourseGeneratorSettings.startingLocationWorldPos then
		if self.vehicle.Waypoints and #self.vehicle.Waypoints > 0 then
			self.vehicle.cp.oldCourseGeneratorSettings.startingLocationWorldPos = ({ x = self.vehicle.Waypoints[1].cx, z = self.vehicle.Waypoints[1].cz})
		else
			local x, _, z = getWorldTranslation(self.vehicle.rootNode)
			self.vehicle.cp.oldCourseGeneratorSettings.startingLocationWorldPos = ({ x = x, z = z })
		end
	end
end

-----------------------------------------------------------------------------------------------------
-- Row direction mode
local function getRowDirectionModeState( rowDirectionMode )
	return rowDirectionMode - courseGenerator.ROW_DIRECTION_MIN + 1
end

local function getRowDirectionMode( rowDirectionModeState )
	return rowDirectionModeState + courseGenerator.ROW_DIRECTION_MIN - 1
end

function CourseGeneratorScreen:onOpenRowDirectionMode( element, parameter )
	local texts = {}
	for i = courseGenerator.ROW_DIRECTION_MIN, courseGenerator.ROW_DIRECTION_MAX do
		table.insert( texts, courseplay:loc(string.format('COURSEPLAY_DIRECTION_%d', i )))
	end
	element:setTexts( texts )
	element:setState( getRowDirectionModeState( self.vehicle.cp.rowDirectionMode ))
end

function CourseGeneratorScreen:onClickRowDirectionMode( state )
	courseplay:setRowDirectionMode( self.vehicle, getRowDirectionMode( state ))
	self.manualDirectionAngle:setVisible( self.vehicle.cp.rowDirectionMode == courseGenerator.ROW_DIRECTION_MANUAL )
end

-----------------------------------------------------------------------------------------------------
-- Manual row angle
function CourseGeneratorScreen:onOpenManualDirectionAngle( element, parameter )
	local texts = {}
	for i, direction in ipairs( self.directions ) do
		table.insert( texts, tostring( direction.compassAngleDeg ) .. '°' .. ' (' .. courseplay:loc( courseGenerator.getCompassDirectionText( direction.gameAngleDeg )) .. ')')
	end
	element:setTexts( texts )
	element:setState( self.directionToState[ self.vehicle.cp.rowDirectionDeg ])
	-- enable only when manual row direction is selected.
	element:setVisible( self.vehicle.cp.rowDirectionMode == courseGenerator.ROW_DIRECTION_MANUAL )
end

function CourseGeneratorScreen:onClickManualDirectionAngle( state )
	self.vehicle.cp.rowDirectionDeg = self.directions[ state ].gameAngleDeg
end

function CourseGeneratorScreen:onScrollManualDirectionAngle(element, isDown, isUp, button)
	local eventUsed = false
	local currentState = self.manualDirectionAngle:getState()
	if isDown and button == Input.MOUSE_BUTTON_WHEEL_UP then
		eventUsed = true
		local newState = currentState + 1
		newState = newState <= #self.directions and newState or 1
		self.manualDirectionAngle:setState(newState)
		self.vehicle.cp.rowDirectionDeg = self.directions[ newState ].gameAngleDeg
	end
	if isDown and button == Input.MOUSE_BUTTON_WHEEL_DOWN then
		eventUsed = true
		local newState = currentState - 1
		newState = newState > 0 and newState or #self.directions
		self.manualDirectionAngle:setState(newState)
		self.vehicle.cp.rowDirectionDeg = self.directions[ newState ].gameAngleDeg
	end
	return eventUsed
end

-----------------------------------------------------------------------------------------------------
-- Island bypass mode
function CourseGeneratorScreen:onOpenIslandBypassMode( element, parameter )
	local texts = {}
	for i = 1, Island.BYPASS_MODE_MAX do
		table.insert( texts, courseplay:loc( Island.bypassModeText[ i ]))
	end
	element:setTexts( texts )
	element:setState( self.vehicle.cp.oldCourseGeneratorSettings.islandBypassMode )
end

function CourseGeneratorScreen:onClickIslandBypassMode( state )
	self.vehicle.cp.oldCourseGeneratorSettings.islandBypassMode = state
end


-----------------------------------------------------------------------------------------------------
-- Number of rows to skip
function CourseGeneratorScreen:onOpenSkipRows( element, parameter )
	local texts = {}
	for i = 0, 3 do
		table.insert( texts, tostring( i ))
	end
	element:setTexts( texts )
	element:setState( self.vehicle.cp.oldCourseGeneratorSettings.nRowsToSkip + 1 )
end

function CourseGeneratorScreen:onClickSkipRows( state )
	self.vehicle.cp.oldCourseGeneratorSettings.nRowsToSkip = state - 1
end

-----------------------------------------------------------------------------------------------------
-- Multiple tools
function CourseGeneratorScreen:onOpenMultiTools( element, parameter )
	local texts = {}
	for i = 1,8 do
		table.insert( texts, i )
	end
	element:setTexts( texts )
	element:setState( self.vehicle.cp.multiTools )
end

function CourseGeneratorScreen:onClickMultiTools( state )
	--Courseplay call here cause of courseplay:changeLaneNumber function is called when this number is changed
	courseplay:setMultiTools(self.vehicle, state)
end

-----------------------------------------------------------------------------------------------------
-- Headland mode
function CourseGeneratorScreen:setHeadlandProperties()
	-- headland properties only if we in normal headland mode
	if self.vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_NORMAL or
		self.vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_TWO_SIDE then
		if self.vehicle.cp.headland.getNumLanes() == 0 then
			self.vehicle.cp.headland.numLanes = 1
		end
		self.headlandPasses:setState( self.vehicle.cp.headland.numLanes )
		if self.vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_TWO_SIDE then
			-- force headland turn maneuver for two side mode
			self.vehicle.cp.headland.turnType = courseplay.HEADLAND_CORNER_TYPE_SHARP
		end
	elseif self.vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_NONE then
		self.vehicle.cp.headland.numLanes = 0
	end
end

function CourseGeneratorScreen:setHeadlandFields()
	local headlandFieldsVisible = self.vehicle.cp.headland.mode ==
		courseGenerator.HEADLAND_MODE_NORMAL or self.vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_TWO_SIDE
  self.headlandDirection:setVisible( self.vehicle.cp.headland.mode ==
		courseGenerator.HEADLAND_MODE_NORMAL or self.vehicle.cp.headland.mode ==
		courseGenerator.HEADLAND_MODE_NARROW_FIELD )
	self.headlandPasses:setVisible( headlandFieldsVisible )
	self.headlandFirst:setVisible( headlandFieldsVisible )
	-- force headland turn maneuver for two side mode
	self.headlandCorners:setVisible( headlandFieldsVisible and self.vehicle.cp.headland.mode ==
		courseGenerator.HEADLAND_MODE_NORMAL)
	self.headlandOverlapPercent:setVisible( headlandFieldsVisible )
end

function CourseGeneratorScreen:onOpenHeadlandMode( element, parameter )
	local texts = {}
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_MODE_NONE' ))
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_MODE_NORMAL' ))
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_MODE_NARROW_FIELD' ))
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_MODE_TWO_SIDE' ))
	element:setTexts( texts )
	self:setHeadlandProperties()
	element:setState( self.vehicle.cp.headland.mode )
	self:setHeadlandFields()
end

function CourseGeneratorScreen:onClickHeadlandMode( state )
	self.vehicle.cp.headland.mode = state
	self:setHeadlandProperties()
	self:setHeadlandFields()
end
-----------------------------------------------------------------------------------------------------
-- Headland passes
function CourseGeneratorScreen:onOpenHeadlandPasses( element, parameter )
	local texts = {}
	for i = 1, self.vehicle.cp.headland.autoDirMaxNumLanes do
		table.insert( texts, tostring( i ))
	end
	element:setTexts( texts )
	element:setState( self.vehicle.cp.headland.getNumLanes())
end

function CourseGeneratorScreen:onClickHeadlandPasses( state )
	self.vehicle.cp.headland.numLanes = state
end


-----------------------------------------------------------------------------------------------------
-- Headland direction
function CourseGeneratorScreen:onOpenHeadlandDirection( element, parameter )
	local texts = {}
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_CLOCKWISE' ))
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_COUNTERCLOCKWISE' ))
	element:setTexts( texts )
	local state = self.vehicle.cp.headland.userDirClockwise and 1 or 2
	element:setState( state )
end

function CourseGeneratorScreen:onClickHeadlandDirection( state )
	self.vehicle.cp.headland.userDirClockwise = state == 1
end

-----------------------------------------------------------------------------------------------------
-- Headland first
function CourseGeneratorScreen:onOpenHeadlandFirst( element, parameter )
	local texts = {}
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_PASSES' ))
	table.insert( texts, courseplay:loc( 'COURSEPLAY_UP_DOWN_ROWS' ))
	element:setTexts( texts )
	local state = self.vehicle.cp.headland.orderBefore and 1 or 2
	element:setState( state )
	self:setStartingLocationLabel(self.vehicle.cp.headland.orderBefore)
end

function CourseGeneratorScreen:onClickHeadlandFirst( state )
	if state ~= self.vehicle.cp.headland.orderBefore then
		-- must call this in order to update the bitmap in the HUD, that is apparently not being taken care of by reload
		courseplay:toggleHeadlandOrder( self.vehicle )
	end
	self:setStartingLocationLabel(self.vehicle.cp.headland.orderBefore)
end

function CourseGeneratorScreen:setStartingLocationLabel(headlandFirst)
	local label = headlandFirst and
			courseplay:loc('COURSEPLAY_STARTING_LOCATION') or
			courseplay:loc('COURSEPLAY_ENDING_LOCATION')
	self.startingLocation.labelElement.text = label
end

-----------------------------------------------------------------------------------------------------
-- Headland corner
function CourseGeneratorScreen:onOpenHeadlandCorners( element, parameter )
	local texts = {}
	for i = 1, courseplay.HEADLAND_CORNER_TYPE_MAX do
		table.insert( texts, courseplay:loc( courseplay.cornerTypeText[ i ]))
	end
	element:setTexts( texts )
	element:setState( self.vehicle.cp.headland.turnType )
end

function CourseGeneratorScreen:onClickHeadlandCorners( state )
	self.vehicle.cp.headland.turnType = state
end

function CourseGeneratorScreen:onOpenHeadlandOverlapPercent( element, parameter )
	self.vehicle.cp.courseGeneratorSettings.headlandOverlapPercent:setGuiElement(element)
	element:setTexts(self.vehicle.cp.courseGeneratorSettings.headlandOverlapPercent:getGuiElementTexts())
	element:setState(self.vehicle.cp.courseGeneratorSettings.headlandOverlapPercent:getGuiElementState())
end

function CourseGeneratorScreen:onClickHeadlandOverlapPercent(state)
	self:setFromGui(self.vehicle.cp.courseGeneratorSettings.headlandOverlapPercent)
end


-- this is called when the dynamic map gui element is rendered
function CourseGeneratorScreen:draw()
	CourseGeneratorScreen:superClass().draw(self)

	if self.coursePlot then
		self.coursePlot:setPosition(self.ingameMap.absPosition[ 1 ], self.ingameMap.absPosition[ 2 ])
		self.coursePlot:setSize(self.ingameMap.size[1], self.ingameMap.size[2])
		self.coursePlot:draw()
	end
	if self.vehicle.cp.courseGeneratorSettings.showSeedCalculator:is(true) then
		self:drawSeedCalculator(self.ingameMap.absPosition[ 1 ],self.ingameMap.absPosition[2]+0.025)
	end
end

function CourseGeneratorScreen:onOpenCenterMode( element, parameter )
	self.vehicle.cp.courseGeneratorSettings.centerMode:setGuiElement(element)
	element:setTexts(self.vehicle.cp.courseGeneratorSettings.centerMode:getGuiElementTexts())
	element:setState(self.vehicle.cp.courseGeneratorSettings.centerMode:getGuiElementState())
end

function CourseGeneratorScreen:onClickCenterMode(state)
	self:setFromGui(self.vehicle.cp.courseGeneratorSettings.centerMode)
	print(self.vehicle.cp.courseGeneratorSettings.centerMode:get())
	self.vehicle.cp.courseGeneratorSettings.numberOfRowsPerLand:getGuiElement():setVisible(self.vehicle.cp.courseGeneratorSettings.centerMode:is(courseGenerator.CENTER_MODE_LANDS))
end

function CourseGeneratorScreen:onOpenNumberOfRowsPerLand( element, parameter )
	self.vehicle.cp.courseGeneratorSettings.numberOfRowsPerLand:setGuiElement(element)
	element:setTexts(self.vehicle.cp.courseGeneratorSettings.numberOfRowsPerLand:getGuiElementTexts())
	element:setState(self.vehicle.cp.courseGeneratorSettings.numberOfRowsPerLand:getGuiElementState())
	element:setVisible(self.vehicle.cp.courseGeneratorSettings.centerMode:is(courseGenerator.CENTER_MODE_LANDS))
end

function CourseGeneratorScreen:onClickNumberOfRowsPerLand(state)
	local setting = self.vehicle.cp.courseGeneratorSettings.numberOfRowsPerLand
	if setting:getGuiElement() then
		setting:setToIx(setting:getGuiElement():getState())
	end
end

function CourseGeneratorScreen:onOpenShowSeedCalculator( element, parameter )
	local setting = self.vehicle.cp.courseGeneratorSettings.showSeedCalculator
	setting:setGuiElement(element)
	element:setTexts(setting:getGuiElementTexts())
	element:setState(setting:getGuiElementState())
end

function CourseGeneratorScreen:onClickShowSeedCalculator(state)
	local setting = self.vehicle.cp.courseGeneratorSettings.showSeedCalculator
	if setting:getGuiElement() then
		setting:setToIx(setting:getGuiElement():getState())
	end
end

---a very basic and simple seed calculator in the course generator
function CourseGeneratorScreen:drawSeedCalculator(xPos,yPos)
	-- do have a valid field selected ?
	local currentFieldNumber = self.vehicle.cp.fieldEdge.selectedField.fieldNum
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

	if courseGenerator.STARTING_LOCATION_SELECT_ON_MAP == self.startingLocationSetting:getValueFromGuiElementState(self.startingLocation:getState()) then
		self.vehicle.cp.oldCourseGeneratorSettings.startingLocationWorldPos = {x = posX, z = posZ }
		self.coursePlot:setStartPosition(posX, posZ)
	end

	local fieldNum = courseplay.fields:getFieldNumForPosition(posX, posZ)
	if fieldNum > 0 and self.fields then
		-- clicked on a field, set it as selected
		for i, field in ipairs(self.fields) do
			if field.number == fieldNum then
				-- field found
				self.fieldSelector:setState(i)
				self:selectField( fieldNum )
			end
		end
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

	if self:isOverElement(posX, posY, self.width) then
		return self:onScrollWidth(self.width, isDown, isUp, button)
	end
	if self:isOverElement(posX, posY, self.manualDirectionAngle) then
		return self:onScrollManualDirectionAngle(self.width, isDown, isUp, button)
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

