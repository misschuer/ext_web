-----------------------------------------------------------------------------------
--world_boss-----------------------------------------------------------------------
-----------------------------------------------------------------------------------

require 'util.functions'
local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode
local router_cls = require 'util.router_map'
local cache = ngx.shared.world_boss_cache



local _M = {}

--分组编号
function _M:SetGroup(server_name, gid)
	local key = string.format("server#%s", server_name)
	cache:set(key, gid)
end
function _M:GetGroup(server_name)
	local key = string.format("server#%s", server_name)
	return 1--cache:get(key) --腾讯无战区区别
end

--房间信息
function _M:SetRoomInfo(gid, room_info)
	local key = string.format("room_info#gid#%u#%s", gid, os.date('%Y%m%d'))
	local cur_date = os.date('*t', os.time())
	cur_date.hour = 0
	cur_date.sec = 0
	cur_date.min = 0
	local due_time = os.time(cur_date) + 86400 - os.time()
	
	cache:set(key, room_info, due_time)		
end
function _M:GetRoomInfo(gid)
	local key = string.format("room_info#gid#%u#%s", gid, os.date('%Y%m%d'))
	local info = cache:get(key)
	if info then
		return json_decode(info)
	else
		return nil
	end		
end

--怪物信息
function _M:SetBossInfo(gid, boss_info)
	local key = string.format("boss_info#gid#%u#%s", gid, os.date('%Y%m%d'))
	local cur_date = os.date('*t', os.time())
	cur_date.hour = 0
	cur_date.sec = 0
	cur_date.min = 0
	local due_time = os.time(cur_date) + 86400 - os.time()
	
	cache:set(key, boss_info, due_time)		
end
function _M:GetBossInfo(gid)
	local key = string.format("boss_info#gid#%u#%s", gid, os.date('%Y%m%d'))
	return cache:get(key)	
end

--拾取列表
function _M:SetPickInfo(gid, pick_info)
	local key = string.format("pick_info#gid#%u", gid)
	cache:set(key, pick_info)		
end
function _M:GetPickInfo(gid)
	local key = string.format("pick_info#gid#%u", gid)
	return cache:get(key)	
end


return _M