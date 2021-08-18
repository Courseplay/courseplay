--- This file is only for functional tests outside of the game.

require("CpObject")
---@class DummyFillUnit
DummyFillUnit = CpObject()

function DummyFillUnit:init(fillUnitData)
	self.fillUnits = DummyFillUnit.createFillUnits(fillUnitData)
end

function DummyFillUnit.createFillUnits(fillUnitData)
	local fillUnits = {}
	for ix,data in ipairs(fillUnitData) do 
		local fillUnit = {}
		fillUnit.fillUnitIndex = ix
		fillUnit.capacity = data.capacity or 0
		fillUnit.fillLevel = data.fillLevel or 0
		fillUnit.fillType = data.fillType or 0
		fillUnit.supportedFillTypes = data.supportedFillTypes or {}
		fillUnit.isConsumer = data.isConsumer
		table.insert(fillUnits,fillUnit)
	end
	return fillUnits
end

---@param fillLevel number
---@param capacity number
---@param fillType number
---@param supportedFillTypes table fill types are the indices and need a true value.
---@param isConsumer boolean simulates consumer fill types from spec_motorized
function DummyFillUnit.getNewDataForFillUnit(fillLevel,capacity,fillType,supportedFillTypes,isConsumer)
	return {
			fillLevel = fillLevel,
			capacity = capacity,
			fillType = fillType,
			supportedFillTypes = supportedFillTypes,
			isConsumer = isConsumer
			}
end