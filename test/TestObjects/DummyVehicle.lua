--- This file is only for functional tests outside of the game.
require("CpObject")
require("test.TestObjects.DummyFillUnit")
require("test.TestObjects.DummyMotorized")
---@class DummyVehicle
DummyVehicle = CpObject()
function DummyVehicle:init(implements,fillUnitData)
	self.spec_fillUnit = DummyFillUnit(fillUnitData)
	self.spec_motorized = DummyMotorized(self)
	self.implements = implements or {}
end

function DummyVehicle:getFillUnits()
	return self.spec_fillUnit.fillUnits
end

function DummyVehicle:getConsumerFillUnitIndex(fillType)
	local consumer = self.spec_motorized.consumersByFillType[fillType]
	if consumer ~= nil then
        return consumer.fillUnitIndex
    end
end

function DummyVehicle:getAttachedImplements()
	return self.implements
end
--- {{object = trailer}}
function DummyVehicle.getNewDataForImplements(...)
	local impl = {...}
	local implements = {}
	for _,obj in pairs(impl) do 
		print(obj)
		table.insert(implements,{object = obj})
	end
	return implements
end
