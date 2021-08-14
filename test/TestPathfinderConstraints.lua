---@class TestPathfinderConstraints : PathfinderConstraintInterface
TestPathfinderConstraints = CpObject(PathfinderConstraintInterface)

function TestPathfinderConstraints:init(obstacles, fruit)
	self:resetConstraints()
	self.obstacles = obstacles
	self.fruit = fruit
	local vehicleData = {createSquare = function () return end}
	self.context = {hitchLength = 10, vehicleData = vehicleData}
end

---@param node State3D
---@param userdata table
function TestPathfinderConstraints:isValidNode(node)
	for _, obstacle in ipairs(self.obstacles) do
		local isInObstacle = node.x >= obstacle.x1 and node.x <= obstacle.x2 and node.y >= obstacle.y1 and node.y <= obstacle.y2
		if isInObstacle then
			return false
		end
	end
	return true
end

function TestPathfinderConstraints:getNodePenalty(node)
	if not self.fruit then return 0 end
	for _, fruit in ipairs(self.fruit) do
		local isInObstacle = node.x >= fruit.x1 and node.x <= fruit.x2 and node.y >= fruit.y1 and node.y <= fruit.y2
		if isInObstacle then
			return 200
		end
	end
	return 0
end

function TestPathfinderConstraints:isValidAnalyticSolutionNode(node)
	local fruitValue = self:getNodePenalty(node)
	if fruitValue > self.fruitLimit then return false end
	return self:isValidNode(node)
end

function TestPathfinderConstraints:relaxConstraints()
	print('Relaxing fruit limit to math.huge')
	self.fruitLimit = math.huge
end

function TestPathfinderConstraints:resetConstraints()
	print('Resetting fruit limit to 100')
	self.fruitLimit = 100
end
