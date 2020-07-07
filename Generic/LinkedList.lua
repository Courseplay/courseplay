LinkedList = CpObject()

function LinkedList:init(...)
	self.First = nil
	self.count = -1
	self:addToEmptyList(...)
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
	local LastNode = self:iterateToEnd(self.First)
	local node = LinkedNode:new(nil,...)
	LastNode.Next = node
	self:incrementCount()
	self:printLinkedList()
end

function LinkedList:addFirst(...)
	local First = self.First
	local node = LinkedNode:new(First,...)
	self.First = node
	self:incrementCount()
end

--remove methos 

function LinkedList:removeLast()
	if self:isEmpty() then 
		return false
	end
	local node = self.Last
	self.Last = self.Last.Prev
	self.Last.Next = nil
	self:decrementCount()
	return true
end

function LinkedList:removeFirst()
	if self:isEmpty() then 
		return false
	end
	local node = self.First.Next
	self.First.Next = node.Next
	self:decrementCount()
	return true
end

function LinkedList:removeX(index)
	if self:isEmpty() then 
		return false
	end
	local preNode = self:getElementByIndex(index-1)
	if preNode then 
		local node = preNode.Next 
		preNode.Next = node.Next
		self:decrementCount()
	else
		self:removeFirst()
	end
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
end

--print methods

function LinkedList:printLinkedList()
	if self:isEmpty() then 
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
	self.Last=node
	self:incrementCount()
end

function LinkedList:isEmpty()
	if self.count > 0 then 
		return false
	else
		print("LinkedList is empty!!!!!")
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

function LinkedList:printLinkedNode(X,index )
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

function LinkedList:incrementCount()
	self.count = self.count+1
end

function LinkedList:decrementCount()
	self.count = self.count-1
end


function LinkedList:iterateToEnd(node)
	while node.Next ~=nil do 
		node=node.Next
	end
	return node
end

function LinkedList:getData()
	local node = self.First.Next
	local totalData = {}
	i=1
	while node ~=nil do 
		totalData[i]=node.data
		node=node.Next
		i=i+1
	end
	return totalData
end

--getters

function LinkedList:getFirst()
	return self.First
end


function LinkedList:getSize()
	return self.count
end


function LinkedList:getElementByIndex(index)
	return self:iterateByIndex(index)
end







