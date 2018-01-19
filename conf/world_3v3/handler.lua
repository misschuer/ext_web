-----------------------------------------------------------------------------------
--world_3v3------------------------------------------------------------------------
-----------------------------------------------------------------------------------

local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

local router_cls = require 'util.router_map'
local vaildArgs = router_cls.vaildArgs
local cache = require 'world_3v3.cache'
local manager = require 'world_3v3.manager'
local config = require 'world_3v3.config'

local _M = {}
function _M:init()
	-- 读数据库
	local db = dbAccess.getDBObj(conf.db_name )
	if not db then
		return
	end
	
	local cursor = db.match_rank_list:find()
	if cursor:hasNext() then
		local data = cursor:next()
		cache:SetRankInfo(data.rank_info)
	else
		db.match_rank_list:insert({indx = 1, rank_info='', update_time = os.time()})
	end	
	
	cursor = db.match_result_list:find()
	while cursor:hasNext() do
		local data = cursor:next()
		cache:SetMatchResult(data.player_guid, data.result_info)
	end
end

--队伍请求匹配
-- team_info = "id,score,id,score,id,score"
function _M:match()
	local args = vaildArgs({'group_guid', 'team_info', 'open_time'},{'open_time'}) 
	if not args then
		return
	end

	local params = string.split(args.team_info, ",")
	local userList = {}
	for i = 1, #params, 2 do
		local user = User:new {id = params[ i ], score = tonumber(params[i+1])}
		table.insert(userList, user)
	end
	
	-- 获得匹配列表信息
	local ret_tab = router_cls.opdata_with_lock(config.match_list, function() 
		return manager:match(args.group_guid, userList)
	end)	
	return ngx.print(json_encode(ret_tab))
end

--队伍中某个人取消匹配
function _M:cancel_match()
	local args = vaildArgs({'player_guid', 'open_time'},{'open_time'}) 
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_list, function() 
		return manager:cancel_match(args.player_guid)
	end)	
	return ngx.print(json_encode(ret_tab))	
end

-- 检测是否匹配到, 或者已经过期
function _M:check_match()
	local args = vaildArgs({'player_guid', 'open_time'},{'open_time'}) 
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_list, function() 
		return manager:check_match(args.player_guid)
	end)
	return ngx.print(json_encode(ret_tab))
end

-- 结果
function _M:match_result()
	local args = vaildArgs({'ret', 'open_time'},{'open_time'}) 
	if not args then
		return
	end
	
	--ngx.log(ngx.ERR, "match_result = ", args.ret)
	
	local ret = {}
	local infos = string.split(args.ret, ";")
	for _, info in pairs(infos) do
		local details = string.split(info, ",")
		local player_guid = details[1]
		local score  = tonumber(details[2])
		local honor  = tonumber(details[3])
		local result = tonumber(details[4])
		table.insert(ret, {player_guid=player_guid, score=score, honor=honor, result=result})
	end
	
	--ngx.log(ngx.ERR, "match_result ret length = ", #ret)
	
	local ret_tab = router_cls.opdata_with_lock(config.match_result, function() 
		return manager:match_result(ret)
	end)
	return ngx.print(json_encode(ret_tab))
end

-- 结果
function _M:check_match_result()
	local args = vaildArgs({'player_guid', 'open_time'},{'open_time'}) 
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_result, function() 
		return manager:check_match_result(args.player_guid)
	end)
	return ngx.print(json_encode(ret_tab))
end

-- 排行
function _M:rank()
	local args = vaildArgs({'player_guid', 'player_name', 'avatar', 'weapon', 'divine', 'score', 'force', 'gender'}, {'avatar', 'weapon', 'divine', 'score', 'force', 'gender'}) 
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_rank, function()
		return manager:rank(args.player_name, args.avatar, args.weapon, args.divine, args.score, args.player_guid, args.force, args.gender)
	end)
	return ngx.print(json_encode(ret_tab))
end

-- 更新排行
function _M:check_rank()
	local ret_tab = router_cls.opdata_with_lock(config.match_rank, function()
		return manager:check_rank()
	end)
	return ngx.print(json_encode(ret_tab))
end

-- 准备比赛
function _M:prepare_match()
	local args = vaildArgs({'player_guid', 'oper'}, {'oper'})
	if not args then
		return
	end
	
	local ret_tab = router_cls.opdata_with_lock(config.match_list, function()
		return manager:prepare_match(args.player_guid, args.oper)
	end)
	return ngx.print(json_encode(ret_tab))
end

-- 参数选择
function _M:extend(hanlder)
	hanlder['/world_3v3/match'] = self.match --队伍请求匹配
	hanlder['/world_3v3/cancel_match'] = self.cancel_match --队伍取消匹配
	hanlder['/world_3v3/check_match'] = self.check_match --检查匹配
	hanlder['/world_3v3/match_result'] = self.match_result --比赛结束, 存储奖励
	hanlder['/world_3v3/check_match_result'] = self.check_match_result --检查奖励
	hanlder['/world_3v3/rank'] = self.rank --进行排名
	hanlder['/world_3v3/check_rank'] = self.check_rank --更新排名
	hanlder['/world_3v3/prepare_match'] = self.prepare_match --准备比赛
end

return _M
