local module = {
    _version = "Vector.lua v2019.14.12",
    _description = "a simple Vector library for Lua based on the PVector class from processing",
    _url = "https://github.com/themousery/Vector.lua",
    _license = [[
    Copyright (c) 2018 themousery

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
  ]]
}

---@class Vector
Vector = CpObject()

-- get a random function from Love2d or base lua, in that order.
local rand = math.random
if love and love.math then rand = love.math.random end

-- makes a new Vector
function Vector:init(x,y)
    self.x, self.y = x, y
end

-- makes a new Vector from an angle
local function fromAngle(theta)
    return Vector(math.cos(theta), math.sin(theta))
end

-- makes a Vector with a random direction
local function random()
    return fromAngle(rand() * math.pi*2)
end

-- set the values of the Vector to something new
function Vector:set(x,y)
    if x:is_a(Vector) then self.x, self.y = x.x, x.y; return end
    self.x, self.y = x or self.x, y or self.y
    return self
end

-- replace the values of a Vector with the values of another Vector
function Vector:replace(v)
    assert(v:is_a(Vector), "replace: wrong argument type: (expected <Vector>, got "..type(v)..")")
    self.x, self.y = v.x, v.y
    return self
end

-- returns a copy of a Vector
function Vector:clone()
    return Vector(self.x, self.y)
end

-- get the magnitude of a Vector
function Vector:length()
    return math.sqrt(self.x^2 + self.y^2)
end

-- get the magnitude squared of a Vector
function Vector:lengthSquared()
    return self.x^2 + self.y^2
end

-- set the magnitude of a Vector
function Vector:setLength(mag)
    self:norm()
    local v = self * mag
    self:replace(v)
    return self
end

-- meta function to make Vectors negative
-- ex: (negative) -Vector(5,6) is the same as Vector(-5,-6)
function Vector.__unm(v)
    return Vector(-v.x, -v.y)
end

-- meta function to add Vectors together
-- ex: (Vector(5,6) + Vector(6,5)) is the same as Vector(11,11)
function Vector.__add(a,b)
    assert(a:is_a(Vector) and b:is_a(Vector), "add: wrong argument types: (expected <Vector> and <Vector>)")
    return Vector(a.x + b.x, a.y + b.y)
end

-- meta function to subtract Vectors
function Vector.__sub(a,b)
    assert(a:is_a(Vector) and b:is_a(Vector), "sub: wrong argument types: (expected <Vector> and <Vector>)")
    return Vector(a.x - b.x, a.y - b.y)
end

-- meta function to multiply Vectors
function Vector.__mul(a,b)
    if type(a) == 'number' then
        return Vector(a * b.x, a * b.y)
    elseif type(b) == 'number' then
        return Vector(a.x * b, a.y * b)
    else
        assert(a:is_a(Vector) and b:is_a(Vector),  "mul: wrong argument types: (expected <Vector> or <number>)")
        return Vector(a.x * b.x, a.y * b.y)
    end
end

-- meta function to divide Vectors
function Vector.__div(a,b)
    assert(a:is_a(Vector) and type(b) == "number", "div: wrong argument types (expected <Vector> and <number>)")
    return Vector(a.x / b, a.y / b)
end

-- meta function to check if Vectors have the same values
function Vector.__eq(a,b)
    assert(a:is_a(Vector) and b:is_a(Vector), "eq: wrong argument types (expected <Vector> and <Vector>)")
    return a.x==b.x and a.y==b.y
end

-- meta function to change how Vectors appear as string
-- ex: print(Vector(2,8)) - this prints '(2,8)'
function Vector:__tostring()
    return string.format('(%.2f, %.2f)', self.x, self.y)
end

-- get the distance between two Vectors
function Vector.dist(a,b)
    assert(a:is_a(Vector) and b:is_a(Vector), "dist: wrong argument types (expected <Vector> and <Vector>)")
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

-- return the dot product of the Vector
function Vector:dot(v)
    assert(v:is_a(Vector), "dot: wrong argument type (expected <Vector>)")
    return self.x * v.x + self.y * v.y
end

-- normalize the Vector (give it a magnitude of 1)
function Vector:norm()
    local m = self:length()
    if m ~= 0 then
        self:replace(self / m)
    end
    return self
end

-- limit the Vector to a certain amount
function Vector:limit(max)
    assert(type(max) == 'number', "limit: wrong argument type (expected <number>)")
    local mSq = self:magSq()
    if mSq > max ^ 2 then
        self:setLength(max)
    end
    return self
end

-- Clamp each axis between max and min's corresponding axis
function Vector:clamp(min, max)
    assert(min:is_a(Vector) and max:is_a(Vector), "clamp: wrong argument type (expected <Vector>) and <Vector>")
    local x = math.min( math.max( self.x, min.x ), max.x )
    local y = math.min( math.max( self.y, min.y ), max.y )
    self:set(x, y)
    return self
end

-- get the heading (direction) of a Vector
function Vector:heading()
    return math.atan2(self.y, self.x)
end

-- rotate a Vector by a certain number of degrees
function Vector:rotate(theta)
    local m = self:length()
    self:replace(fromAngle(self:heading() + theta))
    self:setLength(m)
    return self
end

-- return x and y of Vector as a regular array
function Vector:array()
    return {self.x, self.y}
end

-- return x and y of Vector, unpacked from table
function Vector:unpack()
    return self.x, self.y
end
