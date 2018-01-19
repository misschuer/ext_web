-----------------------------------------------------------------------------------
--world_gbt------------------------------------------------------------------------
-----------------------------------------------------------------------------------

local _M = {}

_M.enter_expiry = 120
_M.match_number = 9

_M.fenqu_change_divtime = 1480867200	--分区变更划分时间
_M.fenqu_divide_oldtime = 1478131200	--分区老的划分时间
_M.fenqu_divide_newtime = 1480867200	--分区新的划分时间

function _M:get_fenqu(open_time)
	return 1
	-- if os.time() < self.fenqu_change_divtime then
		-- if open_time < self.fenqu_divide_oldtime then
			-- return 1
		-- else
			-- return 2
		-- end
	-- else
		-- if open_time < self.fenqu_divide_newtime then
			-- return 1
		-- else
			-- return 2
		-- end	
	-- end
end

return _M
