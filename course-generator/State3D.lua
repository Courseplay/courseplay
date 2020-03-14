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

--- A node in a 3D state space, also known as a pose, which is a 2D postiion (x, y) and a heading
---@class State3D : Vector
State3D = CpObject(Vector)

---@param x number x position
---@param y number y position
---@param t number heading (theta) in radians
---@param r number turn radius
---@param pred State3D predecessor node
---@param gear HybridAstar.Gear straight/left/right
---@param steer HybridAstar.Steer forward/backward
---@param userData table any data the user wants to associate with this state
function State3D:init(x, y, t, g, pred, gear, steer, userData)
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
    self.gear = gear or HybridAStar.Gear.Forward
    self.steer = steer
    -- penalty for using this node, to avoid obstacles, stay in an area, etc.
    self.nodePenalty = 0
end

function State3D:copy(other)
    local this = State3D(other.x, other.y, other.t, other.g, other.pred, other.gear, other.steer, other.userData)
    this.h = other.h
    this.cost = other.cost
    this.goal = other.goal
    this.onOpenList = other.onOpenList
    this.closed = other.closed
    this.nodePenalty = other.nodePenalty
    this.gear = other.gear
    this.steer = other.steer
    this.userData = other.userData
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

---@param other State3D
function State3D:distance(other)
    local dx = other.x - self.x
    local dy = other.y - self.y
    local d = math.sqrt(dx * dx + dy * dy)
    return d
end

function State3D:equals(other, deltaPos, deltaTheta)
    local d = self:distance(other)
    if d < 2*deltaPos then
        --print(d, self.t, other.t, self.t - other.t, self:getCost())
    end
    return math.abs(self.x - other.x ) < deltaPos and
            math.abs(self.y - other.y ) < deltaPos and
            (math.abs(self.t - other.t) < deltaTheta or
            math.abs(self.t - other.t) > 2 * math.pi - deltaTheta)
end

function State3D:updateG(primitive, userPenalty)
    local penalty = 1
    local reversePenalty = 2
    if self.pred then
        -- penalize turning
        if self.pred.steer and self.steer ~= self.pred.steer then
            penalty = penalty * 1.1
        end
        -- penalize direction change
        if self.pred.gear and self.gear ~= self.pred.gear then
            penalty = penalty * reversePenalty * 2
        end
        -- penalize reverse driving
        if self.gear == HybridAStar.Gear.Backward then
            penalty = penalty * reversePenalty
        end
    end
    self.g = self.g + penalty * primitive.d + (userPenalty or 0)
end

function State3D:setNodePenalty(nodePenalty)
    self.nodePenalty = nodePenalty
end

---@param node State3D
function State3D:updateH(goal, analyticPathLength, heuristicPathLength)
    -- simple Eucledian heuristics
    local h = self:distance(goal)
    self.hAnalytic = analyticPathLength
    self.hHeuristic = heuristicPathLength
    self.h = math.max(h, analyticPathLength or 0, heuristicPathLength or 0)
    self.cost = self.g + self.h
end

function State3D:getCost()
    return self.cost
end

function State3D:getReverseHeading()
    return self:normalizeHeadingRad(self.t + math.pi)
end

function State3D:addHeading(angle)
    self.t = self:normalizeHeadingRad(self.t + angle)
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

--- Add a vector (+= operator, not creating a new Vector instance as __add)
function State3D:add(v)
    self.x, self.y = (self + v):unpack()
end

function State3D:__tostring()
    local result
    local steer
    if self.steer == HybridAStar.Steer.Right then
        steer = 'Right'
    elseif self.steer == HybridAStar.Steer.Left then
        steer = 'Left'
    else
        steer = 'Straight'
    end
    local gear = self.gear == HybridAStar.Gear.Forward and 'Forward' or 'Backward'
    result = string.format('x: %.2f y:%.2f t:%d(%.2f) gear:%s steer:%s g:%.4f h:%.4f c:%.4f closed:%s open:%s',
            self.x, self.y, math.deg(self.t), self.t, gear, steer,
            self.g, self.h, self.cost, tostring(self.closed), tostring(self.onOpenList))
    return result
end

---@param path State3D[]
function State3D.printPath(path, title)
    if title then
        print(title)
    end
    for i, p in ipairs(path) do
        print(string.format('%d: %s', i, tostring(p)))
    end
end

--- Set the heading on an array of nodes (a polyline) so that the heading is pointing to the next
--- node in the list. The last node will have the same heading as the previous.
---@param path State3D[]
function State3D.setHeading(path)
    for i = 2, #path do
        local delta = path[i] - path[i - 1]
        path[i - 1].t = delta:heading()
    end
    path[#path].t = path[#path - 1].t
end
