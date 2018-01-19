local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

User = class('User')

-- IUser instance = User:new {id = id, score = score}
--¹¹Ôìº¯Êý
function User:ctor(...)
	local _, args = ...
	self.id = args.id
	self.score = args.score
end

function User:getScore()
	return self.score
end

function User:getId()
	return self.id
end

function User.encode(obj)
	return string.format("{\"id\":\"%s\",\"score\":%d}", obj.id, obj.score)
end

function User.decode(obj)
	return User:new {id = obj.id, score = obj.score}
end