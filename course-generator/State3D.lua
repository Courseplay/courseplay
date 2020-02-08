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

--- A node in a 3D state space
---@class State3D
State3D = CpObject()

---@param x number x position
---@param y number y position
---@param t number heading (theta) in radians
---@param r number turn radius
---@param pred State3D predecessor node
---@param motionPrimitive HybridAstar.MotionPrimitive straight/left/right
---@param userData table any data the user wants to associate with this state
function State3D:init(x, y, t, g, pred, motionPrimitive, userData)
    self.x = x
    self.y = y
    self.t = self:normalizeHeadingRad(t)
    self.pred = pred
    self.g = g or 0
    self.h = 0
    self.cost = 0
    self.goal = false
    self.onOpenList = false
    self.open = false
    self.closed = false
    self.userData = userData
    self.motionPrimitive = motionPrimitive
    if motionPrimitive and HybridAStar.MotionPrimitives.isReverse(motionPrimitive) then
        self.reverse = true
    end
        -- penalty for using this node, to avoid obstacles, stay in an area, etc.
    self.nodePenalty = 0
end

function State3D:copy(other)
    local this = State3D(other.x, other.y, other.t, other.g, other.pred, other.motionPrimitive, other.userData)
    this.h = other.h
    this.cost = other.cost
    this.goal = other.goal
    this.onOpenList = other.onOpenList
    this.closed = other.closed
    this.nodePenalty = other.nodePenalty
    self.userData = userData
    return this
end


--- Comparision for the binary heap to find the node with the lowest cost
function State3D:lt(other)
    return self.cost < other.cost
end

function State3D:close()
    self.closed = true
end

function State3D.pop(openList)
    local node = openList:pop()
    node.onOpenList = false
    return node
end

function State3D:insert(openList)
    self.closed = false
    if not self.onOpenList then
        self.onOpenList = true
        openList:insert(self, self)
    end
end

function State3D:update(openList)
    if self.onOpenList then
        openList:update(self, self)
    end
end

function State3D:remove(openList)
    if self.onOpenList then
        openList:remove(self)
    end
end

function State3D:isClosed()
    return self.closed
end

function State3D:equals(other, deltaPos, deltaTheta)
    return math.abs(self.x - other.x ) < deltaPos and
            math.abs(self.y - other.y ) < deltaPos and
            (math.abs(self.t - other.t) < deltaTheta or
            math.abs(self.t - other.t) > 2 * math.pi - deltaTheta)
end

function State3D:updateG(primitive, userPenalty)
    local penalty = 1
    local reversePenalty = 4
    if self.pred and self.pred.motionPrimitive then
        -- penalize turning
        if HybridAStar.MotionPrimitives.isTurn(primitive, self.pred.motionPrimitive) then
            penalty = penalty * 1.1
        end
        -- penalize direction change
        if not HybridAStar.MotionPrimitives.isSameDirection(primitive, self.pred.motionPrimitive) then
            penalty = penalty * reversePenalty * 2
        end
        -- penalize reverse driving
        if HybridAStar.MotionPrimitives.isReverse(primitive) then
            penalty = penalty * reversePenalty
        end
    end
    self.g = self.g + penalty * primitive.d + (userPenalty or 0)
end

function State3D:setNodePenalty(nodePenalty)
    self.nodePenalty = nodePenalty
end

---@param node State3D
function State3D:updateH(goal)
    -- simple Eucledian heuristics
    local dx = goal.x - self.x
    local dy = goal.y - self.y
    self.h = math.sqrt(dx * dx + dy * dy)
    self.cost = self.g + self.h
end


---@param node State3D
function State3D:updateHWithDubins(goal, turnRadius)
    local dubinsPath = dubins_shortest_path(self, goal, turnRadius)
    local dubinsPathLength = dubins_path_length(dubinsPath)
    self.h = math.max(dubinsPathLength, self.h)
    self.cost = self.g + self.h
end

function State3D:getCost()
    return self.cost
end

function State3D:getReverseHeading()
    return self:normalizeHeadingRad(self.t + math.pi)
end

--- Make a 180 turn
function State3D:reverseHeading()
    self.t = self:getReverseHeading()
end

function State3D:normalizeHeadingRad(t)
    t = t % (2 * math.pi)
    if t < 0 then
        return 2 * math.pi - t
    else
        return t
    end
end

function State3D:__tostring()
    local result
    local type = self.motionPrimitive and tostring(self.motionPrimitive.type) or 'nil'
    local pred = self.pred and self.pred.motionPrimitive and self.pred.motionPrimitive.type or 'nil'
    result = string.format('x: %.2f y:%.2f t:%d type:%s g:%.2f h:%.2f c:%.2f closed:%s open:%s, pred = %s', self.x, self.y, math.deg(self.t),
                type, self.g, self.h, self.cost, tostring(self.closed), tostring(self.onOpenList), pred)
    return result
end
