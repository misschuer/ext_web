-----------------------------------------------------------------------------------
--world_3v3------------------------------------------------------------------------
-----------------------------------------------------------------------------------
local cache = require 'world_3v3.cache'
local dbAccess = require 'util.db_access'

local _M = {}

_M.max_user = 3
_M.match_list = "matchlist#"
_M.match_result = "matchresult#"
_M.match_rank = "matchrank#"
_M.match_prepare = "matchprepare#"
_M.prepare_time = 60
_M.rank_num = 1000
_M.DIFF_TIME = 10

function _M:get_fenqu(open_time)
	return 1
end

-- 静态函数
function _M:initMatch3v3()
	local combineExpandConfig = CombineExpandConfig:new {config = {100, 200, 300, 400, 500, 600, 700, 800, 900, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800, 50000, 100000}}
	local matchExpandConfig = MatchExpandConfig:new {config = {50, 100, 150, 200, 250, 300, 350, 400, 450, 500, 550, 600, 650, 700, 750, 800, 850, 900, 50000, 100000}}
	local matchConfig = MatchConfig:new {userMax = _M.max_user, matchExpandConfig = matchExpandConfig, combineExpandConfig = combineExpandConfig}
	_M.matchProcessor = MatchProcessor:new {config = matchConfig, cache = cache}
	_M.matchProcessor:setNotifier(MatchProcessorNotifier:new{choose_battle_server_callback = _M.choose_battle_server, matchProcessor = _M.matchProcessor, prepare_time=_M.prepare_time})
end

--选一个战斗服
function _M.choose_battle_server()
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
		--ngx.log(ngx.ERR, "server_info:", data.server_info)
	end
	
	-- 这行需要删掉, DEBUG 本地调试模式下的
	----[[
	for _, result_value in pairs(result) do
		if string.find(result_value.server_info, "65534") then
			return result_value.server_info
		end
	end
	--]]

	if #result > 0 then
		local index = math.random(1, 10000) % (#result) + 1
		return result[index].server_info
	else
		ngx.log(ngx.ERR, "there is no battle_server")
		return nil
	end
end

-- 如果未初始化那就进行初始化
if not _M.matchProcessor then
	_M:initMatch3v3()
end

return _M
