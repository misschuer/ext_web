local json = require 'cjson'
local json_encode = json.encode
local json_decode = json.decode

MatchProcessorNotifier = class('MatchProcessorNotifier')
-- MatchProcessorNotifier = MatchProcessorNotifier:new {choose_battle_server_callback = choose_battle_server_callback}
--构造函数
function MatchProcessorNotifier:ctor(...)
	local _, args = ...
	self.choose_battle_server_callback = args.choose_battle_server_callback
	self.matchProcessor = args.matchProcessor
	self.prepare_time = args.prepare_time
end

function MatchProcessorNotifier:completed(task, position)
	local p1 = MatchTask.encode(task)
	local p2 = MatchTask.encode(position)
	--ngx.log(ngx.ERR, "p1 = ", p1)
	--ngx.log(ngx.ERR, "p2 = ", p2)
	
	local all_player_guid = {}
	self:get_all_player_guid(task    , all_player_guid)
	self:get_all_player_guid(position, all_player_guid)
	
	local leetGrougId = task:getCaptain()
	local riitGrougId = position:getCaptain()
	local war_id = string.format('%u#%u#%s#%s',os.time(), math.random(10, 100), leetGrougId, riitGrougId)
	local battle_server = self.choose_battle_server_callback()
	self:notice(task, war_id, 1, battle_server, all_player_guid)
	self:notice(position, war_id, 2, battle_server, all_player_guid)
end

function MatchProcessorNotifier:get_all_player_guid(task, all_player_guid)
	for _, teamPart in pairs(task.partList) do
		local userIdList = teamPart:getUserIdList()
		for _, player_guid in pairs(userIdList) do
			table.insert(all_player_guid, player_guid)
		end
	end
end

function MatchProcessorNotifier:notice(task, war_id, pos, battle_server, all_player_guid)
	-- 通知匹配完成
	local enter_info = {}
	enter_info.pos = pos
	enter_info.war_id = war_id
	enter_info.battle_server = battle_server
	
	local match_info = {}
	match_info.enter_info = enter_info
	match_info.all_player_guid = all_player_guid
	match_info.match_time = os.time()
	match_info.state = 0
	
	for _, teamPart in pairs(task.partList) do
		local userIdList = teamPart:getUserIdList()
		for _, player_guid in pairs(userIdList) do
			self.matchProcessor.cache:SetMatchInfo(player_guid, json_encode(match_info), self.prepare_time)
		end
	end
end

function MatchProcessorNotifier:cancel(task)
	local match_info = {}
	match_info.state = -1
	
	for _, teamPart in pairs(task.partList) do
		local userIdList = teamPart:getUserIdList()
		for _, player_guid in pairs(userIdList) do
			self.matchProcessor.cache:SetMatchInfo(player_guid, json_encode(match_info))
		end
	end
end
