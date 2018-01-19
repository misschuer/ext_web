-----------------------------------------------------------------------------------
--world_gbt------------------------------------------------------------------------
-----------------------------------------------------------------------------------

local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local cache = require 'world_gbt.cache'
local config = require 'world_gbt.config'
local logger = require ('world_gbt.logger').new()

local _M = {}

--队伍请求匹配
function _M:match(fenqu, player_guid, battle_type)
	local match_info = cache:GetMatchInfo(player_guid)	
	if match_info then
		--已经匹配到了就直接进入
		if match_info.enter_info ~= nil then
			--清理自己的报名信息
			cache:SetMatchInfo(player_guid, nil)		
			
			--超时过来就取消匹配
			if match_info.match_time + config.enter_expiry < os.time() then
				--写一下玩家匹配日记
				logger:write_player_log(player_guid, match_info.enter_info.war_id, match_info.match_time, 'expiry')				
				return {ret = 4, msg = 'cancel'}
			end
			
			--写一下玩家匹配日记
			logger:write_player_log(player_guid, match_info.enter_info.war_id, match_info.match_time, 'success')			
			
			--正常过来发进场信息
			return {ret = 0, msg = 'success', enter_info = json_encode(match_info.enter_info)}
		end
		
		--正在匹配过程中直接返回
		local match_list = cache:GetMatchList(fenqu, battle_type)
		return {ret = 3, msg = 'matching', count = #match_list}
	else
		--没有匹配就尝试可否匹配
		local match_list = cache:GetMatchList(fenqu, battle_type)		
		if #match_list < config.match_number - 1 then
			--列表为空则加入匹配
			match_list[#match_list + 1] = player_guid 
			cache:SetMatchList(fenqu, battle_type, json_encode(match_list))
			
			--生成自己的报名信息
			local match_info = {}
			match_info.match_time = os.time()
			match_info.enter_info = nil
			cache:SetMatchInfo(player_guid, json_encode(match_info))
			
			--写一下玩家匹配日记
			logger:write_player_log(player_guid, string.format('0#0#%u#%u', fenqu, battle_type), match_info.match_time, 'addlist')
			
			return {ret = 2, msg = 'add match list'}
		else
			--找一个可用的战斗服
			local battle_server = self:choose_battle_server()
			if not battle_server then
				return {ret = 5, msg = 'can not find battle server'}			 
			end			
		
			--生成一个进场的信息
			local enter_info = {}
			enter_info.pos = 1	
			enter_info.war_id = string.format('%u#%u#%u#%u',os.time(), os.clock()*1000, fenqu, battle_type)
			enter_info.battle_server = battle_server		
		
			for _, match_guid in ipairs(match_list) do
				local match_info = cache:GetMatchInfo(match_guid)
				if match_info then
					--生成对手的匹配信息
					match_info.enter_info = enter_info	
					match_info.match_time = os.time()
					cache:SetMatchInfo(match_guid, json_encode(match_info))
				end
			end

			--更新一下列表的信息
			cache:SetMatchList(fenqu, battle_type, json_encode({}))		

			--写一下战场匹配日记
			match_list[#match_list + 1] = player_guid
			logger:write_match_log(fenqu, enter_info.war_id, battle_type, enter_info.battle_server, table.concat(match_list, ','))
			
			--写一下玩家匹配日记
			logger:write_player_log(player_guid, string.format('0#0#%u#%u', fenqu, battle_type), os.time(), 'addlist')
			logger:write_player_log(player_guid, enter_info.war_id, os.time(), 'success')
			
			--生成自己的匹配信息	
			return {ret = 0, msg = 'success', enter_info = json_encode(enter_info)}
		end
	end
end

--队伍取消匹配
function _M:cancel_match(fenqu, player_guid, battle_type)
	--先从列表里面移除掉
	local match_list = cache:GetMatchList(fenqu, battle_type)
	for index, match_guid in ipairs(match_list) do
		if match_guid == player_guid then
			table.remove(match_list, index)
			break
		end
	end			
	cache:SetMatchList(fenqu, battle_type, json_encode(match_list))

	--写一下玩家匹配日记
	local match_info = cache:GetMatchInfo(player_guid)
	if match_info then
		if match_info.enter_info and match_info.enter_info.war_id then
			logger:write_player_log(player_guid, match_info.enter_info.war_id, match_info.match_time, 'cancel')
		else
			logger:write_player_log(player_guid, string.format('0#0#%u#%u', fenqu, battle_type), match_info.match_time, 'cancel')
		end
	end	

	--清理自己的报名信息
	cache:SetMatchInfo(player_guid, nil)	
	return {ret = 0, msg = 'success'}
end

--选一个战斗服
function _M:choose_battle_server()
	local db = dbAccess.getDBObj(conf.db_name )
	if not db then
		return nil
	end
	
	local where = {}
	where['reg_time'] = {['$gte'] = os.time() - 660}	
	local cursor = db.battle_server_list:find(where,{})
	local result = {}
	while cursor:hasNext() do
		local data = cursor:next()
		result[#result + 1] = data
	end
	
	if #result > 0 then
		local index = math.random(1, 10000) % (#result) + 1
		return result[index].server_info
	else
		return nil
	end
end

return _M
