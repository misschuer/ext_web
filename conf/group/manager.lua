-----------------------------------------------------------------------------------
--world_3v3------------------------------------------------------------------------
-----------------------------------------------------------------------------------

local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local cache = require 'world_3v3.cache'
--local config = require 'world_3v3.config'

local _M = {}

--队伍请求匹配
function _M:match(group_guid, groupInfo)
	
end

--队伍取消匹配
function _M:cancel_match(group_guid)
	
	return {ret = 0, msg = 'success'}
end

--进入圣兽房间
function _M:enter_saint_beast_room(fenqu, saint_beast_type)
	if not self:is_valid_room(saint_beast_type) then
		return {ret = 4, msg = 'is not valid room'}
	end

	if not self:is_valid_time() then
		return {ret = 5, msg = 'is not valid time'}
	end	
	
	local room_info = cache:GetSaintBeastRoomInfo(fenqu, saint_beast_type)
	--房间进入信息已经生成
	if room_info then
		--房间已满不准进入
		if room_info.group_count >= config.saint_beast_room_max_group_count then
			return {ret = 3, msg = 'the room is full'}
		
		--房间不满允许进入
		else
			room_info.group_count = room_info.group_count + 1	
		end
	
	--房间进入信息还未生成
	else
		--找个可用的战斗服
		local battle_server = self:choose_battle_server()
		if not battle_server then
			return {ret = 2, msg = 'can not find battle_server'}			 
		end		
	
		--初始化房间的信息
		room_info = {}
		room_info.war_id = string.format('%u#%u#saint_beast#%s', fenqu, saint_beast_type, os.date('%Y%m%d'))
		room_info.pos = 1
		room_info.battle_server = battle_server
		room_info.group_count = 1
		room_info.group_infos = json_encode({}) --让地图过来同步
		room_info.drop_count = 0
	end
	
	--保存一下圣兽房间信息
	local room_info_to_json = json_encode(room_info)
	cache:SetSaintBeastRoomInfo(fenqu, saint_beast_type, room_info_to_json)	

	--保存到数据库中持久化
	local db = dbAccess.getDBObj(conf.db_name)
	if db then
		local wheres = {}
		wheres._id = string.format('fenqu#%u#saint_beast_type#%u#date#%s', fenqu, saint_beast_type, os.date('%Y%m%d'))
		
		local value = {}
		value.date = os.date('%Y%m%d')
		value.fenqu = fenqu
		value.saint_beast_type = saint_beast_type
		value.room_info = room_info_to_json
		db.world_3v3_saint_beast_room_info:update(wheres, {["$set"] = value}, true, false)
	end	

	local enter_info = {}
	enter_info.war_id = room_info.war_id
	enter_info.pos = room_info.pos
	enter_info.battle_server = room_info.battle_server
	return {ret = 0, msg = 'success', enter_info = json_encode(enter_info)}	
end

--查询圣兽房间
function _M:query_saint_beast_room(fenqu, saint_beast_type)
	if saint_beast_type == 0 then
		local room_info = {}
		for saint_beast_type = 1, config.saint_beast_room_max_type, 1 do
			local info = cache:GetSaintBeastRoomInfo(fenqu, saint_beast_type)	
			if info == nil then
				room_info['' .. saint_beast_type] = {group_count = 0, group_infos = nil, drop_count = 0}
			else
				room_info['' .. saint_beast_type] = {group_count = info.group_count, group_infos = info.group_infos, drop_count = info.drop_count}
			end
		end
	
		return {ret = 0, msg = 'success', room_info = room_info}
	else
		local room_info = {}
		local info = cache:GetSaintBeastRoomInfo(fenqu, saint_beast_type)
		if info == nil then
			room_info['' .. saint_beast_type] = {group_count = 0, group_infos = nil, drop_count = 0}
		else
			room_info['' .. saint_beast_type] = {group_count = info.group_count, group_infos = info.group_infos, drop_count = info.drop_count}
		end

		return {ret = 0, msg = 'success', room_info = room_info}
	end
end

--同步队伍人数
function _M:sync_group_count(fenqu, saint_beast_type, group_count, group_infos)
	if not self:is_valid_room(saint_beast_type) then
		return {ret = 4, msg = 'is not valid room'}
	end

	if not self:is_valid_time() then
		return {ret = 5, msg = 'is not valid time'}
	end	
	
	local room_info = cache:GetSaintBeastRoomInfo(fenqu, saint_beast_type)
	--没有房间信息就不管了
	if room_info == nil then	
		return {ret = 2, msg = 'can not find room'}	
	end

	--更新一下圣兽房间信息	
	room_info.group_count = group_count
	room_info.group_infos = group_infos
	local room_info_to_json = json_encode(room_info)
	cache:SetSaintBeastRoomInfo(fenqu, saint_beast_type, room_info_to_json)	

	--保存到数据库中持久化
	local db = dbAccess.getDBObj(conf.db_name)
	if db then
		local wheres = {}
		wheres._id = string.format('fenqu#%u#saint_beast_type#%u#date#%s', fenqu, saint_beast_type, os.date('%Y%m%d'))
		
		local value = {}	
		value.room_info = room_info_to_json
		db.world_3v3_saint_beast_room_info:update(wheres, {["$set"] = value}, true, false)
	end	

	return {ret = 0, msg = 'success', group_count = group_count}		
end

--同步掉落个数
function _M:sync_drop_count(fenqu, saint_beast_type, drop_count)
	if not self:is_valid_room(saint_beast_type) then
		return {ret = 4, msg = 'is not valid room'}
	end

	if not self:is_valid_time() then
		return {ret = 5, msg = 'is not valid time'}
	end	

	local room_info = cache:GetSaintBeastRoomInfo(fenqu, saint_beast_type)
	--没有房间信息就不管了
	if room_info == nil then	
		return {ret = 2, msg = 'can not find room'}	
	end
	
	--人数没有变化不保存了
	if room_info.drop_count == drop_count then
		return {ret = 3, msg = 'no change'}
	end

	--更新一下圣兽房间信息	
	room_info.drop_count = drop_count
	local room_info_to_json = json_encode(room_info)
	cache:SetSaintBeastRoomInfo(fenqu, saint_beast_type, room_info_to_json)	

	--保存到数据库中持久化
	local db = dbAccess.getDBObj(conf.db_name)
	if db then
		local wheres = {}
		wheres._id = string.format('fenqu#%u#saint_beast_type#%u#date#%s', fenqu, saint_beast_type, os.date('%Y%m%d'))
		
		local value = {}	
		value.room_info = room_info_to_json
		db.world_3v3_saint_beast_room_info:update(wheres, {["$set"] = value}, true, false)
	end	

	return {ret = 0, msg = 'success', drop_count = drop_count}		
end

--请求宝箱信息
function _M:get_box_info(fenqu, info_time)
	return {ret = 0, msg = 'success', box_info = cache:GetBoxInfo(fenqu, info_time)}
end

--推送宝箱信息
function _M:set_box_info(fenqu, guid, name)
	local box_info = cache:GetBoxInfo(fenqu, os.time())
	if box_info then
		return {ret = 2, msg = 'already opened'}
	end
	
	box_info = {}
	box_info.guid = guid
	box_info.name = name

	--设置一下宝箱开启信息
	local box_info_to_json = json_encode(box_info)
	cache:SetBoxInfo(fenqu, os.time(), box_info_to_json)	

	--保存到数据库中持久化
	local db = dbAccess.getDBObj(conf.db_name)
	if db then
		local wheres = {}
		wheres._id = string.format('fenqu#%u#box_info#%s', fenqu, os.date('%Y%m%d'))
		
		local value = {}
		value.fenqu = fenqu
		value.box_info = box_info_to_json
		value.time = os.time()
		db.world_3v3_box_info:update(wheres, {["$set"] = value}, true, false)
	end		
	
	return {ret = 0, msg = 'success'}
end


--是否有效房间
function _M:is_valid_room(saint_beast_type)
	return saint_beast_type >= 1 and saint_beast_type <= config.saint_beast_room_max_type
end	

--是否有效时间
function _M:is_valid_time()
	return os.date('*t').hour >= 8
end

--选一个战斗服
function _M:choose_battle_server(use_battle_server_1, use_battle_server_2)
	local db = dbAccess.getDBObj(conf.db_name )
	if not db then
		return nil
	end
	
	local where = {}
	where['reg_time'] = {['$gte'] = os.time() - 660}
	local cursor = db.battle_server_list:find(where,{})
	local result = {}
	local seletc_result = {}	
	while cursor:hasNext() do
		local data = cursor:next()
		result[#result + 1] = data
		if data.server_info ~= use_battle_server_1 and data.server_info ~= use_battle_server_2 then
			seletc_result[#seletc_result + 1] = data
		end
	end

	if #seletc_result ~= 0 then
		result = seletc_result
	end
	
	-- DEBUG 本地调试模式下的
	for _, result_value in pairs(result) do
		if string.find(result_value.server_info, "65534") then
			return result_value.server_info
		end
	end

	if #result > 0 then
		local index = math.random(1, 10000) % (#result) + 1
		return result[index].server_info
	else
		return nil
	end
end

return _M
