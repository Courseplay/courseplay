--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2019 Peter Vaiko

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

function courseplay.initAIImplements()

	AIImplement.getCanImplementBeUsedForAI = Utils.overwrittenFunction(AIImplement.getCanImplementBeUsedForAI,
		function(self, superFunc)
			if SpecializationUtil.hasSpecialization(BaleLoader, self.specializations) then
				return true
			elseif superFunc ~= nil then
				return superFunc(self)
			end
		end)

	BaleLoader.onAIImplementStart = Utils.overwrittenFunction(BaleLoader.onAIImplementStart,
		function(self, superFunc)
			if superFunc ~= nil then superFunc(self) end
			print('#### onAIImplementStart')
			self:doStateChange(BaleLoader.CHANGE_MOVE_TO_WORK);
		end)

	BaleLoader.onAIImplementEnd = Utils.overwrittenFunction(BaleLoader.onAIImplementEnd,
		function(self, superFunc)
			if superFunc ~= nil then superFunc(self) end
			print('#### onAIImplementEnd')
			self:doStateChange(BaleLoader.CHANGE_MOVE_TO_TRANSPORT);
		end)

	local baleLoaderRegisterEventListeners = function(vehicleType)
		print('Registering event listeners for bale loader')
		SpecializationUtil.registerEventListener(vehicleType, "onAIImplementStart", BaleLoader)
		SpecializationUtil.registerEventListener(vehicleType, "onAIImplementEnd", BaleLoader)
	end

	print('Appending event listener for bale loaders')
	BaleLoader.registerEventListeners = Utils.appendedFunction(BaleLoader.registerEventListeners, baleLoaderRegisterEventListeners)


	-- Make sure the Giants helper can't be hired for implements which have no Giants AI functionality
	AIVehicle.getCanStartAIVehicle = Utils.overwrittenFunction(AIVehicle.getCanStartAIVehicle,
		function(self, superFunc)
			-- chack our list for AI implements that can only be handled by the courseplay helper
			local aiImplements = self:getAttachedAIImplements()
			for _, implement in ipairs(aiImplements) do
				-- Only the courseplay helper can handle bale loaders.
				if SpecializationUtil.hasSpecialization(BaleLoader, implement.object.specializations) then
					return false
				end
			end
			if superFunc ~= nil then
				return superFunc(self)
			end
		end)
end