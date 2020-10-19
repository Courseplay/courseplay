--This is a Generic First -> Last LinkedList
--Courseplay Interface should be a LinkedListSetting

LinkedList = CpObject()

function LinkedList:init(...)
	self.First = nil
	self.count = -1
	self:addToEmptyList(...)
	self.debug = false
end

LinkedNode = {}
function LinkedNode:new(_next,_data)
	local o = {}
	o.Next = _next
	o.data = _data
	return o
end

--add methods
function LinkedList:addLast(...)	
	local node = self:iterateToEnd(self.First)
	node.Next = LinkedNode:new(nil,...)
	self:incrementCount()
	self:printLinkedList()
end

function LinkedList:addFirst(...)
	local First = self.First.Next
	local node = LinkedNode:new(First,...)
	self.First.Next = node
	self:incrementCount()
	self:printLinkedList()
end

--remove methos 
function LinkedList:removeLast()
	if self:isEmpty() then 
		return false
	end
	local node = self:iterateByIndex(self.count-1)
	local Last = node.Next
	node.Next = nil
	self:decrementCount()
end

function LinkedList:removeFirst()
	if self:isEmpty() then 
		return false
	end
	local node = self.First.Next
	self.First.Next = node.Next
	self:decrementCount()
end

function LinkedList:removeX(index)
	if self:isEmpty() then 
		return false
	end
	local preNode = self:getElementByIndex(index-1)
	local node = self:getElementByIndex(index)
	if not node then 
		return false
	end
	if preNode and preNode ~= self.First then 
		preNode.Next = node.Next 
		self:decrementCount()
	else
		self:removeFirst()
	end
	self:printLinkedList()
	return true
end

--shift Node methods
function LinkedList:swapUpX(index)
	local prePreNode = self:getElementByIndex(index-2)
	if prePreNode then 
		local preNode = prePreNode.Next
		if preNode then
			local node = preNode.Next
			if node then 
				local nextNode = node.Next 
				prePreNode.Next = node
				node.Next = preNode
				preNode.Next = nextNode
			end
		end
	else
		local preNode = self:getElementByIndex(index-1)
		if preNode then 
			local node = preNode.Next
			if node then 
				local nextNode = node.Next
				node.Next = preNode
				preNode.Next = nextNode
				self.First.Next = node
			end
		end
	end
	self:printLinkedList()
end

function LinkedList:swapDownX(index)
	local preNode = self:getElementByIndex(index-1)
	if preNode then 
		local node = preNode.Next
		if node then
			local nextNode = node.Next
			if nextNode then 
				local nextNextNode = nextNode.Next
				preNode.Next = nextNode
				nextNode.Next = node
				node.Next = nextNextNode
			end
		end
	else
		--node = self.First.Next
		local node = self:getElementByIndex(index)
		if node then
			local nextNode = node.Next
			if nextNode then 
				local nextNextNode = nextNode.Next
				nextNode.Next = node
				node.Next = nextNextNode
				self.First.Next = nextNode
			end
		end
	end
	self:printLinkedList()
end

--print List
function LinkedList:printLinkedList()
	if self:isEmpty() or not self.debug then 
		return false
	end	
	local node = self.First.Next
	index = 1
	while node ~=nil do
		self:printLinkedNode(node,index)
		node = node.Next
		index = index+1
	end
end

--local helpers
function LinkedList:addToEmptyList(...)
	local node = LinkedNode:new(nil,self.First,...)
	self.First=node
	self:incrementCount()
end

function LinkedList:isEmpty()
	if self.count > 0 then 
		return false
	else
	--	print("LinkedList is empty!!!!!")
		return true
	end
end

function LinkedList:iterateBeforeX(X)
	local node = self.First
	while X.Prev ~= node do 
		node = node.Next
	end
end

function LinkedList:iterateAfterX(X)
	local node = self.Last
	while X.Next ~= node do 
		node = node.Prev
	end
end

function LinkedList:printLinkedNode(X,index)
	if X == nil or not self.debug then 
		return
	end	
	if type(X.data) == "table" then
		print(index..": ")
		for _,value in pairs(X.data) do 
			print("     ".._..": "..value)
		end
	else
		print(index..": "..tostring(X.data))
	end
end

function LinkedList:iterateByIndex(index)
	if index <1 then 
		return
	end
	
	local node = self.First
	i=1
	for i=1,index do 
		node = node.Next
		
		if node == nil then 
			return
		end
	end
	return node
end

function LinkedList:iterateToEnd(node)
	while node.Next ~=nil do 
		node=node.Next
	end
	return node
end

function LinkedList:incrementCount()
	self.count = self.count+1
end

function LinkedList:decrementCount()
	self.count = self.count-1
end

--getters
function LinkedList:getFirst()
	return self.First.Next
end

function LinkedList:getSize()
	return self.count
end

function LinkedList:getElementByIndex(index)
	local node = self:iterateByIndex(index)
	self:printLinkedNode(node,index)
	return node
end

function LinkedList:getDataXtoY(x,y)	
	local node = self:iterateByIndex(x)
	local totalData = {}
	local i=x
	while node ~=nil do 
		totalData[i]=node.data
		if i==y then
			break 
		end
		node=node.Next
		i=i+1
	end
	return totalData
end


function LinkedList:getData()
	local node = self.First.Next
	local totalData = {}
	i=1
	while node ~=nil do 
		self:printLinkedNode(node,i)
		totalData[i]=node.data
		node=node.Next
		i=i+1
	end
	return totalData
end