--ValidModeSetupHandler used to check which mode is valid
--the configuration can be found in ValidModeSetup.xml

---@class ValidModeSetupHandler
ValidModeSetupHandler = CpObject()
function ValidModeSetupHandler:init()
	self:loadFromXml()
end

--load the ValidModeSetup.xml file and create a data table once at start
function ValidModeSetupHandler:loadFromXml()
	local modeSetup = {}
	local validModeSetupKey = "ValidModeSetup"
	local filePath = Utils.getFilename('config/ValidModeSetup.xml', courseplay.path);
	self.xmlFile = loadXMLFile('modeSetup', filePath);
	if self.xmlFile and hasXMLProperty(self.xmlFile, validModeSetupKey) then
		local i = 0
		--go through all cp modes
		while true do
			local modeKey = string.format("%s.%s(%d)",validModeSetupKey,"Mode",i)
			if not hasXMLProperty(self.xmlFile, modeKey) then
			--	courseplay.info(string.format("ValidModeSetupHandler, modeKey not found: %s",modeKey))
				break
			end
			--all the allowedSetups ..
			local allowedSetups = {}
			self:loadSetupsFromXml(self.xmlFile,modeKey,allowedSetups,"AllowedSetups")
			--all the disallowedSetups ..
			local disallowedSetups = {}
			self:loadSetupsFromXml(self.xmlFile,modeKey,disallowedSetups,"DisallowedSetups")
			local validData = {}
			if #allowedSetups > 0 then 
				validData.allowedSetups =  allowedSetups
			end
			if #disallowedSetups > 0 then 
				validData.disallowedSetups =  disallowedSetups
			end
			modeSetup[i+1] = validData
			i = i+1
		end
		self.modeSetup = modeSetup
	--	DebugUtil.printTableRecursively(modeSetup, "   ", 0, 3)
	else 
		print(string.format("ValidModeSetupHandler, could not load file: %s",filePath))
	end
end

--load the Setup for either the allowed or disallowed Setups
function ValidModeSetupHandler:loadSetupsFromXml(xmlFile,baseKey,entry,allowKey)
	local key = string.format("%s.%s",baseKey,allowKey)
	local i = 0
	while true do 
		local setupKey = string.format("%s.%s(%d)",key,"Setup",i)
		if not hasXMLProperty(xmlFile, setupKey) then
		--	courseplay.info(string.format("ValidModeSetupHandler, %s not found: %s",allowKey,setupKey))
			break
		end
		local specSetup = {}
		self:loadSetupFromXml(xmlFile,setupKey,specSetup,"Specialization")	
		self:loadSetupFromXml(xmlFile,setupKey,specSetup,"SpecialTool")	
		if #specSetup>0 then
			table.insert(entry,specSetup)
		end
		i = i+1
	end
end

--load the Specializations or SpecialTools
function ValidModeSetupHandler:loadSetupFromXml(xmlFile,baseKey,entry,itemKey)
	local i = 0
	while true do 
		local key = string.format("%s.%s(%d)",baseKey,itemKey,i)
		if not hasXMLProperty(xmlFile, key) then
		--	courseplay.info(string.format("ValidModeSetupHandler, %s not found: %s",itemKey,key))
			break
		end
		local specName = getXMLString(xmlFile, key.."#name")
		table.insert(entry,specName)
		i = i+1
	end
end


---checks if the "mode" is allowed and not disallowed for the vehicle
---@param int : cpMode to check
---@param vehicle : object, implement,vehicle
---@return boolean : isAllowedOkay, boolean : isDisallowedOkay
function ValidModeSetupHandler:isModeValid(mode,object)
	local validData = self.modeSetup[mode]
	local isAllowedOkay = false
	local isDisallowedOkay = true
	if validData then 
		if validData.allowedSetups then 
			isAllowedOkay = self:isSetupAllowedValid(validData.allowedSetups,object)
			courseplay.debugVehicle(18,object,"allowedSetups, mode: %d, isAllowedOkay: %s",mode,tostring(isAllowedOkay))
		end
		if validData.disallowedSetups then 
			isDisallowedOkay = self:isSetupDisallowedValid(validData.disallowedSetups,object)
			courseplay.debugVehicle(18,object,"disallowedSetup, mode: %d,, isDisallowedOkay: %s",mode,tostring(isDisallowedOkay))
		end
	else 
		courseplay.info("ValidModeSetupHandler, validData==nil !!")
		return false
	end
	return isAllowedOkay, isDisallowedOkay
end

---checks if one setup combo is allowed for this object
---@param table : setups 
---@param vehicle : object, implement,vehicle
---@return boolean : isAllowedOkay
function ValidModeSetupHandler:isSetupAllowedValid(setups,object)
	local allowedSetup = false
	for _,specSetup in pairs(setups) do 
		local found = true
		for _,spec in pairs(specSetup) do
			if object[spec] == nil and object.cp.xmlFileName ~= spec then 
				found = false
			end
		end
		allowedSetup = allowedSetup or found
	end
	return allowedSetup
end

---checks if one setup combo is disallowed for this object
---@param table : setups 
---@param vehicle : object, implement,vehicle
---@return boolean : isDisallowedOkay
function ValidModeSetupHandler:isSetupDisallowedValid(setups,object)
	local disallowedSetup = false
	for _,specSetup in pairs(setups) do 
		local found = false
		for _,spec in pairs(specSetup) do
			if object[spec] or object.cp.xmlFileName == spec then 
				found = true
			end
		end
		disallowedSetup = disallowedSetup or found
	end
	return not disallowedSetup
end