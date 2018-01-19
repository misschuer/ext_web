require('util.functions')

require('match.config.CombineExpandConfig')
require('match.config.MatchConfig')
require('match.config.MatchExpandConfig')

require('match.CombineTRExpander')
require('match.MatchProcessor')
require('match.MatchProcessorNotifier')
require('match.MatchTask')
require('match.MatchTRExpander')
require('match.TeamPart')
require('match.User')

MatchController = {}

function MatchController:onMatching(matchProcessor)
	matchProcessor:organizeTeam()
end

--[[
	user = {id = id, score = score}
	userList = {user1, user2}
--]]
function MatchController:submitMatchTask(matchProcessor, userList)	
	local teamPart = TeamPart:new{userList = userList}
	local task = MatchTask:new{partList = {teamPart}}
	
	matchProcessor:submitMatch(task)
end

function MatchController:IsInMatching(matchProcessor, userIdList)
	matchProcessor:decode()
	
	for _, player_guid in pairs(userIdList) do
		local task = matchProcessor:getMatchTask(player_guid)
		if task then
			return true
		end
	end
	
	return false
end

function MatchController:cancelMatch(matchProcessor, player_guid)
	matchProcessor:cancelMatch(player_guid)
end