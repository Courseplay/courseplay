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

-- Class implementation stolen from http://lua-users.org/wiki/SimpleLuaClasses

function CpObject(base, init)
	local c = {}    -- a new class instance
	if not init and type(base) == 'function' then
		init = base
		base = nil
	elseif type(base) == 'table' then
		-- our new class is a shallow copy of the base class!
		for i,v in pairs(base) do
			c[i] = v
		end
		c._base = base
	end
	-- the class will be the metatable for all its objects,
	-- and they will look up their methods in it.
	c.__index = c

	-- expose a constructor which can be called by <classname>(<args>)
	local mt = {}
	mt.__call = function(class_tbl, ...)
		local obj = {}
		setmetatable(obj,c)
		if class_tbl.init then
			class_tbl.init(obj,...)
		else
			-- make sure that any stuff from the base class is initialized!
			if base and base.init then
				base.init(obj, ...)
			end
		end
		return obj
	end
	c.init = init
	c.is_a = function(self, klass)
		local m = getmetatable(self)
		while m do
			if m == klass then return true end
			m = m._base
		end
		return false
	end
	setmetatable(c, mt)
	return c
end

--- Object with a time to live.
CpTemporaryObject = CpObject()

function CpTemporaryObject:init(valueWhenExpired)
	self.valueWhenExpired = valueWhenExpired
	self.value = self.valueWhenExpired
	self.expiryTime = g_time
end

--- Set temporary value for object
---@value anything the temporary value
---@ttlMs Time To Live, for ttlMs milliseconds, CpTemporaryObject:get() will
--- return this value, otherwise valueWhenExpired
function CpTemporaryObject:set(value, ttlMs)
	self.value = value
	self.expiryTime = g_time + ttlMs
end

function CpTemporaryObject:get()
	if g_time > self.expiryTime then
		-- value expired, reset it
		self.value = self.valueWhenExpired
	end 
	return self.value
end

--- Object slowly adjusting its value
CpSlowChangingObject = CpObject()

function CpSlowChangingObject:init(targetValue, timeToReachTargetMs)
	self.value = targetValue
	self:set(targetValue, timeToReachTargetMs)
end

function CpSlowChangingObject:set(targetValue, timeToReachTargetMs)
	self.previousValue = self.value
	self.targetValue = targetValue
	self.targetValueMs = g_time
	self.timeToReachTargetMs = timeToReachTargetMs or 1
end

function CpSlowChangingObject:get()
	local age = g_time - self.targetValueMs
	if age < self.timeToReachTargetMs then
		-- not reaped yet, return a value proportional to the time until ripe
		self.value = self.previousValue + (self.targetValue - self.previousValue) * age / self.timeToReachTargetMs
	else
		self.value = self.targetValue
	end
	return self.value
end

