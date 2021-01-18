--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2021 Peter Vaiko

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

--- A container for custom vehicle configurations.
---
--- Allows to customize vehicle data an in XML file.
---
---@class VehicleConfigurations : CpObject
VehicleConfigurations = CpObject()

VehicleConfigurations.attributes = {
    {name = 'toolOffsetX', getXmlFunction = getXMLFloat},
}

function VehicleConfigurations:init()
    self.vehicleConfigurations = {}
    if g_currentMission then
        self:loadFromXml()
    end
end

function VehicleConfigurations:loadFromXml()
    self.xmlFileName = Utils.getFilename('config/VehicleConfigurations.xml', courseplay.path)
    self:loadXmlFile(self.xmlFileName)
    self.userXmlFileName =
    getUserProfileAppPath() .. 'savegame' .. g_currentMission.missionInfo.savegameIndex ..
            '/courseplayVehicleConfigurations.xml'
    self:loadXmlFile(self.userXmlFileName)
end

function VehicleConfigurations:addAttribute(vehicleConfiguration, xmlFile, vehicleElement, attribute, getXmlFunction)
    local configValue = getXmlFunction(xmlFile, vehicleElement .. '#' .. attribute)
    if configValue then
        vehicleConfiguration[attribute] = configValue
        courseplay.info('\\__ %s = %s', attribute, configValue)
    end
end

function VehicleConfigurations:readVehicle(xmlFile, vehicleElement)
    local vehicleConfiguration = {}
    local name = getXMLString(xmlFile, vehicleElement .. "#name")
    courseplay.info('Reading configuration for %s', name)
    for _, attribute in pairs(self.attributes) do
        self:addAttribute(vehicleConfiguration, xmlFile, vehicleElement, attribute.name, attribute.getXmlFunction)
    end
    self.vehicleConfigurations[name] = vehicleConfiguration
end

function VehicleConfigurations:loadXmlFile(fileName)
    courseplay.info('Loading vehicle configuration from %s', fileName)
    if fileExists(fileName) then
        local xmlFile = loadXMLFile('vehicleConfigurations', fileName);
        local rootElement = 'VehicleConfigurations'
        if xmlFile and hasXMLProperty(xmlFile, rootElement) then
            local i = 0
            while true do
                local vehicleElement = string.format('%s.Vehicle(%d)', rootElement, i)
                if hasXMLProperty(xmlFile, vehicleElement) then
                    self:readVehicle(xmlFile, vehicleElement)
                else
                    break
                end
                i = i + 1
            end
        end
    end
end

--- Get a custom configuration value for a single vehicle/implement
--- @param object table vehicle or implement object. This function uses the object's configFileName to uniquely
--- identify the vehicle/implement.
--- @param attribute string configuration attribute to get
--- @return any the value of the configuration attribute or nil if there's no custom config for it
function VehicleConfigurations:get(object, attribute)
    if object and object.configFileName then
        local vehicleXmlFileName = courseplay.utils:getFileNameFromPath(object.configFileName)
        if self.vehicleConfigurations[vehicleXmlFileName] then
            return self.vehicleConfigurations[vehicleXmlFileName][attribute]
        else
            return nil
        end
    end
end

--- Get a custom configuration value for an object and its attached implements.
--- First checks the vehicle itself, then all its attached implements until the attribute is found. If the same
--- attribute is defined on multiple implements, only the first is returned
--- @param vehicle table vehicle
--- @param attribute string configuration attribute to get
--- @return any the value of the configuration attribute or nil if there's no custom config for it
function VehicleConfigurations:getRecursively(object, attribute)
    local value = self:get(object, attribute)
    if value then
        return value
    end
    for _, implement in pairs(object:getAttachedImplements()) do
        value = self:getRecursively(implement.object, attribute)
        if value then
            return value
        end
    end
    return nil
end

g_vehicleConfigurations = VehicleConfigurations()
