-- 加定频率任务
function addFixRateTask(delay, callback, args, nextTime)
	nextTime = nextTime or delay
	local handler
	handler = function (premature, args, nextTime)
		-- do some routine job in Lua just like a cron job
		if callback then
			callback(args)
		end
		
		if premature then
			return
		end
		local ok, err = ngx.timer.at(nextTime, handler, args, nextTime)
		if not ok then
			ngx.log(ngx.ERR, "failed to create the timer: ", err)
			return
		end
	end
	
	local ok, err = ngx.timer.at(delay, handler, args, nextTime)
	if not ok then
		ngx.log(ngx.ERR, "failed to create the timer: ", err)
		return
	end
end