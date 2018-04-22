
CourseGeneratorScreen = {}

local CourseGeneratorScreen_mt = Class(CourseGeneratorScreen, ScreenElement)

CourseGeneratorScreen.SHOW_NOTHING = 0
CourseGeneratorScreen.SHOW_FULL_MAP = 1
CourseGeneratorScreen.SHOW_SELECTED_FIELD = 2

function CourseGeneratorScreen:new(target, custom_mt)
	if custom_mt == nil then
		custom_mt = CourseGeneratorScreen_mt
	end
	local self = ScreenElement:new(target, custom_mt)
	-- needed for onClickBack to work.
	self.returnScreenName = "";
	self.state = CourseGeneratorScreen.SHOW_NOTHING
	self.vehicle = nil
	self.boundingBox = nil

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
	return self
end

function CourseGeneratorScreen:setVehicle( vehicle )
	self.vehicle = vehicle
end

function CourseGeneratorScreen:showSelectedField()
	self.state = CourseGeneratorScreen.SHOW_SELECTED_FIELD
	self.hintText:setText(courseplay:loc('COURSEPLAY_CLICK_MAP_TO_SET_STARTING_POSITION'))
end

function CourseGeneratorScreen:showCourse()
	if self.vehicle.Waypoints and #self.vehicle.Waypoints > 0 then
		self.coursePlot:setWaypoints( self.vehicle.Waypoints )
		self.coursePlot:setStartPosition(self.vehicle.Waypoints[1].cx, self.vehicle.Waypoints[1].cz)
		self.coursePlot:setStopPosition(self.vehicle.Waypoints[#self.vehicle.Waypoints].cx, self.vehicle.Waypoints[#self.vehicle.Waypoints].cz)
	end
end

function CourseGeneratorScreen:onOpen()
	g_currentMission.isPlayerFrozen = true
	CourseGeneratorScreen:superClass().onOpen(self)
	if not self.coursePlot then
		self.coursePlot = CoursePlot:new(
			self.mapOverview.absPosition[ 1 ], self.mapOverview.absPosition[ 2 ],
			self.mapOverview.size[1], self.mapOverview.size[2])
		self.coursePlot:setView( 0, 0, g_currentMission.ingameMap.worldSizeX)
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
	courseplay:generateCourse( self.vehicle )
	self.vehicle.cp.fieldEdge.selectedField.fieldNum = selectedField
	-- update number of headland passes in case we ended up generating less 
	self:setHeadlandProperties()
	self:showCourse()
	self:showSelectedField()
	-- if we have course generated, zoom in on the course
	self.boundingBox = courseplay.utils:getCourseDimensions(self.vehicle.Waypoints)
end

function CourseGeneratorScreen:onClickOk()
	self:generate()
	self:onClickBack()
end

function CourseGeneratorScreen:onClickGenerate()
	self:generate()
end

function CourseGeneratorScreen:onClose()
	self.vehicle.cp.hud.reloadPage[ 8 ] = true
	g_currentMission.isPlayerFrozen = false
	if self.vehicle then self.vehicle = nil end
	if self.boundingBox then self.boundingBox = nil end
	if self.coursePlot then
		self.coursePlot:delete()
		self.coursePlot = nil
	end
	g_currentMission.ingameMap:resetSettings()
	CourseGeneratorScreen:superClass().onClose(self)
end

-----------------------------------------------------------------------------------------------------
-- Field selector
function CourseGeneratorScreen:onOpenFieldSelector( element, parameter )
	local texts = {}
	for _, field in ipairs( self.fields ) do
		table.insert( texts, field.name )
	end
	element:setTexts( texts )
	element:setState( self.fieldToState[ self.vehicle.cp.fieldEdge.selectedField.fieldNum ])
end

function CourseGeneratorScreen:onClickFieldSelector( state )
	self:selectField( self.fields[ state ].number )
end

function CourseGeneratorScreen:selectField( fieldNum )
	self.vehicle.cp.fieldEdge.selectedField.fieldNum = fieldNum
	self.boundingBox = courseplay.utils:getCourseDimensions(courseplay.fields.fieldData[ self.vehicle.cp.fieldEdge.selectedField.fieldNum ].points)
end

-----------------------------------------------------------------------------------------------------
-- Starting location
-- Mappings between the textbox option number and the setting
local function getStartingLocationState( startingCorner )
	return startingCorner - courseGenerator.STARTING_LOCATION_NEW_COURSEGEN_MIN + 1
end

local function getStartingCorner( startingLocationState )
	return startingLocationState + courseGenerator.STARTING_LOCATION_NEW_COURSEGEN_MIN - 1
end

function CourseGeneratorScreen:onOpenStartingLocation( element, parameter )
	local texts = {}
	-- allow for the new course generator only
	for i = courseGenerator.STARTING_LOCATION_NEW_COURSEGEN_MIN, courseGenerator.STARTING_LOCATION_MAX do
		-- enable last position only if the vehicle has one
		if i ~= courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION or self.vehicle.cp.generationPosition.hasSavedPosition then
			table.insert( texts, courseplay:loc(string.format('COURSEPLAY_CORNER_%d', i )))
		end
	end
	element:setTexts( texts )
	-- force new course gen settings.
	if not self.vehicle.cp.isNewCourseGenSelected() or not self.vehicle.cp.hasStartingCorner then
		courseplay:setStartingCorner( self.vehicle, courseGenerator.STARTING_LOCATION_VEHICLE_POSITION )
	end
	element:setState( getStartingLocationState( self.vehicle.cp.startingCorner ))
end

function CourseGeneratorScreen:onClickStartingLocation( state )
	courseplay:setStartingCorner( self.vehicle, getStartingCorner(state))
	if self.vehicle.cp.startingCorner == courseGenerator.STARTING_LOCATION_SELECT_ON_MAP and
		not self.vehicle.cp.courseGeneratorSettings.startingLocationWorldPos then
		if self.vehicle.Waypoints and #self.vehicle.Waypoints > 0 then
			self.vehicle.cp.courseGeneratorSettings.startingLocationWorldPos = ({ x = self.vehicle.Waypoints[1].cx, z = self.vehicle.Waypoints[1].cz})
		else
			local x, _, z = getWorldTranslation(self.vehicle.rootNode)
			self.vehicle.cp.courseGeneratorSettings.startingLocationWorldPos = ({ x = x, z = z })
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

-----------------------------------------------------------------------------------------------------
-- Headland corner
function CourseGeneratorScreen:onOpenIslandBypassMode( element, parameter )
	local texts = {}
	for i = 1, Island.BYPASS_MODE_MAX do
		table.insert( texts, courseplay:loc( Island.bypassModeText[ i ]))
	end
	element:setTexts( texts )
	element:setState( self.vehicle.cp.courseGeneratorSettings.islandBypassMode )
end

function CourseGeneratorScreen:onClickIslandBypassMode( state )
	self.vehicle.cp.courseGeneratorSettings.islandBypassMode = state
end

-----------------------------------------------------------------------------------------------------
-- Number of rows to skip
function CourseGeneratorScreen:onOpenSkipRows( element, parameter )
	local texts = {}
	for i = 0, 3 do
		table.insert( texts, tostring( i ))
	end
	element:setTexts( texts )
	element:setState( self.vehicle.cp.courseGeneratorSettings.nRowsToSkip + 1 )
end

function CourseGeneratorScreen:onClickSkipRows( state )
	self.vehicle.cp.courseGeneratorSettings.nRowsToSkip = state - 1
end

-----------------------------------------------------------------------------------------------------
-- Headland mode
function CourseGeneratorScreen:setHeadlandProperties()
	-- headland properties only if we in normal headland mode
	if self.vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_NORMAL then
		if self.vehicle.cp.headland.getNumLanes() == 0 then
			self.vehicle.cp.headland.numLanes = 1
		end
		self.headlandPasses:setState( self.vehicle.cp.headland.numLanes )
	elseif self.vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_NONE then
		self.vehicle.cp.headland.numLanes = 0
	end
end

function CourseGeneratorScreen:setHeadlandFields()
	local headlandFieldsVisible = self.vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_NORMAL
	self.headlandDirection:setVisible( headlandFieldsVisible )
	self.headlandPasses:setVisible( headlandFieldsVisible )
	self.headlandFirst:setVisible( headlandFieldsVisible )
	self.headlandCorners:setVisible( headlandFieldsVisible )
end

function CourseGeneratorScreen:onOpenHeadlandMode( element, parameter )
	local texts = {}
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_MODE_NONE' ))
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_MODE_NORMAL' ))
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_MODE_NARROW_FIELD' ))
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
end

function CourseGeneratorScreen:onClickHeadlandFirst( state )
	if state ~= self.vehicle.cp.headland.orderBefore then
		-- must call this in order to update the bitmap in the HUD, that is apparently not being taken care of by reload
		courseplay:toggleHeadlandOrder( self.vehicle )
	end
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

-- this is called when the dynamic map gui element is rendered
function CourseGeneratorScreen:drawDynamicMapImage(element)
	if g_currentMission and g_currentMission.ingameMap and g_currentMission.ingameMap.mapOverlay and
		g_currentMission.ingameMap.mapOverlay.filename and not self.mapOverlay then

		local ingameMap = g_currentMission.ingameMap
		-- zoom out completely by default
		ingameMap.mapVisWidthMin = 1

		if self.state == CourseGeneratorScreen.SHOW_SELECTED_FIELD and self.boundingBox then
			local padding = 10
			local centerX = ( self.boundingBox.xMin + self.boundingBox.xMax ) / 2
			local centerY = ( self.boundingBox.yMin + self.boundingBox.yMax ) / 2
			local width = self.boundingBox.span + 2 * padding
			if self.coursePlot then
				self.coursePlot:setView( centerX, centerY, width )
			end
			-- figure out view (center and zoom) for ingame map, normalized
			ingameMap.mapVisWidthMin = 1 / ingameMap.worldSizeX * width
			-- ingame map uses normalized coordinates, the map corners are (0,0) and (1,1)
			ingameMap.centerXPos = Utils.clamp(( centerX + ingameMap.worldCenterOffsetX)/ingameMap.worldSizeX, 0, 1)
			ingameMap.centerZPos = Utils.clamp(( centerY + ingameMap.worldCenterOffsetZ)/ingameMap.worldSizeZ, 0, 1)
		end

		ingameMap:setPosition(self.mapOverview.absPosition[1], self.mapOverview.absPosition[2])
		ingameMap:setSize(self.mapOverview.size[1], self.mapOverview.size[2])
		local leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached = ingameMap:drawMap(1)
		ingameMap:renderHotspots(leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached, false, true);
		if self.coursePlot then
			self.coursePlot:draw()
		end
	end
end

function CourseGeneratorScreen:isOnMap(x, y)
	if x < self.mapOverview.absPosition[ 1 ] or x > self.mapOverview.absPosition[ 1 ] + self.mapOverview.size[ 1 ] or
		y < self.mapOverview.absPosition[ 2 ] or y > self.mapOverview.absPosition[ 2 ] + self.mapOverview.size[ 2 ] then
		return false
	else
		return true
	end
end

function CourseGeneratorScreen:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	if CourseGeneratorScreen:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed) then
		eventUsed = true
	end
	if not eventUsed and isDown and button == Input.MOUSE_BUTTON_LEFT then
		-- ignore clicks off the map
		if not self:isOnMap(posX, posY) then return eventUsed end
		eventUsed = true
		-- find world coordinates from the mouse cursor position
		local viewX, viewY = posX - self.mapOverview.absPosition[ 1 ], posY - self.mapOverview.absPosition[ 2 ]
		local viewW, viewH = self.mapOverview.size[ 1 ], self.mapOverview.size[ 2 ]
		local x, z = self.coursePlot:screenToWorld(posX, posY)
		if self.state == CourseGeneratorScreen.SHOW_FULL_MAP then
			-- find the field under the cursor
			local fieldNum = courseplay:getFieldNumForPosition( x, z )
			if fieldNum > 0 and self.fields then
				-- clicked on a field, set it as selected
				for i, field in ipairs( self.fields ) do
					if field.number == fieldNum then
						-- field found
						self.fieldSelector:setState( i )
						self:selectField( fieldNum )
						-- zoom in on the selected field
						self:showSelectedField()
						return eventUsed
					end
				end
			end
		elseif self.state == CourseGeneratorScreen.SHOW_SELECTED_FIELD then--and		  then
			self.vehicle.cp.courseGeneratorSettings.startingLocationWorldPos = { x=x, z=z }
			self.coursePlot:setStartPosition(x, z)
			self.vehicle.cp.startingCorner = courseGenerator.STARTING_LOCATION_SELECT_ON_MAP
			self.startingLocation:setState( getStartingLocationState( self.vehicle.cp.startingCorner ))
		end
	end
	return eventUsed
end