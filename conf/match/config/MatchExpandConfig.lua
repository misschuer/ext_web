MatchExpandConfig = class('MatchExpandConfig')

-- IMatchExpandConfig instance = MatchExpandConfig:new {config = config}
--构造函数
function MatchExpandConfig:ctor(...)
	local _, args = ...
	self.config = args.config
end

-- 获得长度
function MatchExpandConfig:size()
	return #self.config
end

-- 获得元素
function MatchExpandConfig:get(index)
	if index < 1 or index > self:size() then
		return 0
	end
	return self.config[index]
end