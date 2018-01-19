--日志管理类
local MillionWarLogMgr = class('MillionWarLogMgr')

--日志类型枚举
LOG_TYPE_MATCH			= 1			--百万大战匹配日志
LOG_TYPE_ENTER			= 2			--进场日志
LOG_TYPE_REG			= 3			--报名百万大战
LOG_TYPE_FIGHT_RESULT	= 4			--战报日志
LOG_TYPE_TABLE			= 5			--匹配取表日志

--构造函数
function MillionWarLogMgr:ctor()
	self.log_path_prefix = os.date("%Y-%m-%d-%H")
	self.file_maps = {}		--{[文件名] = 对应的file句柄,}
end

--校验下文件日期，如果隔天了，那就得把之前的文件句柄close了
function MillionWarLogMgr:checkFileName()
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
function MillionWarLogMgr:getFile(typed)
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
function MillionWarLogMgr:getPath(typed)
	local logname = {
		[LOG_TYPE_MATCH] 	= "MILLION_WAR_MATCH_LOG",	
		[LOG_TYPE_ENTER]	= "MILLION_WAR_ENTER_LOG",
		[LOG_TYPE_REG]		= "MILLION_WAR_REG_LOG",
		[LOG_TYPE_FIGHT_RESULT] = "MILLION_WAR_FIGHT_RESULT_LOG",
		[LOG_TYPE_TABLE] 	= "MILLION_WAR_TABLE_LOG",
	}
	
	return string.format('data/%s_%d_%s.log', self.log_path_prefix, ngx.worker.pid(), logname[typed])	
end

--百万大战匹配日志
--[[
@fenqu:分区
@jie:第几届
@members：该分区总报名人数
@max_member：配置里的最大允许报名人数
@min_force：最小要求身价
@realnum:实际参数人数（包括机器人）
@index:匹配信息索引
@guid：玩家guid
@name：玩家name
@force：玩家身价
]]
function MillionWarLogMgr:writeMatchLog(fenqu, jie, members, max_member, min_force, realnum, 
			index, guid, name, force, new_player)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_MATCH)
	if(file)then
		file:write(string.format("%d %s %s %s %s %s %s %s %s %s %s %s\n", os.time(), 
			fenqu, jie, members, max_member, min_force, realnum, index, guid, name, force, new_player))		
		file:flush()
	end	
end

--百万大战进场日志
--[[
@guid:玩家guid
@jie:第几届
@round:第几轮
@war_id：场次id
@duishou_guid：对手guid
@battle_server：战斗服地址
]]
function MillionWarLogMgr:writeEnterLog(guid, jie, round, war_id, duishou_guid, battle_server)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_ENTER)
	if(file)then
		file:write(string.format("%d %s %s %d %s %s %s\n", os.time(), 
			guid, jie, tonumber(round), tostring(war_id), duishou_guid, battle_server))		
		file:flush()
	end	
end

--百万大战报名
--[[
@guid:玩家guid
@name:玩家名字
@ret:报名结果0成功非0失败
@msg:成功失败信息
]]
function MillionWarLogMgr:writeRegLog(guid, name, ret, msg)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_REG)
	if(file)then
		file:write(string.format("%d %s %s %d %s\n", os.time(), 
			guid, name, ret, msg))		
		file:flush()
	end	
end


--百万大战战报
--[[
@winner_guid:胜利玩家guid
@round：第几轮
]]
function MillionWarLogMgr:writeFightResultLog(winner_guid, round)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_FIGHT_RESULT)
	if(file)then
		file:write(string.format("%d %s %s\n", os.time(), 
			winner_guid, round))		
		file:flush()
	end	
end

--百万大战取表日志
--[[
table_name:表名
]]
function MillionWarLogMgr:writeTableLog(table_name)
	self:checkFileName()
	local file = self:getFile(LOG_TYPE_TABLE)
	if(file)then
		file:write(string.format("%s %s\n", os.date("%H:%M:%S"), table_name))		
		file:flush()
	end	
end

return MillionWarLogMgr