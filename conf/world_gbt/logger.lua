--日志管理类
local logger = class('logger')

--日志类型枚举
LOG_TYPE_MATCH = 1 --匹配日志
LOG_TYPE_PLAYER = 2 -- 玩家日志

--构造函数
function logger:ctor()
	self.log_path_prefix = os.date("%Y-%m-%d-%H")
	self.file_maps = {}		--{[文件名] = 对应的file句柄,}
end

--校验下文件日期，如果隔天了，那就得把之前的文件句柄close了
function logger:checkFileName()
	local prefix = os.date("%Y-%m-%d-%H")
	if prefix ~= self.log_path_prefix then
		--先把之前打开的文件关了
		for file_name, file in pairs(self.file_maps) do
			local start = string.find(file_name, self.log_path_prefix)
			if start ~= nil and file then
				file:close()			
			end			
	    end
	    self.file_maps = {}
		--已经过了一天了
		self.log_path_prefix = prefix
	end	
end

--获得日志文件句柄
function logger:getFile(typed)
	local file_name = self:getPath(typed)
	local file = self.file_maps[file_name]
	--缓存里有
	if file then
		--ngx.log(ngx.ERR, string.format("ERROR: getFile cache file  %s", file_name))
		return file
	end
	
	--重新打开文件
	file = io.open(file_name, "a")
	self.file_maps[file_name] = file	--存入缓存
	return file
end

--获得日志文件的路径名
function logger:getPath(typed)
	local logname = {
		[LOG_TYPE_MATCH] 	= "GOLD_BATTLE_MATCH_LOG",	
		[LOG_TYPE_PLAYER] 	= "GOLD_BATTLE_PLAYER_LOG",	
	}
	
	return string.format('data/%s_%d_%s.log', self.log_path_prefix, ngx.worker.pid(), logname[typed])	
end

--开启场次日志
function logger:write_match_log(fenqu, war_id, war_type, battle_server, matchers)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_MATCH)
	if(file)then
		file:write(string.format("%d %d %s %d %s %s\n", os.time(), fenqu, war_id, war_type, battle_server, matchers))		
		file:flush()
	end	
end

--玩家匹配日志
function logger:write_player_log(player_guid, war_id, match_time, op_info)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_PLAYER)
	if(file)then
		file:write(string.format("%d %s %s %d %s\n", os.time(), player_guid, war_id, match_time, op_info))		
		file:flush()
	end	
end

return logger