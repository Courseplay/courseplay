
courseGeneratorScreen = {}

local courseGeneratorScreen_mt = Class(courseGeneratorScreen, ScreenElement)

function courseGeneratorScreen:new(target, custom_mt)
	if custom_mt == nil then
		custom_mt = courseGeneratorScreen_mt
	end
	local self = ScreenElement:new(target, custom_mt)
	-- needed for onClickBack to work.
	self.returnScreenName = "";

	self.vehicle = nil

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

	self.fields = {}
	self.fieldToState = {}
	i = 1
	for key, field in pairs( courseplay.fields.fieldData ) do
		table.insert( self.fields, { name = field.name, number = key })
		self.fieldToState[ key ] = i
		i = i + 1
	end
	-- add the 'currently loaded course' option
	table.insert( self.fields, { name = courseplay:loc( 'COURSEPLAY_CURRENTLY_LOADED_COURSE' ), number = 0 })
	self.fieldToState[ 0 ] = #self.fields
	return self
end

function courseGeneratorScreen:setVehicle( vehicle )
	self.vehicle = vehicle
end

function courseGeneratorScreen:onOpen()
	g_currentMission.isPlayerFrozen = true
	courseGeneratorScreen:superClass().onOpen(self)
end

function courseGeneratorScreen:onClickOk()
	courseplay:generateCourse( self.vehicle )
	self:onClickBack()
end

function courseGeneratorScreen:onClickGenerate()
	-- save the selected field as generateCourse will reset it.
	-- this way we can regenerate the course with different settings without
	-- having to reselect the field or closing the GUI
	local selectedField = self.vehicle.cp.fieldEdge.selectedField.fieldNum
	courseplay:generateCourse( self.vehicle )
	courseplay:setupCourse2dData( self.vehicle )
	self.vehicle.cp.fieldEdge.selectedField.fieldNum = selectedField
end

function courseGeneratorScreen:onClose()
	self.vehicle.cp.hud.reloadPage[ 8 ] = true
	g_currentMission.isPlayerFrozen = false
	self.vehicle = nil
	g_currentMission.ingameMap:resetSettings()
	courseGeneratorScreen:superClass().onClose(self)
end

-----------------------------------------------------------------------------------------------------
-- Field selector
function courseGeneratorScreen:onOpenFieldSelector( element, parameter )
	local texts = {}
	for _, field in ipairs( self.fields ) do
		table.insert( texts, field.name )
	end
	element:setTexts( texts )
	element:setState( self.fieldToState[ self.vehicle.cp.fieldEdge.selectedField.fieldNum ])
end

function courseGeneratorScreen:onClickFieldSelector( state )
	self.vehicle.cp.fieldEdge.selectedField.fieldNum = self.fields[ state ].number
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


function courseGeneratorScreen:onOpenStartingLocation( element, parameter )
	local texts = {}
	-- allow for the new course generator only
	for i = courseGenerator.STARTING_LOCATION_NEW_COURSEGEN_MIN, courseGenerator.STARTING_LOCATION_MAX do
		-- enable last position only if the vehicle has one
		if i ~= courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION or self.vehicle.cp.generationPosition.hasSavedPosition then
			table.insert( texts, courseplay:loc(string.format('COURSEPLAY_CORNER_%d', i )))
		end
	end
	element:setTexts( texts )
	if not self.vehicle.cp.isNewCourseGenSelected() then
		courseplay:setStartingCorner( self.vehicle, courseGenerator.STARTING_LOCATION_VEHICLE_POSITION )
	end
	element:setState( getStartingLocationState( self.vehicle.cp.startingCorner ))
end

function courseGeneratorScreen:onClickStartingLocation( state )
	courseplay:setStartingCorner( self.vehicle, getStartingCorner(state ))
end

-----------------------------------------------------------------------------------------------------
-- Row direction mode
local function getRowDirectionModeState( rowDirectionMode )
	return rowDirectionMode - courseGenerator.ROW_DIRECTION_MIN + 1
end

local function getRowDirectionMode( rowDirectionModeState )
	return rowDirectionModeState + courseGenerator.ROW_DIRECTION_MIN - 1
end

function courseGeneratorScreen:onOpenRowDirectionMode( element, parameter )
	local texts = {}
	for i = courseGenerator.ROW_DIRECTION_MIN, courseGenerator.ROW_DIRECTION_MAX do
		table.insert( texts, courseplay:loc(string.format('COURSEPLAY_DIRECTION_%d', i )))
	end
	element:setTexts( texts )
	element:setState( getRowDirectionModeState( self.vehicle.cp.rowDirectionMode ))
end

function courseGeneratorScreen:onClickRowDirectionMode( state )
	courseplay:setRowDirectionMode( self.vehicle, getRowDirectionMode( state ))
	self.manualDirectionAngle:setVisible( self.vehicle.cp.rowDirectionMode == courseGenerator.ROW_DIRECTION_MANUAL )
end

-----------------------------------------------------------------------------------------------------
-- Manual row angle
function courseGeneratorScreen:onOpenManualDirectionAngle( element, parameter )
	local texts = {}
	for i, direction in ipairs( self.directions ) do
		table.insert( texts, tostring( direction.compassAngleDeg ) .. '°' .. ' (' .. courseplay:loc( courseGenerator.getCompassDirectionText( direction.gameAngleDeg )) .. ')')
	end
	element:setTexts( texts )
	element:setState( self.directionToState[ self.vehicle.cp.rowDirectionDeg ])
	-- enable only when manual row direction is selected.
	element:setVisible( self.vehicle.cp.rowDirectionMode == courseGenerator.ROW_DIRECTION_MANUAL )
end

function courseGeneratorScreen:onClickManualDirectionAngle( state )
	self.vehicle.cp.rowDirectionDeg = self.directions[ state ].gameAngleDeg
end

-----------------------------------------------------------------------------------------------------
-- Headland corner
function courseGeneratorScreen:onOpenIslandBypassMode( element, parameter )
	local texts = {}
	for i = 1, Island.BYPASS_MODE_MAX do
		table.insert( texts, courseplay:loc( Island.bypassModeText[ i ]))
	end
	element:setTexts( texts )
	element:setState( self.vehicle.cp.islandBypassMode )
end

function courseGeneratorScreen:onClickIslandBypassMode( state )
	self.vehicle.cp.islandBypassMode = state
end


-----------------------------------------------------------------------------------------------------
-- Headland mode
function courseGeneratorScreen:setHeadlandProperties()
	-- headland properties only if we in normal headland mode
	if self.vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_NORMAL then
		if self.vehicle.cp.headland.getNumLanes() == 0 then
			self.vehicle.cp.headland.numLanes = 1
			self.headlandPasses:setState( self.vehicle.cp.headland.numLanes )
		end
	end
end

function courseGeneratorScreen:setHeadlandFields()
	local headlandFieldsVisible = self.vehicle.cp.headland.mode == courseGenerator.HEADLAND_MODE_NORMAL
	self.headlandDirection:setVisible( headlandFieldsVisible )
	self.headlandPasses:setVisible( headlandFieldsVisible )
	self.headlandFirst:setVisible( headlandFieldsVisible )
	self.headlandCorners:setVisible( headlandFieldsVisible )
end

function courseGeneratorScreen:onOpenHeadlandMode( element, parameter )
	local texts = {}
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_MODE_NONE' ))
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_MODE_NORMAL' ))
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_MODE_NARROW_FIELD' ))
	element:setTexts( texts )
	self:setHeadlandProperties()
	element:setState( self.vehicle.cp.headland.mode )
	self:setHeadlandFields()
end

function courseGeneratorScreen:onClickHeadlandMode( state )
	self.vehicle.cp.headland.mode = state
	self:setHeadlandProperties()
	self:setHeadlandFields()
end
-----------------------------------------------------------------------------------------------------
-- Headland passes
function courseGeneratorScreen:onOpenHeadlandPasses( element, parameter )
	local texts = {}
	for i = 1, self.vehicle.cp.headland.autoDirMaxNumLanes do
		table.insert( texts, tostring( i ))
	end
	element:setTexts( texts )
	element:setState( self.vehicle.cp.headland.getNumLanes())
end

function courseGeneratorScreen:onClickHeadlandPasses( state )
	self.vehicle.cp.headland.numLanes = state
end


-----------------------------------------------------------------------------------------------------
-- Headland direction
function courseGeneratorScreen:onOpenHeadlandDirection( element, parameter )
	local texts = {}
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_CLOCKWISE' ))
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_COUNTERCLOCKWISE' ))
	element:setTexts( texts )
	local state = self.vehicle.cp.headland.userDirClockwise and 1 or 2
	element:setState( state )
end

function courseGeneratorScreen:onClickHeadlandDirection( state )
	self.vehicle.cp.headland.userDirClockwise = state == 1
end

-----------------------------------------------------------------------------------------------------
-- Headland first
function courseGeneratorScreen:onOpenHeadlandFirst( element, parameter )
	local texts = {}
	table.insert( texts, courseplay:loc( 'COURSEPLAY_HEADLAND_PASSES' ))
	table.insert( texts, courseplay:loc( 'COURSEPLAY_UP_DOWN_ROWS' ))
	element:setTexts( texts )
	local state = self.vehicle.cp.headland.orderBefore and 1 or 2
	element:setState( state )
end

function courseGeneratorScreen:onClickHeadlandFirst( state )
	if state ~= self.vehicle.cp.headland.orderBefore then
		-- must call this in order to update the bitmap in the HUD, that is apparently not being taken care of by reload
		courseplay:toggleHeadlandOrder( self.vehicle )
	end
end

-----------------------------------------------------------------------------------------------------
-- Headland corner
function courseGeneratorScreen:onOpenHeadlandCorners( element, parameter )
	local texts = {}
	for i = 1, courseplay.HEADLAND_CORNER_TYPE_MAX do
		table.insert( texts, courseplay:loc( courseplay.cornerTypeText[ i ]))
	end
	element:setTexts( texts )
	element:setState( self.vehicle.cp.headland.turnType )
end

function courseGeneratorScreen:onClickHeadlandCorners( state )
	self.vehicle.cp.headland.turnType = state
end

-- this is called when the dynamic map gui element is rendered
function courseGeneratorScreen:drawDynamicMapImage(element)
	if g_currentMission and g_currentMission.ingameMap and g_currentMission.ingameMap.mapOverlay and
		g_currentMission.ingameMap.mapOverlay.filename and not self.mapOverlay then

		local ingameMap = g_currentMission.ingameMap
		-- zoom out completely
		ingameMap.mapVisWidthMin = 1
		ingameMap:setPosition(self.mapOverview.absPosition[1], self.mapOverview.absPosition[2])
		ingameMap:setSize(self.mapOverview.size[1], self.mapOverview.size[2])
		local leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached = ingameMap:drawMap(1)
		ingameMap:renderHotspots(leftBorderReached, rightBorderReached, topBorderReached, bottomBorderReached, false, true);
		-- course
		if self.vehicle.cp.course2dDrawData and false then
			local numPoints = #self.vehicle.cp.course2dDrawData;
			local r,g,b,a;
			for i,data in ipairs(self.vehicle.cp.course2dDrawData) do
				if not doLoop and i == numPoints then
					break;
				end;

				r,g,b,a = unpack(data.color);
				setOverlayColor(ingameMap.mapOverlay.overlayId, r,g,b,a);
				setOverlayRotation(ingameMap.mapOverlay.overlayId, data.rotation, 0, 0);
				renderOverlay(ingameMap.mapOverlay.overlayId, data.x, data.y, data.width, data.height);
			end;
			setOverlayRotation(ingameMap.mapOverlay.overlayId, 0, 0, 0); -- reset overlay rotation
		end
	end
end

function courseGeneratorScreen:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	if courseGeneratorScreen:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed) then
		eventUsed = true;
	end
	if  not eventUsed and isDown and button == Input.MOUSE_BUTTON_LEFT then
		eventUsed = true
		-- find the field under the cursor
		local ingameMap = g_currentMission.ingameMap
		local viewX, viewY = posX - self.mapOverview.absPosition[ 1 ], posY - self.mapOverview.absPosition[ 2 ]
		local viewW, viewH = self.mapOverview.size[ 1 ], self.mapOverview.size[ 2 ]
		local x = viewX * ingameMap.worldSizeX / viewW - ingameMap.worldCenterOffsetX
		local z = ingameMap.worldSizeZ - viewY * ingameMap.worldSizeZ / viewH - ingameMap.worldCenterOffsetZ
		local fieldNum = courseplay:getFieldNumForPosition( x, z )
		if fieldNum > 0 and self.fields then
			-- clicked on a field, set it as selected
			for i, field in ipairs( self.fields ) do
				if field.number == fieldNum then
					self.fieldSelector:setState( i )
					self.vehicle.cp.fieldEdge.selectedField.fieldNum = fieldNum
					return eventUsed
				end
			end
		end
	end
	return eventUsed
end