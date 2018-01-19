TeamPart = class('TeamPart')

-- ITeamPart instance = TeamPart:new {userList = userList}
--¹¹Ôìº¯Êý
function TeamPart:ctor(...)
	local _, args = ...
	self.userList = args.userList
	
	local value = 0
	for _, user in pairs(self.userList) do
		value = value + user:getScore()
	end
	
	self.scores = value
	self.average = math.floor(self.scores / self:size())
end

function TeamPart:size()
	return #self.userList
end

function TeamPart:getScores()
	return self.scores
end

function TeamPart:getAverage()
	return self.average
end

function TeamPart:getUserIdList()
	local userIdList = {}
	
	for _, user in pairs(self.userList) do
		table.insert(userIdList, user:getId())
	end
	
	return userIdList
end

function TeamPart:contaisId(id)
	for _, user in pairs(self.userList) do
		if id == user:getId() then
			return true
		end
	end
	
	return false
end

function TeamPart:getCaptain()
	return self.userList[ 1 ]:getId()
end

function TeamPart.encode(obj)
	local datastrs = {}
	for _, user in ipairs(obj.userList) do
		table.insert(datastrs, User.encode(user))
	end
	return string.format("{\"userList\":[%s]}", string.join(",", datastrs))
end

function TeamPart.decode(obj)
	local objs = obj.userList
	local userList = {}
	for _, user_info in ipairs(objs) do
		local user = User.decode(user_info)
		table.insert(userList, user)
	end
	return TeamPart:new {userList = userList}
end