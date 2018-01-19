-----------------------------------------------------------------------------------
--world_xianfu------------------------------------------------------------------------
-----------------------------------------------------------------------------------
local cache = require 'world_xianfu.cache'
local dbAccess = require 'util.db_access'

local _M = {}

_M.max_user = 4
_M.match_list = "matchlist#"
_M.match_result = "matchresult#"
_M.match_money = "matchmoney#"
_M.match_prepare = "matchprepare#"
_M.prepare_time = 60
_M.rank_num = 1000

function _M:get_fenqu(open_time)
	return 1
end

return _M
