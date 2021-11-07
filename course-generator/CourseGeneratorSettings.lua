------------------------------------------------------------------------------------------------------------------------
-- Course Generator Settings
------------------------------------------------------------------------------------------------------------------------
---@class StartingLocationSetting : SettingList
StartingLocationSetting = CpObject(SettingList)

function StartingLocationSetting:init(vehicle)
	SettingList.init(self, 'startingLocation', 'COURSEPLAY_STARTING_LOCATION', '', vehicle,
		{
			courseGenerator.STARTING_LOCATION_VEHICLE_POSITION,
			courseGenerator.STARTING_LOCATION_SW,
			courseGenerator.STARTING_LOCATION_NW,
			courseGenerator.STARTING_LOCATION_NE,
			courseGenerator.STARTING_LOCATION_SE,
			courseGenerator.STARTING_LOCATION_SELECT_ON_MAP
		},
		{
			'COURSEPLAY_CORNER_5',
			'COURSEPLAY_CORNER_7',
			'COURSEPLAY_CORNER_8',
			'COURSEPLAY_CORNER_9',
			'COURSEPLAY_CORNER_10',
			'COURSEPLAY_CORNER_11'
		})
	self:update()
end

function StartingLocationSetting:update()
	-- only enable to select last location if we have one
	if self.lastVehiclePosition then
		if self.values[2] ~= courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION then
			table.insert(self.values, 2, courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION)
			table.insert(self.texts, 2, 'COURSEPLAY_CORNER_6')
		end
	elseif self.values[2] == courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION then
		table.remove(self.values, 2)
		table.remove(self.texts, 2)
	end
	-- if there's a GUI element assigned, make sure the selection list is up to date
	self:updateGuiElement()
end

-- the 'starting' location is really a starting location only when the course is started on the headland.
-- We always generate courses starting at the headland and only reverse it if the user wants to start it in
-- the middle of the field. Then this setting really means where the course will _end_, so adjust the label
-- accordingly.
function StartingLocationSetting:getLabel(startOnHeadland)
	local label = startOnHeadland and
		courseplay:loc('COURSEPLAY_STARTING_LOCATION') or
		courseplay:loc('COURSEPLAY_ENDING_LOCATION')
	return label
end

-- position selected on the map
function StartingLocationSetting:setSelectedPosition(x, z)
	self.worldPosition = { x = x, z = z }
end

function StartingLocationSetting:getSelectedPosition()
	if self.worldPosition == nil then
		-- make sure there's a position, just use the vehicle pos
		self.worldPosition = self:getVehiclePosition()
	end
	return self.worldPosition
end

function StartingLocationSetting:getVehiclePosition()
	local x, z
	x, _, z = getWorldTranslation(self.vehicle.rootNode)
	return { x = x, z = z }
end

function StartingLocationSetting:getLastVehiclePosition()
	return self.lastVehiclePosition or self:getVehiclePosition()
end

-- return a world position if last/current vehicle position or map position is selected
function StartingLocationSetting:getWorldPosition()
	if self:is(courseGenerator.STARTING_LOCATION_SELECT_ON_MAP) then
		courseplay.debugVehicle(courseplay.DBG_COURSES, self.vehicle, 'Starting location selected on map')
		return self:getSelectedPosition()
	elseif self:is(courseGenerator.STARTING_LOCATION_LAST_VEHICLE_POSITION) then
		courseplay.debugVehicle(courseplay.DBG_COURSES, self.vehicle, 'Starting location last vehicle position')
		return self:getLastVehiclePosition()
	elseif self:is(courseGenerator.STARTING_LOCATION_VEHICLE_POSITION) then
		courseplay.debugVehicle(courseplay.DBG_COURSES, self.vehicle, 'Starting location current vehicle position')
		self.lastVehiclePosition = self:getVehiclePosition()
		self:update()
		return self.lastVehiclePosition
	end
end

function StartingLocationSetting:saveToXml(xml, parentKey)
	SettingList.saveToXml(self, xml, parentKey)
	if self.lastVehiclePosition then
		setXMLFloat(xml, self:getElementKey(parentKey) .. '#x', Utils.getNoNil(self.lastVehiclePosition.x, 0))
		setXMLFloat(xml, self:getElementKey(parentKey) .. '#z', Utils.getNoNil(self.lastVehiclePosition.z, 0))
	end
end

function StartingLocationSetting:loadFromXml(xml, parentKey)
	local x = getXMLFloat(xml, self:getElementKey(parentKey) .. '#x')
	local z = getXMLFloat(xml, self:getElementKey(parentKey) .. '#z')
	if x and z then
		self.lastVehiclePosition = { x = x, z = z }
	end
	-- need to update first so if there's a position we first add that option to the value list before loading from XML
	self:update()
	SettingList.loadFromXml(self, xml, parentKey)
end

--- A working width setting, which is a float, viewed in a MultiTextOption GUI control. The multi text box has the
--- current value +- increment, 3 values at any time and we update it when
---@class WorkWidthSetting : SettingList
WorkWidthSetting = CpObject(SettingList)
WorkWidthSetting.WidthFormatString = '%.1f m'
WorkWidthSetting.Increment = 0.1

function WorkWidthSetting:init(vehicle)
	SettingList.init(self, 'workWidth', 'COURSEPLAY_WORK_WIDTH', 'COURSEPLAY_WORK_WIDTH', vehicle)
	self.value = FloatSetting('workWidth', 'COURSEPLAY_WORK_WIDTH', 'COURSEPLAY_WORK_WIDTH', vehicle, 0)
	self.automaticValue = FloatSetting('automaticWorkWidth',nil,nil,vehicle,0)
	self.minWidth, self.maxWidth = 1, 50
	-- do not attempt to send an event from the constructor as at that point, the vehicle is not completely ready
	-- and parentName is not set.
	-- TODO: move creating the course gen (or others too?) settings to onPostLoad() (instead of onLoad())
	-- TODO: add parentName to the constructor of the settings instead of the explicit setter.
	self:refresh()
	self.WORK_WIDTH_EVENT = self:registerFloatEvent(self.setWorkWidthFromNetwork)
	self.AUTO_WORK_WIDTH_EVENT = self:registerFloatEvent(self.setAutoWorkWidthFromNetwork)
	if g_server then
		self:updateAutoWorkWidth()
		self:setToDefault(true)
	end
	self.loaded = false
end

--- The saved value gets applied, before all implements are attached.
--- So only allow automatic changes after all implements are attached on savegame start.
function WorkWidthSetting:postInit()
	self.loaded = true
end

function WorkWidthSetting:loadFromXml(xml, parentKey)
	self.value:loadFromXml(xml, parentKey)
	self:updateGuiElement()
end

function WorkWidthSetting:saveToXml(xml, parentKey)
	self.value:saveToXml(xml, parentKey)
end

function WorkWidthSetting:onWriteStream(stream)
	self.value:onWriteStream(stream)
	self.automaticValue:onWriteStream(stream)
end

function WorkWidthSetting:onReadStream(stream)
	self.value:onReadStream(stream)
	self.automaticValue:onReadStream(stream)
	self:updateGuiElement()
end

function WorkWidthSetting:refresh()
	self.texts = {}
	self.values = {}
	-- have at most 3 values in the text box around the selected (sliding window around the current value)
	if self.value:get() > self.minWidth then
		table.insert(self.values, self.value:get() - WorkWidthSetting.Increment)
		table.insert( self.texts, string.format(WorkWidthSetting.WidthFormatString, self.value:get() - WorkWidthSetting.Increment))
	end
	table.insert(self.values, self.value:get())
	table.insert(self.texts, string.format(WorkWidthSetting.WidthFormatString, self.value:get()))
	if self.value:get() < self.maxWidth then
		table.insert(self.values, self.value:get() + WorkWidthSetting.Increment)
		table.insert( self.texts, string.format(WorkWidthSetting.WidthFormatString, self.value:get() + WorkWidthSetting.Increment))
	end
end

function WorkWidthSetting:updateGuiElement()
	self:refresh()
	if self.guiElement then
		self.guiElement:setTexts(self:getGuiElementTexts())
		if self.value:is(self.minWidth) then
			self.guiElement:setState(1)
		else
			self.guiElement:setState(2)
		end
	end
end

function WorkWidthSetting:setFromGuiElement()
	if self.guiElement then
		self:set(self.values[self.guiElement:getState()])
	end
end

function WorkWidthSetting:setToDefault(noEventSend)
	local autoWidth = self:getAutoWorkWidth()
	if autoWidth > 0 then
		self:set(autoWidth, noEventSend)
	end
end

function WorkWidthSetting:set(value, noEventSend)
	self.value:set(value, noEventSend)
	if noEventSend == nil or noEventSend == false then
		self:sendWorkWidthEvent(value)
	end
	self:updateGuiElement()
end

-- override SettingList sendEvent() for setting the float value from the list
function WorkWidthSetting:sendWorkWidthEvent(value)
	self:raiseEvent(self.WORK_WIDTH_EVENT,value)
end

-- override SettingList sendEvent() for setting the float auto work width
function WorkWidthSetting:sendAutoWorkWidthEvent(value)
	self:raiseEvent(self.AUTO_WORK_WIDTH_EVENT,value)
end

function WorkWidthSetting:setWorkWidthFromNetwork(value)
	self.value:set(value,true)
end

function WorkWidthSetting:setAutoWorkWidthFromNetwork(value)
	self.automaticValue:set(value,true)
	self.value:set(value,true)
end

function WorkWidthSetting:setNext()
	self:set(math.min(self.value:get() + WorkWidthSetting.Increment, self.maxWidth))
end

function WorkWidthSetting:setPrevious()
	self:set(math.max(self.value:get() - WorkWidthSetting.Increment, self.minWidth))
end

--- This is needed as the client can't retrieve it directly,
--- so we update it on a attach/detach of an implement and 
--- send the changed value with an event to the client.
function WorkWidthSetting:updateAutoWorkWidth()
	if g_server == nil then return end
	local value = WorkWidthUtil.getAutomaticWorkWidth(self.vehicle) or 0
	self.automaticValue:set(value,true)
	if self.loaded then
		self.value:set(value,true)
	end
	self:refresh()
	self:sendAutoWorkWidthEvent(value)
end

function WorkWidthSetting:getAutoWorkWidth()
	return self.automaticValue:get()
end

function WorkWidthSetting:changeByX(x)
	if x>0 then 
		self:setNext()
	else 
		self:setPrevious()
	end
	self:onChange()
end

function WorkWidthSetting:onChange()
	courseplay:setCustomTimer(self.vehicle, 'showWorkWidth', 2);
end

--- Course gen center mode setting
---@class CenterModeSetting : SettingList
CenterModeSetting = CpObject(SettingList)

function CenterModeSetting:init(vehicle)
	SettingList.init(self, 'centerMode', 'COURSEPLAY_CENTER_MODE', '', vehicle,
		{
			courseGenerator.CENTER_MODE_UP_DOWN,
			courseGenerator.CENTER_MODE_CIRCULAR,
			courseGenerator.CENTER_MODE_SPIRAL,
			courseGenerator.CENTER_MODE_LANDS
		},
		{
			'COURSEPLAY_CENTER_MODE_UP_DOWN',
			'COURSEPLAY_CENTER_MODE_CIRCULAR',
			'COURSEPLAY_CENTER_MODE_SPIRAL',
			'COURSEPLAY_CENTER_MODE_LANDS'
		})
end

--- Number of rows per land in Lands center mode
---@class NumberOfRowsPerLand
NumberOfRowsPerLandSetting = CpObject(SettingList)

function NumberOfRowsPerLandSetting:init(vehicle)
	SettingList.init(self, 'numberOfRowsPerLand', 'COURSEPLAY_NUMBER_OF_ROWS_PER_LAND',
		'COURSEPLAY_NUMBER_OF_ROWS_PER_LAND_TOOLTIP', vehicle,
		{ 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24 },
		{ 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24 })
	self:set(6)
end

--- Percentage of Overlap for Headland
---@class HeadlandOverlapPercent
HeadlandOverlapPercent = CpObject(SettingList)

function HeadlandOverlapPercent:init(vehicle)
	local values, texts = {}, {}
	for i = 0, 20 do
		table.insert(values, i)
		table.insert(texts, string.format('%d %%', i))
	end
	SettingList.init(self, 'headlandOverlapPercent', 'COURSEPLAY_HEADLAND_OVERLAP_PERCENT',
		'COURSEPLAY_HEADLAND_OVERLAP_PERCENT_TOOLTIP', vehicle,
		values, texts)
	-- reasonable default used for years
	self:set(7)
end

---@class ShowSeedCalculatorSetting : BooleanSetting
ShowSeedCalculatorSetting = CpObject(BooleanSetting)
function ShowSeedCalculatorSetting:init(vehicle)
	BooleanSetting.init(self, 'showSeedCalculator', 'COURSEPLAY_SEEDUSAGECALCULATOR', 'COURSEPLAY_SEEDUSAGECALCULATOR', vehicle)
	self:set(false)
end

--- Selected Field
---@class SelectedFieldSetting : FieldNumberSetting
SelectedFieldSetting = CpObject(FieldNumberSetting)
function SelectedFieldSetting:init(vehicle)
	FieldNumberSetting.init(self, 'selectedField', 'COURSEPLAY_FIELD_EDGE_PATH', 'COURSEPLAY_FIELD_EDGE_PATH', vehicle)
	self:addCurrentlyLoaded()
end

function SelectedFieldSetting:addCurrentlyLoaded()
	-- add the option to select the currently loaded course as a field boundary for the generation
	table.insert(self.texts, courseplay:loc('COURSEPLAY_CURRENTLY_LOADED_COURSE'))
	table.insert(self.values, 0)
end

function SelectedFieldSetting:refresh()
	local current = self.current
	FieldNumberSetting.refresh(self)
	self:addCurrentlyLoaded()
	self.current = math.min(current, #self.values)
	-- if there's a GUI element assigned, make sure the selection list is up to date
	self:updateGuiElement()
end

---@class RowDirectionSetting : SettingList
RowDirectionSetting = CpObject(SettingList)
function RowDirectionSetting:init(vehicle)
	SettingList.init(self, 'rowDirection',
		'COURSEPLAY_STARTING_DIRECTION', 'COURSEPLAY_STARTING_DIRECTION', vehicle,
		{
			courseGenerator.ROW_DIRECTION_NORTH,
			courseGenerator.ROW_DIRECTION_EAST,
			courseGenerator.ROW_DIRECTION_SOUTH,
			courseGenerator.ROW_DIRECTION_WEST,
			courseGenerator.ROW_DIRECTION_AUTOMATIC,
			courseGenerator.ROW_DIRECTION_LONGEST_EDGE,
			courseGenerator.ROW_DIRECTION_MANUAL
		},
		{
			'COURSEPLAY_DIRECTION_1',
			'COURSEPLAY_DIRECTION_2',
			'COURSEPLAY_DIRECTION_3',
			'COURSEPLAY_DIRECTION_4',
			'COURSEPLAY_DIRECTION_5',
			'COURSEPLAY_DIRECTION_6',
			'COURSEPLAY_DIRECTION_7',
		})
	self:set(courseGenerator.ROW_DIRECTION_AUTOMATIC)
end

---@class ManualRowAngleSetting : SettingList
ManualRowAngleSetting = CpObject(SettingList)

function ManualRowAngleSetting:init(vehicle)
	-- as values, we store the angle (in radians) as used in waypoints for instance. This is not the compass angle
	-- on the map!
	self.values = {}
	self.texts = {}
	for gameAngleDeg = 0, 180, 5 do
		table.insert(self.values, math.rad(gameAngleDeg))
		table.insert(self.texts, tostring(courseGenerator.getCompassAngleDeg(gameAngleDeg)) .. '°' ..
			' (' .. courseplay:loc( courseGenerator.getCompassDirectionText(gameAngleDeg)) .. ')')
	end

	SettingList.init(self, 'manualRowAngle', 'COURSEPLAY_DIRECTION_7', 'COURSEPLAY_DIRECTION_7',
		vehicle, self.values, self.texts)
end

---@class RowsToSkipSetting : SettingList
RowsToSkipSetting = CpObject(SettingList)

function RowsToSkipSetting:init(vehicle)
	self.values = {0, 1, 2, 3}
	self.texts = {'0', '1', '2', '3'}
	SettingList.init(self, 'rowsToSkip', 'COURSEPLAY_SKIP_ROWS', 'COURSEPLAY_SKIP_ROWS',
		vehicle, self.values, self.texts)
end

---@class MultiToolsSetting : SettingList
MultiToolsSetting = CpObject(SettingList)
MultiToolsSetting.MAX_DRIVERS = 8
function MultiToolsSetting:init(vehicle)
	self.values = {}
	self.texts = {}
	for i = 1, self.MAX_DRIVERS do
		table.insert(self.values, i)
		table.insert(self.texts, i)
	end
	SettingList.init(self, 'multiTools', 'COURSEPLAY_MULTI_TOOLS', 'COURSEPLAY_MULTI_TOOLS',
		vehicle, self.values, self.texts)
	self.laneNumber = LaneNumberSetting(vehicle,self)
	self.LANE_NUMBER_EVENT = self:registerIntEvent(self.setLaneNumberFromNetwork)
end

function MultiToolsSetting:loadFromXml(xml,parentKey)
	SettingList.loadFromXml(self,xml,parentKey)
	self.laneNumber:loadFromXml(xml,parentKey)
end
function MultiToolsSetting:saveToXml(xml,parentKey)
	SettingList.saveToXml(self,xml,parentKey)
	self.laneNumber:saveToXml(xml,parentKey)
end

function MultiToolsSetting:onReadStream(streamId)
	SettingList.onReadStream(self,streamId)
	self.laneNumber:onReadStream(streamId)
	
end
function MultiToolsSetting:onWriteStream(streamId)
	SettingList.onWriteStream(self,streamId)
	self.laneNumber:onWriteStream(streamId)
end

function MultiToolsSetting:setLaneNumberFromNetwork(value)
	self.laneNumber:set(value)
end

function MultiToolsSetting:changeLaneNumber(changeBy,noEventSend)
	self.laneNumber:changeByX(changeBy)
	if noEventSend == nil or noEventSend == false then
		self:raiseEvent(self.LANE_NUMBER_EVENT,self.laneNumber:get())
	end
end

function MultiToolsSetting:onChange()
	self.laneNumber:refresh(self:get())
	-- TODO: consolidate the (poorly named) laneNumber and laneOffset and this into a single setting as they
	-- can only change together (instead of having logic all over the place according to the good old CP practices)
	if self:get() % 2 == 0 then
		self.laneNumber:set(1)
	else
		self.laneNumber:set(0)
	end
end

---@class LaneNumberSetting : SettingList
LaneNumberSetting = CpObject(SettingList)
function LaneNumberSetting:init(vehicle,multiToolsSetting)
	self.multiToolsSetting = multiToolsSetting
	self:refresh(multiToolsSetting:get())
	SettingList.init(self, 'laneNumber', 'COURSEPLAY_LANE_OFFSET', 'COURSEPLAY_LANE_OFFSET',
		vehicle, self.values, self.texts)
end

function LaneNumberSetting:refresh(numDrivers)
	local evenNumOfDrivers = numDrivers % 2 == 0
	local maxLeft,maxRight = self:getMaxValues(numDrivers)
	self.texts = {}
	self.values = {}
	for i = maxLeft, maxRight do
		if not evenNumOfDrivers or i ~= 0 and evenNumOfDrivers then 
			table.insert(self.values, i)
			local text = ""
			if i>0 then 
				text = string.format("%d %s",i,courseplay:loc('COURSEPLAY_RIGHT'))
			elseif i<0 then 
				text = string.format("%d %s",i,courseplay:loc('COURSEPLAY_LEFT'))
			else 
				text = courseplay:loc('COURSEPLAY_CENTER')
			end
			table.insert(self.texts, text)
		end
	end
end

function LaneNumberSetting:getMaxValues(numDrivers)
	local maxRight = math.floor(numDrivers/2)
	return -maxRight,maxRight
end

---@class IslandBypassModeSetting : SettingList
IslandBypassModeSetting = CpObject(SettingList)

function IslandBypassModeSetting:init(vehicle)
	self.values = {
		Island.BYPASS_MODE_NONE,
		Island.BYPASS_MODE_SIMPLE,
		Island.BYPASS_MODE_CIRCLE
	}

	self.texts = {
		'COURSEPLAY_ISLAND_BYPASS_MODE_NONE',
		'COURSEPLAY_ISLAND_BYPASS_MODE_SIMPLE',
		'COURSEPLAY_ISLAND_BYPASS_MODE_CIRCLE'
	}
	SettingList.init(self, 'islandBypassMode', 'COURSEPLAY_BYPASS_ISLANDS', 'COURSEPLAY_BYPASS_ISLANDS',
		vehicle, self.values, self.texts)
end

---@class HeadlandModeSetting : SettingList
HeadlandModeSetting = CpObject(SettingList)

function HeadlandModeSetting:init(vehicle)
	self.values = {
		courseGenerator.HEADLAND_MODE_NONE,
		courseGenerator.HEADLAND_MODE_NORMAL,
		courseGenerator.HEADLAND_MODE_NARROW_FIELD,
		courseGenerator.HEADLAND_MODE_TWO_SIDE
	}
	self.texts = {
		'COURSEPLAY_HEADLAND_MODE_NONE',
		'COURSEPLAY_HEADLAND_MODE_NORMAL',
		'COURSEPLAY_HEADLAND_MODE_NARROW_FIELD',
		'COURSEPLAY_HEADLAND_MODE_TWO_SIDE'
	}
	SettingList.init(self, 'headlandMode', 'COURSEPLAY_HEADLAND', 'COURSEPLAY_HEADLAND',
		vehicle, self.values, self.texts)
end

---@class HeadlandDirectionSetting : SettingList
HeadlandDirectionSetting = CpObject(SettingList)

function HeadlandDirectionSetting:init(vehicle)
	self.values = {
		courseGenerator.HEADLAND_CLOCKWISE,
		courseGenerator.HEADLAND_COUNTERCLOCKWISE,
	}
	self.texts = {
		'COURSEPLAY_HEADLAND_CLOCKWISE',
		'COURSEPLAY_HEADLAND_COUNTERCLOCKWISE',
	}
	SettingList.init(self, 'headlandDirection',
		'COURSEPLAY_HEADLAND_DIRECTION', 'COURSEPLAY_HEADLAND_DIRECTION',
		vehicle, self.values, self.texts)
end

---@class HeadlandCornerTypeSetting : SettingList
HeadlandCornerTypeSetting = CpObject(SettingList)

function HeadlandCornerTypeSetting:init(vehicle)
	self.values = {
		courseGenerator.HEADLAND_CORNER_TYPE_SMOOTH,
		courseGenerator.HEADLAND_CORNER_TYPE_SHARP,
		courseGenerator.HEADLAND_CORNER_TYPE_ROUND
	}
	self.texts = {
		'COURSEPLAY_HEADLAND_CORNER_TYPE_SMOOTH',
		'COURSEPLAY_HEADLAND_CORNER_TYPE_SHARP',
		'COURSEPLAY_HEADLAND_CORNER_TYPE_ROUND'
	}
	SettingList.init(self, 'headlandCornerType',
		'COURSEPLAY_HEADLAND_CORNERS', 'COURSEPLAY_HEADLAND_CORNERS',
		vehicle, self.values, self.texts)
end


---@class StartOnHeadlandSetting : SettingList
StartOnHeadlandSetting = CpObject(SettingList)

function StartOnHeadlandSetting:init(vehicle)
	self.values = {
		courseGenerator.HEADLAND_START_ON_HEADLAND,
		courseGenerator.HEADLAND_START_ON_UP_DOWN_ROWS,
	}
	self.texts = {
		'COURSEPLAY_HEADLAND_PASSES',
		'COURSEPLAY_UP_DOWN_ROWS',
	}
	SettingList.init(self, 'startOnHeadland',
		'COURSEPLAY_START_WORKING_ON', 'COURSEPLAY_START_WORKING_ON',
		vehicle, self.values, self.texts)
end

--- Number of headland passes
---@class HeadlandPassesSetting : SettingList
HeadlandPassesSetting = CpObject(SettingList)

function HeadlandPassesSetting:init(vehicle)
	self.values = {}
	self.texts = {}
	for i = 1, 50 do
		table.insert(self.values, i)
		table.insert(self.texts, i)
	end
	SettingList.init(self, 'headlandPasses', 'COURSEPLAY_HEADLAND_PASSES', 'COURSEPLAY_HEADLAND_PASSES',
		vehicle, self.values, self.texts)
end

---@class FieldEdgePathSetting : IntSetting
FieldEdgePathSetting = CpObject(IntSetting)
FieldEdgePathSetting.EMPTY = 0
FieldEdgePathSetting.MAX_FIELDS = 250
function FieldEdgePathSetting:init(vehicle,selectedFieldSetting)
	self.selectedFieldSetting = selectedFieldSetting
	IntSetting.init(self,"fieldEdgePath","","",vehicle,0,self.MAX_FIELDS,self.EMPTY)
	self.visible = false
	self.customFieldPath = nil
	self.currentFieldNumExists = false
	-- All the labels, tooltips.
	self.labels = {
		["create"] = courseplay:loc('COURSEPLAY_SCAN_CURRENT_FIELD_EDGES'),
		["currentNr"] = courseplay:loc('COURSEPLAY_CURRENT_FIELD_EDGE_PATH_NUMBER'),
		["overwritePath"] = courseplay:loc('COURSEPLAY_OVERWRITE_CUSTOM_FIELD_EDGE_PATH_IN_LIST'),
		["addNewPath"] = courseplay:loc('COURSEPLAY_ADD_CUSTOM_FIELD_EDGE_PATH_TO_LIST'),
		["clear"] = courseplay:loc('COURSEPLAY_CLEAR_CUSTOM_FIELD_EDGE_PATH'),
		["visibility"] =  courseplay:loc('COURSEPLAY_CHANGE_VISIBILITY_CUSTOM_FIELD_EDGE_PATH'),
	}
end

--- After a change, check if the current selected field is already existing.
function FieldEdgePathSetting:onChange()
	local value = self:get() 
	if value > 0 then 
		self.currentFieldNumExists = CpFieldUtil.isFieldNumberValid(value)
	end
end

--- Generates a new field edge path.
function FieldEdgePathSetting:createPath()
	if not self.customFieldPath then
		local customField = CpFieldUtil.generateCustomFieldEdgePath(self.vehicle)
		if customField.numPoints > 0 then 
			self.customFieldPath = customField
			self.visible = true
		end
	end
end

--- Converts a generated field edge path to a field and saves it.
function FieldEdgePathSetting:savePath()
	if self.customFieldPath ~= nil then 
		local field = CpFieldUtil.saveCustomFieldEdgePathAsField(self.customFieldPath,self:get())
		self:sendEvent(field)
		self:clearPath()
	end
end

---@param field table
function FieldEdgePathSetting:sendEvent(field)
	CustomFieldEvent.sendEvent(field)
end

--- Clears the generated field edge path-
function FieldEdgePathSetting:clearPath()
	self.customFieldPath = nil 
	self.visible = false
	self.currentFieldNumExists = false
	self:set(self.EMPTY,true)
end

--- Changes the visibility of a generated field edge path.
function FieldEdgePathSetting:toggleVisibility()
	if self.customFieldPath then
		self.visible = not self.visible
	end
end

--- Is a field edge path generated ?
function FieldEdgePathSetting:hasUnsavedCustomFieldPath()
	return self.customFieldPath~=nil
end

--- Is the field number ~=0 ?
function FieldEdgePathSetting:isValidNumber()
	return self:get() ~= self.EMPTY
end

--- Is the generated field edge visible ?
function FieldEdgePathSetting:isUnsavedCustomFieldPathVisible()
	return self:hasUnsavedCustomFieldPath() and self.visible
end

--- Displays the generated field edge path.
function FieldEdgePathSetting:showCustomFieldEdgePath()
	if self:isUnsavedCustomFieldPathVisible() then 
		CpFieldUtil.showFieldEdgePath(self.vehicle,self.customFieldPath)
	end
end

function FieldEdgePathSetting:isDisabled()
	return self.vehicle:getIsCourseplayDriving() 
	or self.vehicle.cp.canDrive
	or self.vehicle.cp.isRecording 
	or self.vehicle.cp.recordingIsPaused
end

function FieldEdgePathSetting:getCreateLabel()
	return self.labels.create
end

function FieldEdgePathSetting:getCurrentNrLabel()
	return self.labels.currentNr
end

function FieldEdgePathSetting:getClearLabel()
	return self.labels.clear
end

function FieldEdgePathSetting:getVisibilityLabel()
	return self.labels.visibility
end

--- This is a tooltip for the save button.
--- The text changes if the field is already generated or not.
function FieldEdgePathSetting:getSaveLabel()
	local str = self.currentFieldNumExists and self.labels.overwritePath or self.labels.addNewPath
	return self:isValidNumber() and string.format(str,self:get()) or ""
end

function FieldEdgePathSetting:isSyncAllowed()
	return false
end	

function FieldEdgePathSetting:getText()
	if not self:isValidNumber() then 
		return "---"
	end
	return CpFieldUtil.getFieldName(self:get())	or IntSetting.getText(self)
end

--- Global course generator settings (read from the XML, may be added to the UI later when needed):
---
--- Minimum radius in meters where a lane change on the headland is allowed. This is to ensure that
--- we only change lanes on relatively straight sections of the headland (not around corners)
---@class HeadlandLaneChangeMinRadius
HeadlandLaneChangeMinRadius = CpObject(IntSetting)

function HeadlandLaneChangeMinRadius:init()
	IntSetting.init(self, 'headlandLaneChangeMinRadius', 'HeadlandLaneChangeMinRadius',
		'Minimum radius where a lane change on the headland is allowed')
	self:set(20)
end

--- No lane change allowed on the headland if there is a corner ahead within this distance in meters
---@class HeadlandLaneChangeMinDistanceToCorner
HeadlandLaneChangeMinDistanceToCorner = CpObject(IntSetting)
function HeadlandLaneChangeMinDistanceToCorner:init()
	IntSetting.init(self, 'headlandLaneChangeMinDistanceToCorner', 'HeadlandLaneChangeMinDistanceToCorner',
		'Minimum distance to a corner for a lane change on the headland')
	self:set(20)
end

--- No lane change allowed on the headland if there is a corner behind within this distance in meters
---@class HeadlandLaneChangeMinDistanceFromCorner
HeadlandLaneChangeMinDistanceFromCorner = CpObject(IntSetting)
function HeadlandLaneChangeMinDistanceFromCorner:init()
	IntSetting.init(self, 'headlandLaneChangeMinDistanceFromCorner', 'HeadlandLaneChangeMinDistanceFromCorner',
		'Minimum distance from a corner for a lane change on the headland')
	self:set(10)
end

---@class CourseGeneratorSettingsContainer : SettingsContainer
CourseGeneratorSettingsContainer = CpObject(SettingsContainer)

function CourseGeneratorSettingsContainer:init()
	-- store everything under courseGenerator
	SettingsContainer.init(self, 'courseGeneratorSettings')
end

function CourseGeneratorSettingsContainer:saveToXML(xml, parentKey)
	SettingsContainer.saveToXML(self, xml, parentKey .. '.' .. self.name)
end

function CourseGeneratorSettingsContainer:loadFromXML(xml, parentKey)
	SettingsContainer.loadFromXML(self, xml, parentKey .. '.' .. self.name)
end

function SettingsContainer.createCourseGeneratorSettings(vehicle)
	local container = CourseGeneratorSettingsContainer()
	container:addSetting(SelectedFieldSetting, vehicle)
	container:addSetting(StartingLocationSetting, vehicle)
	container:addSetting(RowDirectionSetting, vehicle)
	container:addSetting(ManualRowAngleSetting, vehicle)
	container:addSetting(RowsToSkipSetting, vehicle)
	container:addSetting(MultiToolsSetting, vehicle)
	container:addSetting(WorkWidthSetting, vehicle)
	container:addSetting(NumberOfRowsPerLandSetting, vehicle)
	container:addSetting(HeadlandModeSetting, vehicle)
	container:addSetting(HeadlandPassesSetting, vehicle)
	container:addSetting(HeadlandDirectionSetting, vehicle)
	container:addSetting(HeadlandCornerTypeSetting, vehicle)
	container:addSetting(StartOnHeadlandSetting, vehicle)
	container:addSetting(CenterModeSetting, vehicle)
	container:addSetting(IslandBypassModeSetting, vehicle)
	container:addSetting(HeadlandOverlapPercent, vehicle)
	container:addSetting(ShowSeedCalculatorSetting, vehicle)
	container:addSetting(FieldEdgePathSetting,vehicle,container.selectedField)
	return container
end

function SettingsContainer.createGlobalCourseGeneratorSettings()
	local container = SettingsContainer('globalCourseGeneratorSettings')
	container:addSetting(HeadlandLaneChangeMinRadius)
	container:addSetting(HeadlandLaneChangeMinDistanceToCorner)
	container:addSetting(HeadlandLaneChangeMinDistanceFromCorner)
	return container
end