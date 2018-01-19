--------------------------------------------------------
--百万大战共享内存管理

require 'util.functions'
local dbAccess = require 'util.db_access'
local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode
local router_cls = require 'util.router_map'
--------------------------------



--------------------------------
local _M = {}

local _MW = ngx.shared.million_war_info
local _MWR =  ngx.shared.million_war_rank

--释放共享内存空间
function _M:dictFrush()
	_MW:flush_all()
	_MW:flush_expired()
end

--是否匹配过了
function _M:isMacth(jie)
	return _MW:get('is_macth#'..jie)
end

function _M:setMacth(jie)
	_MW:set('is_macth#'..jie,1,86400)
end

--今天的最低战斗力
function _M:getMinForce(jie,fenqu)
	return _MW:get('min_force#'..jie..'#'..fenqu)
end

function _M:setMinForce(jie,fenqu,force)
	_MW:set('min_force#'..jie..'#'..fenqu,force,86400)
end


--报名人数
function _M:getRegCount(jie,fenqu)
	return _MW:get('reg_count#'..jie..'#'..fenqu)
end

function _M:setRegCount(jie,fenqu,count)
	_MW:set('reg_count#'..jie..'#'..fenqu,count,86400)
end

function _M:addRegCount(jie,fenqu)
	local count = _M:getRegCount(jie,fenqu) or 0
	_M:setRegCount(jie,fenqu,count+1)
end


--匹配信息 以位置为key
function _M:getPosMacthInfo(round,fenqu,pos,jie) 
	return _MW:get('macth_info_pos#'..round..'#'..fenqu..'#'..pos..'#'..jie)
end
function _M:setPosMacthInfo(round,fenqu,pos,jie,info)
	_MW:set('macth_info_pos#'..round..'#'..fenqu..'#'..pos..'#'..jie,info,86400)
end

--匹配信息 以GUID为key
function _M:getGuidMacthInfo(round,guid,jie) 
	return _MW:get('macth_info_guid#'..round..'#'..guid..'#'..jie)
end
function _M:setGuidMacthInfo(round,guid,jie,info)
   _MW:set('macth_info_guid#'..round..'#'..guid..'#'..jie,info,7200)
end


--进场信息
function _M:getEnterInfo(jie,guid,round)
	return _MW:get('enter_info#'..jie..'#'..guid..'#'..round)
end

function _M:setEnterInfo(jie,guid,round,enter_info)
	_MW:set('enter_info#'..jie..'#'..guid..'#'..round,enter_info,7200)
end



--八强晋级列表
function _M:getBaQIangStr(fenqu,jie)
	return _MW:get('baqiang#'..jie..'#'..fenqu)
end

function _M:setBaQIangStr(fenqu,jie,str)
	_MW:set('baqiang#'..jie..'#'..fenqu,str,86400)
end



--历届霸主表
function _M:getChampionStr(fenqu,page)
	return _MWR:get('Champion#'..page..'#'..fenqu)
end

function _M:setChampionStr(fenqu,page,str)
	_MWR:set('Champion#'..page..'#'..fenqu,str)
end

--霸主榜总人数
function _M:getChampionCounts(fenqu)
	return _MWR:get('Champion_pages#'..fenqu)
end

function _M:setChampionCounts(fenqu,count)
	_MWR:set('Champion_pages#'..fenqu,count)
end

--配置信息
--function _M:getConfigInfo(fenqu)
--	return _MWR:get('million_war_config#'..fenqu)
--end
--
--function _M:setConfigInfo(fenqu,info)
--	return _MWR:get('million_war_config#'..fenqu,info)
--end



return  _M