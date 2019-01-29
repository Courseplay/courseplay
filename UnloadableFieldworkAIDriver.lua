--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2018 Peter Vajko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

--[[
Fieldwork AI Driver for harvesting vehicles which need to unload material to continue

Also known as mode 6.

]]

---@class UnloadableFieldworkAIDriver : FieldworkAIDriver
UnloadableFieldworkAIDriver = CpObject(FieldworkAIDriver)
-- at which fill level we need to unload. We want to have a little buffer there
-- as we won't raise our implements until we stopped and during that time we keep
-- harvesting
UnloadableFieldworkAIDriver.fillLevelFullPercentage = 99.5
-- at which fill level we consider ourselves unloaded
UnloadableFieldworkAIDriver.fillLevelEmptyPercentage = 0.1


-- chopper: 0= pipe folded (really? isn't this 1?), 2,= autoaiming;  combine: 1 = closed  2= open
UnloadableFieldworkAIDriver.PIPE_STATE_MOVING = 0
UnloadableFieldworkAIDriver.PIPE_STATE_CLOSED = 1
UnloadableFieldworkAIDriver.PIPE_STATE_OPEN = 2

function UnloadableFieldworkAIDriver:init(vehicle)
	FieldworkAIDriver.init(self, vehicle)
	self:initStates(UnloadableFieldworkAIDriver.myStates)
	self.mode = courseplay.MODE_FIELDWORK
end

function UnloadableFieldworkAIDriver:drive(dt)
	-- only reason we need this is to update the totalFillLevel for reverse.lua so it will
	-- do a raycast for tip triggers
	courseplay:updateFillLevelsAndCapacities(self.vehicle)
	-- handle the pipe in any state
	self:handlePipe()
	-- the rest is the same as the parent class
	FieldworkAIDriver.drive(self, dt)
end

--- Grain tank full during fieldwork
function UnloadableFieldworkAIDriver:changeToFieldworkUnloadOrRefill()
	self:debug('change to fieldwork unload')
	if not self.heldForUnloadRefill then
		self:setInfoText('NEEDS_UNLOADING')
	end
	FieldworkAIDriver.changeToFieldworkUnloadOrRefill(self)
end

---@return boolean true if unload took over the driving
function UnloadableFieldworkAIDriver:driveUnloadOrRefill(dt)
	self:updateOffset()
	if not self.ppc:isReversing() then
		-- 'cause reverse does the raycasting for us
		self:searchForTipTriggers()
	end
	local takeOverSteering = FieldworkAIDriver.driveUnloadOrRefill(self)
	if self.vehicle.cp.totalFillLevel > 0 then
		local allowedToDrive = true
		if self:hasTipTrigger() then
			-- unload at tip trigger
			allowedToDrive, takeOverSteering = courseplay:unload_tippers(self.vehicle, allowedToDrive);
			courseplay:setInfoText(self.vehicle, "COURSEPLAY_TIPTRIGGER_REACHED");
			self:setSpeed(self.vehicle.cp.speeds.turn)
		elseif self:atUnloadWaypoint() then
			-- unload at unload waypoint
			-- TODO: does not work due to #163009151, for now, just stop
			allowedToDrive = false
--			allowedToDrive, takeOverSteering =
--			courseplay:handleUnloading(self.vehicle, self.course:isReverseAt(self.ppc:getCurrentWaypointIx()),dt);
		end
		if not allowedToDrive then
			self:setSpeed(0)
		end
	end
	return takeOverSteering
end

function UnloadableFieldworkAIDriver:hasTipTrigger()
	return self.vehicle.cp.currentTipTrigger ~= nil
end

function UnloadableFieldworkAIDriver:handlePipe()
	if self.vehicle.spec_pipe then
		if self.vehicle.cp.isChopper then
			self:handleChopperPipe()
		else
			self:handleCombinePipe()
		end
	end
end

function UnloadableFieldworkAIDriver:handleCombinePipe()
	if self:isFillableTrailerUnderPipe() then
		self:openPipe()
	else
		self:closePipe()
	end
end

function UnloadableFieldworkAIDriver:handleChopperPipe()
	if self.state == self.states.ON_FIELDWORK_COURSE then
		-- chopper always opens the pipe
		self:openPipe()
		-- and stops if there's no trailer in sight
		local spec = self.vehicle.spec_combine
		local fillLevel = self.vehicle:getFillUnitFillLevel(spec.fillUnitIndex)
		--self:debug('filltype = %s, fillLevel = %.1f', self:getFillType(), fillLevel)
		-- not using isFillableTrailerUnderPipe() as the chopper sometimes has FillType.UNKNOWN
		if fillLevel > 0.01 and self:getFillType() ~= FillType.UNKNOWN and not self:isFillableTrailerUnderPipe() then
			self:debugSparse('Chopper waiting for trailer, fill level %f', fillLevel)
			self:setSpeed(0)
		end
	else
		self:closePipe()
	end
end

function UnloadableFieldworkAIDriver:openPipe()
	if self.vehicle.spec_pipe.currentState ~= UnloadableFieldworkAIDriver.PIPE_STATE_MOVING and
		self.vehicle.spec_pipe.currentState ~= UnloadableFieldworkAIDriver.PIPE_STATE_OPEN then
		self:debug('Opening pipe')
		self.vehicle.spec_pipe:setPipeState(self.PIPE_STATE_OPEN)
	end
end

function UnloadableFieldworkAIDriver:closePipe()
	if self.vehicle.spec_pipe.currentState ~= UnloadableFieldworkAIDriver.PIPE_STATE_MOVING and
		self.vehicle.spec_pipe.currentState ~= UnloadableFieldworkAIDriver.PIPE_STATE_CLOSED then
		self:debug('Closing pipe')
		self.vehicle.spec_pipe:setPipeState(self.PIPE_STATE_CLOSED)
	end
end

-- is the fill level ok to continue? With unloadable tools we need to stop working when the tool is full
-- with fruit
function UnloadableFieldworkAIDriver:isLevelOk(workTool, index, fillUnit)
	local pc = 100 * workTool:getFillUnitFillLevelPercentage(index)
	if courseplay:isBaler(workTool) then
		self:handleBalers(workTool)
		return true
	end
	local fillTypeName = g_fillTypeManager:getFillTypeNameByIndex(fillUnit.fillType)
	if self.state == self.states.ON_FIELDWORK_COURSE and
		self.fieldworkState == self.states.UNLOAD_OR_REFILL_ON_FIELD and
		self.fieldWorkUnloadOrRefillState == self.states.WAITING_FOR_UNLOAD_OR_REFILL and
		self.vehicle.cp.stopWhenUnloading then
		if self:isValidFillType(fillUnit.fillType) and pc > self.fillLevelEmptyPercentage then
			self:debugSparse('Not unloaded yet: %s: %.1f', fillTypeName, pc )
			return false
		end
	else
		if self:isValidFillType(fillUnit.fillType) and pc > self.fillLevelFullPercentage then
			self:debugSparse('Full: %s: %.1f', fillTypeName, pc )
			return false
		end
	end
	self:debugSparse('Fill levels: %s: %.1f', fillTypeName, pc )
	return true
end

function UnloadableFieldworkAIDriver:isFillableTrailerUnderPipe()
	local canLoad = false
	if self.vehicle.spec_pipe then
		for trailer, value in pairs(self.vehicle.spec_pipe.objectsInTriggers) do
			if value > 0 then
				local fillType = self:getFillType()
				--self:debug('ojects = %d, fillType = %s fus=%s', value, tostring(fillType), tostring(trailer:getFillUnits()))
				if fillType then
					local fillUnits = trailer:getFillUnits()
					for i=1, #fillUnits do
						local supportedFillTypes = trailer:getFillUnitSupportedFillTypes(i)
						if supportedFillTypes[fillType] and trailer:getFillUnitFreeCapacity(i) > 0 then
							canLoad = true
						end
					end
				end
			end
		end
	end
	return canLoad
end

--- Check fill levels in all tools and stop when one of them isn't
-- ok (empty or full, depending on the derived class)
function UnloadableFieldworkAIDriver:getFillType()
	if not self.vehicle.cp.workTools then return end
	for _, workTool in pairs(self.vehicle.cp.workTools) do
		if workTool.getFillUnits then
			for _, fillUnit in pairs(workTool:getFillUnits()) do
				if self:isValidFillType(fillUnit.fillType) then
					return fillUnit.fillType
				end
			end
		end
	end
	return nil
end

function UnloadableFieldworkAIDriver:isValidFillType(fillType)
	return fillType ~= FillType.DIESEL and fillType ~= FillType.DEF	and fillType ~= FillType.AIR
end

function UnloadableFieldworkAIDriver:searchForTipTriggers()
	-- look straight ahead for now. The rest of CP looks into the direction of the 'current waypoint'
	-- but we don't have that information (lx/lz) here. See if we can get away with this, should only
	-- be a problem if we have a sharp curve around the trigger
	local nx, ny, nz = localDirectionToWorld(self.vehicle.cp.DirectionNode, 0, -0.1, 1)
	-- raycast start point in front of vehicle
	local x, y, z = localToWorld(self.vehicle.cp.DirectionNode, 0, 1, 3)
	courseplay:doTriggerRaycasts(self.vehicle, 'tipTrigger', 'fwd', true, x, y, z, nx, ny, nz)
end

function UnloadableFieldworkAIDriver:atUnloadWaypoint()
	return self.course:isUnloadAt(self.ppc:getCurrentWaypointIx())
end

--- Update the unload offset from the current settings and apply it when needed
function UnloadableFieldworkAIDriver:updateOffset()
	local currentWaypointIx = self.ppc:getCurrentWaypointIx()
	local useOffset = false

	if self.course:hasUnloadPointAround(currentWaypointIx, 6, 3) then
		-- around unload points
		self.ppc:setOffset(self.vehicle.cp.loadUnloadOffsetX, self.vehicle.cp.loadUnloadOffsetZ)
	else
		self.ppc:setOffset(0, 0)
	end
end

function UnloadableFieldworkAIDriver:handleBalers(workTool)
	-- no baler, return
	if not workTool then return end

	--if vehicle.cp.waypointIndex >= vehicle.cp.startWork + 1 and vehicle.cp.waypointIndex < vehicle.cp.stopWork and vehicle.cp.turnStage == 0 then
	--  vehicle, workTool, unfold, lower, turnOn, allowedToDrive, cover, unload, ridgeMarker,forceSpeedLimit,workSpeed)
	local specialTool, allowedToDrive, stoppedForReason = courseplay:handleSpecialTools(self.vehicle, workTool, true, true, true, true, nil, nil, nil);
	if not specialTool then
		-- automatic opening for balers
		local capacity = workTool.cp.capacity
		local fillLevel = workTool.cp.fillLevel
		if workTool.spec_baler ~= nil then

			--print(string.format("if courseplay:isRoundbaler(workTool)(%s) and fillLevel(%s) > capacity(%s) * 0.9 and fillLevel < capacity and workTool.spec_baler.unloadingState(%s) == Baler.UNLOADING_CLOSED(%s) then",
			--tostring(courseplay:isRoundbaler(workTool)),tostring(fillLevel),tostring(capacity),tostring(workTool.spec_baler.unloadingState),tostring(Baler.UNLOADING_CLOSED)))
			if courseplay:isRoundbaler(workTool) and fillLevel > capacity * 0.9 and fillLevel < capacity and workTool.spec_baler.unloadingState == Baler.UNLOADING_CLOSED then
				if not workTool.spec_turnOnVehicle.isTurnedOn and not stoppedForReason then
					workTool:setIsTurnedOn(true, false);
				end;
				self:setSpeed(self.vehicle.cp.speeds.turn)
			elseif fillLevel >= capacity and workTool.spec_baler.unloadingState == Baler.UNLOADING_CLOSED then
				allowedToDrive = false;
				if #(workTool.spec_baler.bales) > 0 and workTool.spec_baleWrapper == nil then --Ensures the baler wrapper combo is empty before unloading
					workTool:setIsUnloadingBale(true, false)
				end
			elseif workTool.spec_baler.unloadingState ~= Baler.UNLOADING_CLOSED then
				allowedToDrive = false
				if workTool.spec_baler.unloadingState == Baler.UNLOADING_OPEN then
					workTool:setIsUnloadingBale(false)
				end
			elseif fillLevel >= 0 and not workTool:getIsTurnedOn() and workTool.spec_baler.unloadingState == Baler.UNLOADING_CLOSED then
				workTool:setIsTurnedOn(true, false);
			end
			if workTool.spec_baleWrapper and workTool.spec_baleWrapper.baleWrapperState == BaleWrapper.STATE_WRAPPER_FINSIHED then --Unloads the baler wrapper combo
				workTool:doStateChange(BaleWrapper.CHANGE_WRAPPER_START_DROP_BALE)
			end
		end
		if workTool.setPickupState ~= nil then
			if workTool.spec_pickup ~= nil and not workTool.spec_pickup.isLowered then
				workTool:setPickupState(true, false);
				courseplay:debug(string.format('%s: lower pickup order', nameNum(workTool)), 17);
			end;
		end;
	end
	if not allowedToDrive then
		self:setSpeed(0)
	end
end
