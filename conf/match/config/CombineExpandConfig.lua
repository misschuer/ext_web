CombineExpandConfig = class('CombineExpandConfig')

-- ICombineExpandConfig instance = CombineExpandConfig:new {config = config}
--���캯��
function CombineExpandConfig:ctor(...)
	local _, args = ...
	self.config = args.config
end

-- ��ó���
function CombineExpandConfig:size()
	return #self.config
end

-- ���Ԫ��
function CombineExpandConfig:get(index)
	if index < 1 or index > self:size() then
		return 0
	end
	return self.config[index]
end