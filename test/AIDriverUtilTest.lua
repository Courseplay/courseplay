--- This file is only for functional tests outside of the game.

require("test.TestObjects.TestUtil")
require("test.TestObjects.DummyVehicle")
require("AIDriverUtil")

g_fillTypeManager = {}
function g_fillTypeManager:getFillTypeNameByIndex(fillType)
	return tostring(fillType)
end

FillType = {}
FillType.UNKNOWN = 0
FillType.DEF = 98
FillType.AIR = 99
FillType.DIESEL = 100

local vehicleFillUnits = {
	DummyFillUnit.getNewDataForFillUnit(7203,1234,2),
	DummyFillUnit.getNewDataForFillUnit(100000000,10000000,FillType.DIESEL,nil,true)
}

local trailerFillUnits = {
	DummyFillUnit.getNewDataForFillUnit(1000,10000,10),
	DummyFillUnit.getNewDataForFillUnit(100000,100000,10),
	DummyFillUnit.getNewDataForFillUnit(3000,30000,2),
}

local trailer = DummyVehicle(nil,trailerFillUnits)
local vehicle = DummyVehicle(DummyVehicle.getNewDataForImplements(trailer),vehicleFillUnits)

print("GetTotalFillLevelAndCapacity result: ")
debug("FillLevel: %s, Capacity: %s",AIDriverUtil.getTotalFillLevelAndCapacity(vehicle))

--- AIDriverUtil.getTotalFillLevelAndCapacityForObject
print("GetTotalFillLevelAndCapacityForObject result: ")
debug("FillLevel: %s, Capacity: %s",AIDriverUtil.getTotalFillLevelAndCapacityForObject(trailer))

--- AIDriverUtil.getTotalFillLevelPercentage
print("GetTotalFillLevelPercentage result: ")
debug("FillLevelPercentage: %s",AIDriverUtil.getTotalFillLevelPercentage(vehicle))

--- AIDriverUtil.getAllFillTypes
print("GetAllFillTypes result: ")
debugTable(AIDriverUtil.getAllFillTypes(trailer))

--- AIDriverUtil.getAllFillLevels
print("GetAllFillLevels result: ")
local fillLevelInfo = {}
AIDriverUtil.getAllFillLevels(vehicle, fillLevelInfo)
debugTable(fillLevelInfo)