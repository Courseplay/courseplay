--[[
This file is part of Courseplay (https://github.com/Courseplay/courseplay)
Copyright (C) 2020 Peter Vaiko

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General function License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General function License for more details.

You should have received a copy of the GNU General function License
along with this program.  If not, see <http://www.gnu.org/licenses/>.

This implementation of the Reeds-Schepp curve algorithm is based on
Matt Bradley's master thesis and his C# code at
https://github.com/mattbradley/AutonomousCar
--]]

--- The ReedsSheppSolver class takes a start and goal pose and generates the optimal set of Reeds-Shepp actions
--- that can be used to move a vehicle from start to goal obeying the turning radius contraints of the vehicle.
--- This class implements dozens of trigonometric equations described by Reeds and Shepp in their paper:
--- "Optimal paths for a car that goes both forwards and backwards".
--- @class ReedsSheppSolver
ReedsSheppSolver = CpObject(AnalyticSolver)

function ReedsSheppSolver:init()
    self.numPathWords = 48
end

local sin, cos, asin, acos, atan2, abs, sqrt, floor, huge, pi =
    math.sin, math.cos, math.asin, math.acos,  math.atan2, math.abs, math.sqrt, math.floor, math.huge, math.pi

local twoPi = 2 * pi
local piHalf = pi / 2

---@param start State3D
---@param goal State3D
function ReedsSheppSolver:solve(start, goal, turnRadius, allowReverse)
    -- Translate the goal so that the start position is at the origin
    -- Also normalize to turnRadius so all circles are unit circles (radius == 1)
    local newGoal = State3D((goal.x - start.x) / turnRadius, (goal.y - start.y) / turnRadius, self:wrapAngle(goal.t - start.t))
    -- Rotate the goal so that the start orientation is 0
    newGoal:rotate(-start.t)

    local bestPathLength = huge
    local bestWord, bestKey
    local bestT, bestU, bestV = 0, 0, 0
    for key, word in pairs(ReedsShepp.PathWords) do
        local potentialLength, t, u, v = self:calculatePathLength(newGoal, word)
        if potentialLength < huge then
           --   print(key, potentialLength)
        end
        potentialLength = potentialLength * (word.p or 1)
        if potentialLength < bestPathLength then
            bestPathLength = potentialLength
            bestWord = word
            bestKey = key
            bestT = t
            bestU = u
            bestV = v
        end
    end
    if bestPathLength == huge then
        return ReedsShepp.ActionSet(huge)
    end
    return self:getPath(bestWord, bestT, bestU, bestV), bestKey
end

function ReedsSheppSolver:makeGoal(x, y, t) 
    return {x = x, y = y, t = t, sint = sin(t), cost = cos(t)}
end

function ReedsSheppSolver:calculatePathLength(goal, word)
    -- Reeds-Shepp 8.1: CSC, same turn
    if word == ReedsShepp.PathWords.LfSfLf then return self:LfSfLf(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbSbLb then return self:LfSfLf(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfSfRf then return self:LfSfLf(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbSbRb then return self:LfSfLf(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    -- Reeds-Shepp 8.2: CSC, different turn
    if word == ReedsShepp.PathWords.LfSfRf then return self:LfSfRf(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbSbRb then return self:LfSfRf(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfSfLf then return self:LfSfRf(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbSbLb then return self:LfSfRf(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    -- Reeds-Shepp 8.3: C|C|C
    if word == ReedsShepp.PathWords.LfRbLf then return self:LfRbLf(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbRfLb then return self:LfRbLf(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfLbRf then return self:LfRbLf(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbLfRb then return self:LfRbLf(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    -- Reeds-Shepp 8.4: C|CC
    if word == ReedsShepp.PathWords.LfRbLb then return self:LfRbLb(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbRfLf then return self:LfRbLb(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfLbRb then return self:LfRbLb(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbLfRf then return self:LfRbLb(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    -- Reeds-Shepp 8.4: CC|C
    if word == ReedsShepp.PathWords.LfRfLb then return self:LfRfLb(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbRbLf then return self:LfRfLb(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfLfRb then return self:LfRfLb(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbLbRf then return self:LfRfLb(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    -- Reeds-Shepp 8.7: CCu|CuC
    if word == ReedsShepp.PathWords.LfRufLubRb then return self:LfRufLubRb(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbRubLufRf then return self:LfRufLubRb(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfLufRubLb then return self:LfRufLubRb(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbLubRufLf then return self:LfRufLubRb(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    -- Reeds-Shepp 8.8: C|CuCu|C
    if word == ReedsShepp.PathWords.LfRubLubRf then return self:LfRubLubRf(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbRufLufRb then return self:LfRubLubRf(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfLubRubLf then return self:LfRubLubRf(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbLufRufLb then return self:LfRubLubRf(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    -- Reeds-Shepp 8.9: C|C(pi/2)SC, same turn
    if word == ReedsShepp.PathWords.LfRbpi2SbLb then return self:LfRbpi2SbLb(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbRfpi2SfLf then return self:LfRbpi2SbLb(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfLbpi2SbRb then return self:LfRbpi2SbLb(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbLfpi2SfRf then return self:LfRbpi2SbLb(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    -- Reeds-Shepp 8.10: C|C(pi/2)SC, different turn
    if word == ReedsShepp.PathWords.LfRbpi2SbRb then return self:LfRbpi2SbRb(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbRfpi2SfRf then return self:LfRbpi2SbLb(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfLbpi2SbLb then return self:LfRbpi2SbLb(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbLfpi2SfLf then return self:LfRbpi2SbLb(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    -- Reeds-Shepp 8.9 (reversed): CSC(pi/2)|C, same turn
    if word == ReedsShepp.PathWords.LfSfRfpi2Lb then return self:LfSfRfpi2Lb(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbSbRbpi2Lf then return self:LfSfRfpi2Lb(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfSfLfpi2Rb then return self:LfSfRfpi2Lb(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbSbLbpi2Rf then return self:LfSfRfpi2Lb(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    -- Reeds-Shepp 8.10 (reversed): CSC(pi/2)|C, different turn
    if word == ReedsShepp.PathWords.LfSfLfpi2Rb then return self:LfSfLfpi2Rb(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbSbLbpi2Rf then return self:LfSfLfpi2Rb(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfSfRfpi2Lb then return self:LfSfLfpi2Rb(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbSbRbpi2Lf then return self:LfSfLfpi2Rb(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    -- Reeds-Shepp 8.11: C|C(pi/2)SC(pi/2)|C
    if word == ReedsShepp.PathWords.LfRbpi2SbLbpi2Rf then return self:LfRbpi2SbLbpi2Rf(self:makeGoal(goal.x, goal.y, goal.t)) end
    if word == ReedsShepp.PathWords.LbRfpi2SfLfpi2Rb then return self:LfRbpi2SbLbpi2Rf(self:makeGoal(-goal.x, goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RfLbpi2SbRbpi2Lf then return self:LfRbpi2SbLbpi2Rf(self:makeGoal(goal.x, -goal.y, -goal.t)) end
    if word == ReedsShepp.PathWords.RbLfpi2SfRfpi2Lb then return self:LfRbpi2SbLbpi2Rf(self:makeGoal(-goal.x, -goal.y, goal.t)) end

    return huge, 0, 0, 0
end

function ReedsSheppSolver:getPath( word, t, u, v)
    -- Reeds-Shepp 8.1: CSC, same turn
    if word == ReedsShepp.PathWords.LfSfLf then return self:LfSfLfpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbSbLb then return self:timeflipTransform(self:LfSfLfpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfSfRf then return self:reflectTransform(self:LfSfLfpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbSbRb then return self:reflectTransform(self:timeflipTransform(self:LfSfLfpath(t, u, v))) end

    -- Reeds-Shepp 8.2: CSC, different turn
    if word == ReedsShepp.PathWords.LfSfRf then return self:LfSfRfpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbSbRb then return self:timeflipTransform(self:LfSfRfpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfSfLf then return self:reflectTransform(self:LfSfRfpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbSbLb then return self:reflectTransform(self:timeflipTransform(self:LfSfRfpath(t, u, v))) end

    -- Reeds-Shepp 8.3: C|C|C
    if word == ReedsShepp.PathWords.LfRbLf then return self:LfRbLfpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbRfLb then return self:timeflipTransform(self:LfRbLfpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfLbRf then return self:reflectTransform(self:LfRbLfpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbLfRb then return self:reflectTransform(self:timeflipTransform(self:LfRbLfpath(t, u, v))) end

    -- Reeds-Shepp 8.4: C|CC
    if word == ReedsShepp.PathWords.LfRbLb then return self:LfRbLbpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbRfLf then return self:timeflipTransform(self:LfRbLbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfLbRb then return self:reflectTransform(self:LfRbLbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbLfRf then return self:reflectTransform(self:timeflipTransform(self:LfRbLbpath(t, u, v))) end

    -- Reeds-Shepp 8.4: CC|C
    if word == ReedsShepp.PathWords.LfRfLb then return self:LfRfLbpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbRbLf then return self:timeflipTransform(self:LfRfLbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfLfRb then return self:reflectTransform(self:LfRfLbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbLbRf then return self:reflectTransform(self:timeflipTransform(self:LfRfLbpath(t, u, v))) end

    -- Reeds-Shepp 8.7: CCu|CuC
    if word == ReedsShepp.PathWords.LfRufLubRb then return self:LfRufLubRbpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbRubLufRf then return self:timeflipTransform(self:LfRufLubRbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfLufRubLb then return self:reflectTransform(self:LfRufLubRbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbLubRufLf then return self:reflectTransform(self:timeflipTransform(self:LfRufLubRbpath(t, u, v))) end

    -- Reeds-Shepp 8.8: C|CuCu|C
    if word == ReedsShepp.PathWords.LfRubLubRf then return self:LfRubLubRfpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbRufLufRb then return self:timeflipTransform(self:LfRubLubRfpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfLubRubLf then return self:reflectTransform(self:LfRubLubRfpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbLufRufLb then return self:reflectTransform(self:timeflipTransform(self:LfRubLubRfpath(t, u, v))) end

    -- Reeds-Shepp 8.9: C|C(pi/2)SC, same turn
    if word == ReedsShepp.PathWords.LfRbpi2SbLb then return self:LfRbpi2SbLbpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbRfpi2SfLf then return self:timeflipTransform(self:LfRbpi2SbLbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfLbpi2SbRb then return self:reflectTransform(self:LfRbpi2SbLbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbLfpi2SfRf then return self:reflectTransform(self:timeflipTransform(self:LfRbpi2SbLbpath(t, u, v))) end

    -- Reeds-Shepp 8.10: C|C(pi/2)SC, different turn
    if word == ReedsShepp.PathWords.LfRbpi2SbRb then return self:LfRbpi2SbRbpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbRfpi2SfRf then return self:timeflipTransform(self:LfRbpi2SbRbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfLbpi2SbLb then return self:reflectTransform(self:LfRbpi2SbRbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbLfpi2SfLf then return self:reflectTransform(self:timeflipTransform(self:LfRbpi2SbRbpath(t, u, v))) end

    -- Reeds-Shepp 8.9 (reversed): CSC(pi/2)|C, same turn
    if word == ReedsShepp.PathWords.LfSfRfpi2Lb then return self:LfSfRfpi2Lbpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbSbRbpi2Lf then return self:timeflipTransform(self:LfSfRfpi2Lbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfSfLfpi2Rb then return self:reflectTransform(self:LfSfRfpi2Lbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbSbLbpi2Rf then return self:reflectTransform(self:timeflipTransform(self:LfSfRfpi2Lbpath(t, u, v))) end

    -- Reeds-Shepp 8.10 (reversed): CSC(pi/2)|C, different turn
    if word == ReedsShepp.PathWords.LfSfLfpi2Rb then return self:LfSfLfpi2Rbpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbSbLbpi2Rf then return self:timeflipTransform(self:LfSfLfpi2Rbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfSfRfpi2Lb then return self:reflectTransform(self:LfSfLfpi2Rbpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbSbRbpi2Lf then return self:reflectTransform(self:timeflipTransform(self:LfSfLfpi2Rbpath(t, u, v))) end

    -- Reeds-Shepp 8.11: C|C(pi/2)SC(pi/2)|C
    if word == ReedsShepp.PathWords.LfRbpi2SbLbpi2Rf then return self:LfRbpi2SbLbpi2Rfpath(t, u, v) end
    if word == ReedsShepp.PathWords.LbRfpi2SfLfpi2Rb then return self:timeflipTransform(self:LfRbpi2SbLbpi2Rfpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RfLbpi2SbRbpi2Lf then return self:reflectTransform(self:LfRbpi2SbLbpi2Rfpath(t, u, v)) end
    if word == ReedsShepp.PathWords.RbLfpi2SfRfpi2Lb then return self:reflectTransform(self:timeflipTransform(self:LfRbpi2SbLbpi2Rfpath(t, u, v))) end

    return ReedsShepp.ActionSet(huge)
end

function ReedsSheppSolver:timeflipTransform(actions)
    for _, a in ipairs(actions.actions) do
        a.gear = (a.gear == HybridAStar.Gear.Backward) and HybridAStar.Gear.Forward or HybridAStar.Gear.Backward
    end                                                     
    return actions
end

function ReedsSheppSolver:reflectTransform(actions)
    for _, a in ipairs(actions.actions) do
        if a.steer == HybridAStar.Steer.Left then
            a.steer = HybridAStar.Steer.Right
        elseif a.steer == HybridAStar.Steer.Right then
            a.steer = HybridAStar.Steer.Left
        end
    end
    return actions
end

function ReedsSheppSolver:wrapAngle(angle)
    if angle > -pi and angle <= pi then
        return angle;
    end
    angle = angle % (2 * pi)
    if angle <= -pi then
        return angle + 2 * pi
    end
    if angle > pi then
        return angle - 2 * pi
    end
    return angle
end

function ReedsSheppSolver:isInvalidAngle(theta)
    return theta < 0 or theta > pi
end


function ReedsSheppSolver:mod2Pi(theta)
    return theta - twoPi * floor(theta / twoPi)
end

function ReedsSheppSolver:LfSfLf(goal)
    -- Reeds-Shepp 8.1
    local t, u, v = 0, 0, 0

    local x = goal.x - goal.sint
    local y = goal.y - 1 + goal.cost

    u = sqrt(x * x + y * y)
    t = atan2(y, x)
    v = ReedsSheppSolver:wrapAngle(goal.t - t)

    if self:isInvalidAngle(t) or self:isInvalidAngle(v) then
        return huge
    end
    return t + u + v, t, u, v
end

function ReedsSheppSolver:LfSfLfpath(t, u, v)
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Straight, HybridAStar.Gear.Forward, u)
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, v)
    return actions
end

function ReedsSheppSolver:LfSfRf(goal)
    -- Reeds-Shepp 8.2
    local t, u, v = 0, 0, 0

    local x = goal.x + goal.sint
    local y = goal.y - 1 - goal.cost

    local u1squared = x * x + y * y
    local t1 = atan2(y, x)   

    if (u1squared < 4) then
        return huge
    end

    u = sqrt(u1squared - 4)
    local phi = atan2(2, u)
    t = ReedsSheppSolver:wrapAngle(t1 + phi)
    v = ReedsSheppSolver:wrapAngle(t - goal.t)

    if self:isInvalidAngle(t) or self:isInvalidAngle(v) then
        return huge
    end

    return t + u + v, t, u, v
end

function ReedsSheppSolver:LfSfRfpath(t, u, v)
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Straight, HybridAStar.Gear.Forward, u)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Forward, v)
    return actions
end

function ReedsSheppSolver:LfRbLf(goal)
    -- Reeds-Shepp 8.3
    -- Uses a modified formula adapted from the c_c_c function
    -- from http:--msl.cs.uiuc.edu/~lavalle/cs326a/rs.c
    local t, u, v = 0, 0, 0

    local xi = goal.x - goal.sint
    local eta =goal.y - 1 + goal.cost

    local u1 = sqrt(xi * xi + eta * eta)
    if u1 > 4 then
        return huge
    end

    local phi = atan2(eta, xi)
    local alpha = acos(u1 / 4)
    t = self:mod2Pi(piHalf + alpha + phi)
    u = self:mod2Pi(pi - 2 * alpha)
    v = self:mod2Pi(goal.t - t - u)
    if self:isInvalidAngle(t) or self:isInvalidAngle(u) or self:isInvalidAngle(v) then
        return huge
    end
    return t + u + v, t, u, v
end

function ReedsSheppSolver:LfRbLfpath(t, u, v)
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Backward, u)
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, v)
    return actions
end

function ReedsSheppSolver:LfRbLb(goal)
                                                                                                                                                            
    -- Reeds-Shepp 8.4
    -- Uses a modified formula adapted from the c_cc function
    -- from http:--msl.cs.uiuc.edu/~lavalle/cs326a/rs.c
    local t, u, v = 0, 0, 0

    local xi = goal.x - goal.sint
    local eta =goal.y - 1 + goal.cost

    local u1 = sqrt(xi * xi + eta * eta)
    if u1 > 4 then
        return huge
    end

    local phi = atan2(eta, xi)
    local alpha = acos(u1 / 4)
    t = self:mod2Pi(piHalf + alpha + phi)
    u = self:mod2Pi(pi - 2 * alpha)
    v = self:mod2Pi(t + u - goal.t)

    return t + u + v, t, u, v
end

function ReedsSheppSolver:LfRbLbpath(t, u, v)
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Backward, u)
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Backward, v)
    return actions
end

function ReedsSheppSolver:LfRfLb(goal)
    -- Reeds-Shepp 8.4
    -- Uses a modified formula adapted from the cc_c function
    -- from http:--msl.cs.uiuc.edu/~lavalle/cs326a/rs.c
    local t, u, v = 0, 0, 0

    local xi = goal.x - goal.sint
    local eta =goal.y - 1 + goal.cost

    local u1 = sqrt(xi * xi + eta * eta)
    if u1 > 4 then
        return huge
    end

    local phi = atan2(eta, xi)
    u = acos((8 - u1 * u1) / 8)
    local va = sin(u)
    local alpha = asin(2 * va / u1)
    t = self:mod2Pi(piHalf - alpha + phi)
    v = self:mod2Pi(t - u - goal.t)

    return t + u + v, t, u, v
end

function ReedsSheppSolver:LfRfLbpath(t, u, v)
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Forward, u)
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Backward, v)
    return actions
end

function ReedsSheppSolver:LfRufLubRb(goal)
    -- Reeds-Shepp 8.7
    -- Uses a modified formula adapted from the ccu_cuc function
    -- from http:--msl.cs.uiuc.edu/~lavalle/cs326a/rs.c
    local t, u, v = 0, 0, 0

    local xi = goal.x + goal.sint
    local eta =goal.y - 1 - goal.cost

    local u1 = sqrt(xi * xi + eta * eta)
    if u1 > 4 then
        return huge
    end

    local phi = atan2(eta, xi)

    if (u1 > 2) then
        local alpha = acos(u1 / 4 - 0.5)
        t = self:mod2Pi(piHalf + phi - alpha)
        u = self:mod2Pi(pi - alpha)
        v = self:mod2Pi(goal.t - t + 2 * u)
    else
        local alpha = acos(u1 / 4 + 0.5)
        t = self:mod2Pi(piHalf + phi + alpha)
        u = self:mod2Pi(alpha)
        v = self:mod2Pi(goal.t - t + 2 * u)
    end
    return t + u + u + v, t, u, v
end

function ReedsSheppSolver:LfRufLubRbpath(t, u, v)
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Forward, u)
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Backward, u)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Backward, v)
    return actions
end

function ReedsSheppSolver:LfRubLubRf(goal)
    -- Reeds-Shepp 8.8
    -- Uses a modified formula adapted from the c_cucu_c function
    -- from http:--msl.cs.uiuc.edu/~lavalle/cs326a/rs.c
    local t, u, v = 0, 0, 0

    local xi = goal.x + goal.sint
    local eta =goal.y - 1 - goal.cost

    local u1 = sqrt(xi * xi + eta * eta)
    if (u1 > 6) then
        return huge
    end

    local phi = atan2(eta, xi)
    local va1 = 1.25 - u1 * u1 / 16
    if va1 < 0 or va1 > 1 then
        return huge
    end

    u = acos(va1)
    local va2 =  sin(u)
    local alpha = asin(2 * va2 / u1)
    t = self:mod2Pi(piHalf + phi + alpha)
    v = self:mod2Pi(t - goal.t)

    return t + u + u + v, t, u, v
end

function ReedsSheppSolver:LfRubLubRfpath(t, u, v)
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Backward, u)
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Backward, u)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Forward, v)
    return actions
end

function ReedsSheppSolver:LfRbpi2SbLb(goal)
    -- Reeds-Shepp 8.9
    -- Uses a modified formula adapted from the c_c2sca function
    -- from http:--msl.cs.uiuc.edu/~lavalle/cs326a/rs.c
    local t, u, v = 0, 0, 0

    local xi = goal.x - goal.sint
    local eta =goal.y - 1 + goal.cost

    local u1squared = xi * xi + eta * eta
    if u1squared < 4 then
        return huge
    end

    local phi = atan2(eta, xi)

    u = sqrt(u1squared - 4) - 2
    if u < 0 then
        return huge
    end

    local alpha = atan2(2, u + 2)
    t = self:mod2Pi(piHalf + phi + alpha)
    v = self:mod2Pi(t + piHalf - goal.t)

    return t + piHalf + u + v, t, u, v
end

function ReedsSheppSolver:LfRbpi2SbLbpath(t, u, v)     
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Backward, piHalf)
    actions:addAction(HybridAStar.Steer.Straight, HybridAStar.Gear.Backward, u)
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Backward, v)
    return actions
end

function ReedsSheppSolver:LfRbpi2SbRb(goal)
    -- Reeds-Shepp 8.10
    -- Uses a modified formula adapted from the c_c2scb function
    -- from http:--msl.cs.uiuc.edu/~lavalle/cs326a/rs.c
    local t, u, v = 0, 0, 0

    local xi = goal.x + goal.sint
    local eta =goal.y - 1 - goal.cost

    local u1 = sqrt(xi * xi + eta * eta)
    if u1 < 2 then
        return huge
    end

    local phi = atan2(eta, xi)

    t = self:mod2Pi(piHalf + phi)
    u = u1 - 2
    v = self:mod2Pi(goal.t - t - piHalf)

    return t + piHalf + u + v, t, u, v
end

function ReedsSheppSolver:LfRbpi2SbRbpath(t, u, v)
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Backward, piHalf)
    actions:addAction(HybridAStar.Steer.Straight, HybridAStar.Gear.Backward, u)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Backward, v)
    return actions
end

function ReedsSheppSolver:LfSfRfpi2Lb(goal)
    -- Reeds-Shepp 8.9 (reversed)
    -- Uses a modified formula adapted from the csc2_ca function
    -- from http:--msl.cs.uiuc.edu/~lavalle/cs326a/rs.c
    local t, u, v = 0, 0, 0

    local xi = goal.x - goal.sint
    local eta =goal.y - 1 + goal.cost

    local u1squared = xi * xi + eta * eta
    if u1squared < 4 then
        return huge
    end

    local phi = atan2(eta, xi)

    u = sqrt(u1squared - 4) - 2
    if u < 0 then
        return huge
    end

    local alpha = atan2(u + 2, 2)
    t = self:mod2Pi(piHalf + phi - alpha)
    v = self:mod2Pi(t - piHalf - goal.t)

    return t + u + piHalf + v, t, u, v
end

function ReedsSheppSolver:LfSfRfpi2Lbpath(t, u, v)
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Straight, HybridAStar.Gear.Forward, u)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Forward, piHalf)
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Backward, v)
    return actions
end

function ReedsSheppSolver:LfSfLfpi2Rb(goal)
    -- Reeds-Shepp 8.10 (reversed)
    -- Uses a modified formula adapted from the csc2_cb function
    -- from http:--msl.cs.uiuc.edu/~lavalle/cs326a/rs.c
    local t, u, v = 0, 0, 0

    local xi = goal.x + goal.sint
    local eta =goal.y - 1 - goal.cost

    local u1 = sqrt(xi * xi + eta * eta)
    if u1 < 2 then
        return huge
    end

    local phi = atan2(eta, xi)

    t = self:mod2Pi(phi)
    u = u1 - 2
    v = self:mod2Pi(-t - piHalf + goal.t)

    return t + u + piHalf + v, t, u, v
end

function ReedsSheppSolver:LfSfLfpi2Rbpath(t, u, v)
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Straight, HybridAStar.Gear.Forward, u)
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, piHalf)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Backward, v)
    return actions
end

function ReedsSheppSolver:LfRbpi2SbLbpi2Rf(goal)
    -- Reeds-Shepp 8.11
    -- Uses a modified formula adapted from the c_c2sc2_c function
    -- from http:--msl.cs.uiuc.edu/~lavalle/cs326a/rs.c
    local t, u, v = 0, 0, 0

    local xi = goal.x + goal.sint
    local eta = goal.y - 1 - goal.cost

    local u1squared = xi * xi + eta * eta
    if u1squared < 16 then
        return huge
    end

    local phi = atan2(eta, xi)

    u = sqrt(u1squared - 4) - 4
    if u < 0 then
        return huge
    end

    local alpha = atan2(2, u + 4)
    t = self:mod2Pi(piHalf + phi + alpha)
    v = self:mod2Pi(t - goal.t)

    return t + u + v + pi, t, u, v
end

function ReedsSheppSolver:LfRbpi2SbLbpi2Rfpath(t, u, v)
    local actions = ReedsShepp.ActionSet()
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Forward, t)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Backward, piHalf)
    actions:addAction(HybridAStar.Steer.Straight, HybridAStar.Gear.Backward, u)
    actions:addAction(HybridAStar.Steer.Left, HybridAStar.Gear.Backward, piHalf)
    actions:addAction(HybridAStar.Steer.Right, HybridAStar.Gear.Forward, v)
    return actions
end