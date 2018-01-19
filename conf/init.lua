local handler_map = handler_map or {}

-- 载入天梯匹配的算法
require 'match.MatchController'

_M = require 'world_3v3.handler' 
_M:extend(handler_map)
_M:init()

_M = require 'world_xianfu.handler'
_M:extend(handler_map)
_M:init()

-- 组队副本
_M = require 'group_instance.handler' 
_M:extend(handler_map)
_M:init()

require 'timer.timer'

local world_3v3_config = require 'world_3v3.config'
local router_cls = require 'util.router_map'
local world_3v3_cache = require 'world_3v3.cache'

function startTimer()
	-- 3v3匹配
	if 0 == ngx.worker.id() then
		addFixRateTask(0.1, function()
			router_cls.opdata_with_lock(world_3v3_config.match_list, function()
				world_3v3_config.matchProcessor:organizeTeam()
				return
			end)
		end)

	end
	
	-- 每周清空排行榜
	if 1 == ngx.worker.id() then
		local delay = GetNextWeekXStartTimeFromNow(1)
		local nextTime = GetWeekDiffTime()
		addFixRateTask(delay, function()
			router_cls.opdata_with_lock(world_3v3_config.match_rank, function()
				world_3v3_cache:SetRankInfo('', true)
				return
			end)
		end, nil, nextTime)
		
	end
end

return handler_map
