--[[
This file is part of Courseplay (https:--github.com/Courseplay/courseplay)
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
along with this program.  If not, see <http:--www.gnu.org/licenses/>.

This implementation is based on
Matt Bradley's master thesis and his C# code at
https:--github.com/mattbradley/AutonomousCar
--]]

---@class GridCell
GridCell = CpObject()

function GridCell:init(c, r)
    self.c = c
    self.r = r
end

---@class GridCellValue
GridCellValue = CpObject()

---@param cell GridCell
function GridCellValue:init(cell, value)
    self.cell = cell
    self.value = value
end

function GridCellValue:lt(other)
    return self.value < other.value
end

---@class Grid
Grid = CpObject()

function Grid:init(resolution, width, height, origin)
    self.resolution = resolution
    self.diagonalResolution = resolution * math.sqrt(2)
    self.numColumns = math.ceil(width / resolution)
    self.numRows = math.ceil(height / resolution)
    self.origin = origin
end

---@param cell GridCell
function Grid:pointToCellPosition(point)
    local x = point.x - self.origin.x
    local y = point.y - self.origin.y
    local c = math.floor(x / self.resolution)
    local r = math.floor(y / self.resolution)
    if c >= 0 and c < self.numColumns and r >= 0 and r < self.numRows then
        return GridCell(c, r)
    else
        return nil
    end
end

---@param cell GridCell
function Grid:cellToPointPosition(cell)
    return self:cellPositionToPointPosition(cell.c, cell.r)
end

function Grid:cellPositionToPointPosition(c, r)
    local x = c * self.resolution
    local y = r * self.resolution
    x = x + self.origin.x
    y = y + self.origin.y
    return {x = x, y = y}
end

function Grid:get8Neighbors(cell)
    local c = cell.c
    local r = cell.r
    local cm = c - 1 > 0
    local cp = c + 1 <= self.numColumns
    local rm = r - 1 > 0
    local rp = r + 1 <= self.numRows

    local neighbors = {}

    if cm then
        table.insert(neighbors, GridCell(c - 1, r))
        if rm then table.insert(neighbors, GridCell(c - 1, r - 1)) end
        if rp then table.insert(neighbors, GridCell(c - 1, r + 1)) end
    end

    if cp then
        table.insert(neighbors, GridCell(c + 1, r))
        if rm then table.insert(neighbors, GridCell(c + 1, r - 1)) end
        if rp then table.insert(neighbors, GridCell(c + 1, r + 1)) end
    end

    if rm then table.insert(neighbors, GridCell(c, r - 1)) end
    if rp then table.insert(neighbors, GridCell(c, r + 1)) end

    return neighbors
end

---@param cell GridCell
function Grid:occupied(cell, isValidNodeFunc)
    local pos = self:cellToPointPosition(cell)
    local occupied = not isValidNodeFunc(pos)
    if occupied then
        local pos = self:cellPositionToPointPosition(cell.c, cell.r)
    end
    return occupied
end

---The NonholonomicRelaxed class implements the holonomic-with-obstacles heuristic. This heuristic is calculated using Djikstra's algorithm on the
--- obstacle grid. This heuristic value is the 8-neighbor path length from the pose cell to the goal cell. It considers obstacles but ignores the
--- turning radius constraint of the vehicle.
---@class NonholonomicRelaxed
NonholonomicRelaxed = CpObject()
local sqrt2 = 1.4142135623730950488016887242097
NonholonomicRelaxed.discount = 0.92621

---@param grid Grid
function NonholonomicRelaxed:init(grid)
    self.heuristic = {}
    self.expanded = {}
    self.grid = grid
    self.unit = grid.resolution * NonholonomicRelaxed.discount -- factor to discount the suboptimality of 8-neighbor paths
    self.minValue = math.huge
    self.maxValue = -math.huge
    self.count = 0
end

---@param goal State3D
function NonholonomicRelaxed:update(goal, isValidNodeFunc)
    -- this may help with lua performance by hinting the size of the 2D arrays
    self.heuristic[self.grid.numColumns] = {}
    self.expanded[self.grid.numColumns] = {}

    -- initialize heuristic
    for c = 1, self.grid.numColumns do
        self.heuristic[c] = {}
        self.expanded[c] = {}
        for r = 1, self.grid.numRows do
            self.heuristic[c][r] = math.huge
            self.expanded[c][r] = false
        end
    end

    local memorized = {}
    local startCell = self.grid:pointToCellPosition(goal)
    local openList = BinaryHeap.minUnique(function(a, b) return a:lt(b) end)

    self.heuristic[startCell.c][startCell.r] = 0
    local gridCellValue = GridCellValue(startCell, 0)
    openList:insert(gridCellValue, gridCellValue)

    while openList:size() > 0 do
        local cell = openList:pop().cell
        self.expanded[cell.c][cell.r] = true
        local neighbors = memorized[cell.c] and memorized[cell.c][cell.r] or nil
        if not neighbors then
            neighbors = self.grid:get8Neighbors(cell)
            if not memorized[cell.c] then memorized[cell.c] = {} end
            memorized[cell.c][cell.r] = neighbors
        end

        for _, n in ipairs(neighbors) do
            if self.grid:occupied(n, isValidNodeFunc) then
                --print('occ', n.c, n.r, self.heuristic[n.c][n.r])
            elseif not self.expanded[n.c][n.r] then
                local dist = (cell.c == n.c or cell.r == n.r) and 1 or sqrt2
                dist = dist + self.heuristic[cell.c][cell.r]
                if dist < self.heuristic[n.c][n.r] then
                    self.heuristic[n.c][n.r] = dist
                    self.count = self.count + 1
                    self.minValue = dist < self.minValue and dist or self.minValue
                    self.maxValue = dist > self.maxValue and dist or self.maxValue
                    local gridCellValue = GridCellValue(n, dist)
                    openList:insert(gridCellValue, gridCellValue)
                end
            end
        end
    end
    print('Heuristic updated ', self.count, self.minValue, self.maxValue)
end

---@param pose State3D
---@param goal State3D
function NonholonomicRelaxed:getHeuristicValue(pose, goal)
    local cell = self.grid:pointToCellPosition(pose)
    return math.max(self.unit * self.heuristic[cell.c][cell.r] - self.grid.diagonalResolution, goal:distance(pose))
end
