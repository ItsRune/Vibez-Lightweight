--!strict
--[=[
	@class Ranking
	A lightweight module to handle all requests sent to https://vibez.dev/
]=]
--[=[
	@prop GroupId Number
	@within Ranking
]=]
--[=[
	@prop _key string
	@private
	@within Ranking
]=]
--[=[
	@prop _origin string
	@private
	@within Ranking
]=]
--[=[
	@prop _requestCaches { [string]: any }
	@private
	@within Ranking
]=]

local GroupService = game:GetService("GroupService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Definitions = require(script.Definitions)
local Result = require(script.Packages.Result)
local RateLimit = require(script.RateLimit)

local Vibez = {}
local Class = {}

Class.__index = Class

type Public = {
	_key: string,
	_origin: string,
	_requestCaches: { [string]: any },
	GroupId: number,
	_limiter: RateLimit.RateLimitKind,
}
type Private = typeof(Class)
export type VibezRankingKind = typeof(setmetatable({} :: Public, {} :: Private))

--[=[
	@ignore
	@function unpackResult
	Unpacks a result value into a usable return value.
	@within Ranking
]=]
local function unpackResult<T, E>(result: Result.Result<T, E>): T | E
	return result:isOk() and result:unwrap() or result:unwrapErr()
end

--[=[
	Constructs a new Vibez wrapper with the specified key.
	@within Ranking
	@return Ranking
]=]
function Vibez.new(apiKey: string): VibezRankingKind
	assert(typeof(apiKey) == "string", "Vibez Error: API Key must be a string!")

	local self = setmetatable({}, Class) :: VibezRankingKind

	self._key = apiKey
	self._origin = game:GetFullName()
	self._requestCaches = { groupInfo = {} }
	self._limiter = RateLimit.new(60, 60)
	self.GroupId = self:getGroupId()

	if self.GroupId == -1 then
		setmetatable(self :: any, nil)
		self = nil :: any
		error("Invalid API Key!", 2)
	end

	return self
end

--[=[
	@method _sendHttpRequest
	Sends an HTTP request with the api key (if a vibez route was determined to be the host).
	@within Ranking
	@return BaseHttpResponse
	@private
]=]
function Class._sendHttpRequest<T>(
	self: VibezRankingKind,
	route: string,
	method: string?,
	headers: { [string]: any }?,
	body: { [any]: any }?
): Definitions.BaseHttpResponse
	local canContinue, err = self._limiter:Check()
	if not canContinue then
		local message = `You are being rate limited! {tostring(err)}`
		return Result.err({
			Success = false,
			StatusCode = 429,
			StatusMessage = message,
			rawBody = "{}",
			Headers = {
				["Content-Type"] = "application/json",
			},
			Body = {
				success = false,
				errorMessage = message,
			},
		})
	end

	route = string.sub(route, 1, 1) == "/" and route or "/" .. route
	method = typeof(method) == "string" and string.upper(method) or "GET"

	local heads = headers or { ["Content-Type"] = "application/json" }
	if heads["x-api-key"] == nil then
		heads["x-api-key"] = self._key
	end

	if not body and method ~= "GET" and method ~= "HEAD" then
		body = {}
	elseif body ~= nil and (method == "GET" or method == "HEAD") then
		body = nil
	end

	if string.match(route, "http") == nil then
		route = "https://leina.vibez.dev" .. route
	else
		heads["x-api-key"] = nil :: any
	end

	if string.match(route, "leina.vibez") ~= nil and typeof(body) == "table" then
		body.origin = `{self._origin}{RunService:IsStudio() and " (Studio Play-Test)" or ""}`
	end

	local isOk, bodyJson = pcall(HttpService.JSONEncode, HttpService, body)
	if not isOk and body ~= nil then
		return Result.err("Invalid request body!")
	end

	local Options = {
		Url = route,
		Method = method,
		Headers = heads,
		Body = (body ~= nil) and bodyJson or nil,
	}

	local wasOk, response = pcall(HttpService.RequestAsync, HttpService, Options :: any)
	if wasOk and response.Success then
		local newOk, responseJson = pcall(HttpService.JSONDecode, HttpService, response.Body :: any)
		response.Body = newOk and responseJson or response.Body
	end

	return Result.ok(response)
end

--[=[
	@method getGroupId
	Fetches the group associated with the api key.
	@param overrideKey string?
	@return number

	@yields
	@within Ranking
]=]
---
function Class.getGroupId(self: VibezRankingKind, overrideKey: string?): number
	if self.GroupId ~= nil and self.GroupId ~= -1 then
		return self.GroupId
	end

	local result = self:_sendHttpRequest("/ranking/groupid", "post", {
		["x-api-key"] = overrideKey or self._key,
	})
	if result:isErr() then
		return -1
	end

	return result:unwrap().Body.groupId
end

--[=[
	@method setRank
	Sets the rank of a player and `whoCalled` (Optional) is used for logging purposes.
	@param self Ranking
	@param User Player | string | number
	@param whoCalled { userName: string, userId: number }?
	@return SetRankResponse

	@yields
	@within Ranking
]=]
---
function Class.setRank(
	self: VibezRankingKind,
	User: Player | string | number,
	rankId: string | number,
	whoCalled: { userName: string, userId: number }?
): any | string
	local userId = self:_verifyUser(User, "UserId")
	local userName = self:_verifyUser(User, "Name")
	local roleId = self:_getRoleIdFromRank(rankId)

	if not whoCalled then
		whoCalled = {
			userName = "SYSTEM",
			userId = -1,
		}
	end

	if not tonumber(userId) then
		return Result.err("Parameter 'userId' must be a valid number.")
	end

	if not tonumber(roleId) then
		return Result.err("Parameter 'rankId' is an invalid rank.")
	end

	local body = {
		userToRank = {
			userId = tonumber(userId),
			userName = userName,
		},
		userWhoRanked = whoCalled,
		userId = tonumber(userId),
		rankId = tonumber(roleId),
	}

	local result = self:_sendHttpRequest("/ranking/changerank", "post", nil :: any, body)
	return unpackResult(result)
end

--[=[
	@method Promote
	Promotes a player and `whoCalled` (Optional) is used for logging purposes.
	@param self Ranking
	@param User Player | string | number
	@param whoCalled { userName: string, userId: number }?
	@return rankResponse

	@yields
	@within Ranking
]=]
---
function Class.Promote(
	self: VibezRankingKind,
	User: Player | string | number,
	whoCalled: { userName: string, userId: number }?
): Definitions.SetRankResponse
	local userId = self:_verifyUser(User, "UserId")
	local userName = self:_verifyUser(User, "Name")

	if not whoCalled then
		whoCalled = {
			userName = "SYSTEM",
			userId = -1,
		}
	end

	if not tonumber(userId) then
		return {
			success = false,
			message = "Parameter 'userId' must be a valid number.",
		} :: any
	end

	local response = self:_sendHttpRequest("/ranking/promote", "post", nil :: any, {
		userToRank = {
			userId = tostring(userId),
			userName = userName,
		},
		userWhoRanked = whoCalled,
		userId = tostring(userId),
	})

	return response:unwrap().Body
end

--[=[
	@method Demote
	Demotes a player and `whoCalled` (Optional) is used for logging purposes.
	@param self Ranking
	@param User Player | string | number
	@param whoCalled { userName: string, userId: number }?
	@return rankResponse

	@yields
	@within Ranking
]=]
---
function Class.Demote(
	self: VibezRankingKind,
	User: Player | string | number,
	whoCalled: { userName: string, userId: number }?
): Definitions.SetRankResponse | Definitions.Error
	local userId = self:_verifyUser(User, "UserId")
	local userName = self:_verifyUser(User, "Name")

	if not whoCalled then
		whoCalled = {
			userName = "SYSTEM",
			userId = -1,
		}
	end

	if not tonumber(userId) then
		return {
			success = false,
			message = "Parameter 'userId' must be a valid number.",
		} :: any
	end

	local response = self:_sendHttpRequest("/ranking/demote", "post", nil, {
		userToRank = {
			userId = tostring(userId),
			userName = userName,
		},
		userWhoRanked = whoCalled,
		userId = tostring(userId),
	})

	if response:isErr() then
		return response
	end

	return response:unwrap().Body
end

--[=[
	@method Fire
	Fires a player and `whoCalled` (Optional) is used for logging purposes.
	@param self Ranking
	@param User Player | string | number
	@param whoCalled { userName: string, userId: number }?
	@return rankResponse

	@yields
	@within Ranking
]=]
---
function Class.Fire(
	self: VibezRankingKind,
	User: Player | string | number,
	whoCalled: { userName: string, userId: number }?
): boolean
	local userId = self:_verifyUser(User, "UserId")
	local userName = self:_verifyUser(User, "Name")

	if not whoCalled then
		whoCalled = {
			userName = "SYSTEM",
			userId = -1,
		}
	end

	if not tonumber(userId) then
		-- Parameter 'userId' must be a valid number.
		return false
	end

	local response = self:_sendHttpRequest("/ranking/fire", "post", nil, {
		userToRank = {
			userId = tostring(userId),
			userName = userName,
		},
		userWhoRanked = whoCalled,
		userId = tostring(userId),
	})

	return response:isOk() and true or false
end

--[=[
	@method getActivity
	Gets a player's or everyone's current activity
	@param User Player | string | number
	@param sorted boolean? -- Only when fetching all user activities.
	@return activityResponse

	@within Ranking
	@since 0.3.0
]=]
---
function Class.getActivity(
	self: VibezRankingKind,
	User: Player | string | number,
	sorted: boolean?
): Definitions.FetchUserActivityResponse
	local userId = self:_verifyUser(User, "UserId")
	local body: any = { userId = userId }

	if User ~= nil and not userId then
		return {
			success = false,
			message = "Invalid user was supplied.",
		} :: any
	elseif not userId then
		body = nil
	end

	local response = self:_sendHttpRequest("/activity/fetch2", "post", nil, body)
	if response:isErr() then
		return {
			success = false,
			message = response:unwrapErr(),
		} :: any
	end

	local result = response:unwrap().Body
	local newResult = {} :: { Definitions.FetchUserActivityResponse }

	if userId ~= nil then
		return result
	end

	for i, v in pairs(result) do
		v.userId = tonumber(i)
		table.insert(newResult, v)
	end

	if sorted then
		table.sort(newResult, function(a, b)
			return a.secondsUserHasSpent > b.secondsUserHasSpent
		end)
	end

	return newResult :: Definitions.FetchUserActivityResponse
end

--[=[
	@method removeActivity
	Negates the player's activity seconds & message counts. (Does not clear detail logs array.)
	@param User Player | string | number
	@return boolean

	@yields
	@within Ranking
	@since 0.11.0
]=]
---
function Class.removeActivity(
	self: VibezRankingKind,
	User: Player | string | number
): Definitions.SaveUserActivityResponse | Definitions.InfoResponse
	local userId = self:_verifyUser(User, "UserId") :: number
	if not userId then
		return {
			success = false,
			message = "Supplied user was not valid.",
		}
	end

	-- Get the current activity and negate the activity to remove it. (Temporary Solution)
	local rawResponse = self:getActivity(userId) :: Definitions.FetchUserActivityResponse
	if not rawResponse.success then
		return rawResponse :: any
	end

	local userGroupInformation = self:_getGroupFromUser(self.GroupId :: number, userId)
	if userGroupInformation:isErr() then
		return {
			success = false,
			message = userGroupInformation:unwrapErr(),
		}
	end

	local secondsSpent = rawResponse.secondsUserHasSpent
	local messagesSent = rawResponse.messagesUserHasSent
	local fixedSeconds, fixedMessages =
		(secondsSpent == 0) and 0 or -secondsSpent, (messagesSent == 0) and 0 or -messagesSent

	return self:saveActivity(userId, userGroupInformation:unwrap().Rank, fixedSeconds, fixedMessages)
end

--[=[
	@method saveActivity
	Saves the player's current activity
	@param User Player | string | number
	@param userRank number
	@param secondsSpent number
	@param messagesSent (number | { string })?
	@param shouldFetchGroupRank boolean?
	@return httpResponse

	@yields
	@within Ranking
	@since 0.3.0
]=]
---
function Class.saveActivity(
	self: VibezRankingKind,
	User: Player | string | number,
	userRank: number,
	secondsSpent: number?,
	messagesSent: (number | { string })?,
	shouldFetchGroupRank: boolean?
): Definitions.SaveUserActivityResponse | Definitions.InfoResponse
	local userId = self:_verifyUser(User, "UserId") :: number
	messagesSent = (typeof(messagesSent) == "table") and #messagesSent
		or (tonumber(messagesSent) ~= nil) and messagesSent
		or nil
	userRank = (typeof(userRank) == "number" or tonumber(userRank) ~= nil) and userRank or -1

	if not tonumber(messagesSent) then
		return {
			success = false,
			message = "Cannot save activity with an invalid 'number' as the 'messagesSent' parameter!",
		}
	elseif not tonumber(secondsSpent) then
		return {
			success = false,
			message = "Cannot save activity with an invalid 'number' as the 'secondsSpent' parameter!",
		}
	end

	if shouldFetchGroupRank == true then
		local groupData = self:_getGroupFromUser(self.GroupId, userId)
		if groupData:isErr() then
			return {
				success = false,
				message = groupData:unwrapErr(),
			}
		end

		if typeof(groupData:unwrap()) ~= "table" then
			return {
				success = false,
				message = "Could not fetch group data.",
			}
		end

		userRank = groupData:unwrap().Rank
	end

	secondsSpent, messagesSent = tonumber(secondsSpent), tonumber(messagesSent)

	local response = self:_sendHttpRequest("/activity/save2", "post", nil, {
		userId = userId,
		userRank = userRank,
		secondsUserHasSpent = secondsSpent,
		messagesUserHasSent = messagesSent,
	})

	if response:isErr() then
		return response:unwrapErr()
	end

	return response:unwrap().Body
end

--[=[
	@method addBlacklist
	Adds a blacklist to your api key.
	@param userToBlacklist (Player string | number)
	@param Reason string?
	@param blacklistExecutedBy (Player string | number)?
	@return blacklistResponse

	@within Ranking
	@since 0.6.0
]=]
---
function Class.addBlacklist(
	self: VibezRankingKind,
	userToBlacklist: Player | string | number,
	Reason: string?,
	blacklistExecutedBy: Player | string | number
): (boolean, string)
	local userId, reason, blacklistedBy =
		nil, (typeof(Reason) ~= "string" or Reason == "") and "Unknown." or Reason, nil

	if not userToBlacklist then
		return false, "Invalid user was supplied."
	elseif not blacklistExecutedBy then
		blacklistExecutedBy = -1
	end

	userId = self:_verifyUser(userToBlacklist, "UserId")
	blacklistedBy = self:_verifyUser(blacklistExecutedBy, "UserId")

	local response = self:_sendHttpRequest(`/blacklists/{userId}`, "put", nil, {
		reason = reason,
		blacklistedBy = blacklistedBy,
	})

	if response:isErr() then
		return false, response:unwrapErr()
	end

	local unwrapped = response:unwrap()
	if not unwrapped.Success or not unwrapped.Body.success then
		return false, unwrapped.Body.message or "Internal server error."
	end

	return true, unwrapped.Body.message
end

--[=[
	@method deleteBlacklist
	Deletes a blacklist from your api key.
	@param userToDelete (Player string | number)
	@return BlacklistResponse | InfoResponse

	@within Ranking
	@since 0.6.0
]=]
---
function Class.deleteBlacklist(self: VibezRankingKind, userToDelete: Player | string | number): (boolean, string)
	if not userToDelete then
		-- An invalid user was supplied.
		return false, "Invalid user was supplied."
	end

	local userId = self:_verifyUser(userToDelete, "UserId")
	local response = self:_sendHttpRequest(`/blacklists/{userId}`, "delete")

	if response:isErr() then
		return false, response:unwrapErr()
	end

	return true, response:unwrap().Body.message
end

--[=[
	@method getBlacklists
	Gets either a full list of blacklists or checks if a player is currently blacklisted.
	@param userId (string | number | Player)?
	@return BlacklistResponse | UserBlacklistResponse

	@within Ranking
	@since 0.6.0
]=]
---
function Class.getBlacklists(self: VibezRankingKind, userId: (string | number | Player)?): Definitions.BlacklistResponse
	userId = (userId ~= nil) and self:_verifyUser(userId, "UserId") or ""
	local response = self:_sendHttpRequest(`/blacklists/{userId}`)

	if response:isErr() then
		return {
			success = false,
			message = response:unwrapErr(),
		} :: any
	end

	local unwrapped = response:unwrap()
	if not unwrapped.Success or not unwrapped.Body.success then
		return unwrapped.Body
	elseif unwrapped.Body.blacklists ~= nil then
		return unwrapped.Body.blacklists
	end

	unwrapped.Body.success = nil
	return unwrapped.Body
end

--[=[
	@method isUserBlacklisted
	Gets either a full list of blacklists or checks if a player is currently blacklisted.
	@param User Player | string | number
	@return (boolean, string?, string?)

	@within Ranking
	@since 0.6.0
]=]
---
function Class.isUserBlacklisted(self: VibezRankingKind, User: Player | string | number): ...any
	local userId = self:_verifyUser(User, "Id")
	local blacklistData = self:getBlacklists(userId)

	local data: { any } = {
		blacklistData.isBlacklisted,
		blacklistData.details.reason,
		blacklistData.details.blacklistedBy,
	}

	return table.unpack(data)
end

--[=[
	@method _getGroupFromUser
	Uses roblox's group service to get a player's rank.
	@param groupId number
	@param userId number
	@return Result<{ Rank: number?, Role: string?, Id: number?, errMessage: string? }, string>

	@yields
	@private
	@within Ranking
	@since 0.1.0
]=]
---
--stylua: ignore
function Class._getGroupFromUser(
	self: VibezRankingKind,
	groupId: number,
	userId: number,
	force: boolean?,
	useOverride: boolean?
): Result.Result<{ Rank: number, Role: string, Id: number }, string>
	if self._requestCaches.groupInfo[userId] ~= nil and not force then
		return Result.ok(self._requestCaches.groupInfo[userId])
	end

	if RunService:IsStudio() and useOverride then
		return Result.err("Studio override for permission check.")
	end

	local isOk, data: { [any]: any } | string = pcall(GroupService.GetGroupsAsync, GroupService, userId)
	local possiblePlayer = Players:GetPlayerByUserId(userId)
	local found = nil

	if not isOk then
		return Result.err("Failed to fetch group data for '" .. userId .. "'; Fake data provided.")
	end

	for _, groupData in pairs(data) do
		if groupData.Id == groupId then
			found = groupData
			break
		end
	end

	if typeof(found) == "table" then
		self._requestCaches.groupInfo[userId] = found
		return Result.ok(found)
	end

	if possiblePlayer ~= nil then
		local rankOk, rank = pcall(possiblePlayer.GetRankInGroup, possiblePlayer, groupId)
		local roleOk, role = pcall(possiblePlayer.GetRoleInGroup, possiblePlayer, groupId)

		if rankOk and roleOk then
			return Result.ok({
				Id = groupId,
				Role = role,
				Rank = rank,
			})
		end
	end

	return Result.ok({
		Id = self.GroupId,
		Role = "Guest",
		Rank = 0,
	})
end

--[=[
	@method _verifyUser
	Ensures that the parameter returns the proper type associated to the `typeToReturn`
	@param self Ranking
	@param User Player | number | string
	@param typeToReturn "UserId" | "Player" | "Name"
	@return number | string | Player

	@private
	@within Ranking
]=]
function Class._verifyUser(
	self: VibezRankingKind,
	User: Player | number | string,
	typeToReturn: "UserId" | "Player" | "Name" | "Id"
): Player | number | string
	if typeof(User) == "Instance" and User:IsA("Player") then
		if typeToReturn == "UserId" or typeToReturn == "Id" then
			return User.UserId
		elseif typeToReturn == "Name" then
			return User.Name
		elseif typeToReturn == "Player" then
			return User
		end
	elseif typeof(User) == "string" then
		if typeToReturn == "UserId" or typeToReturn == "Id" then
			return (tonumber(User) or self:_getUserIdByName(User))
		elseif typeToReturn == "Name" then
			return User
		elseif typeToReturn == "Player" then
			return Players:FindFirstChild(User) :: Player
		end
	elseif typeof(User) == "number" then
		if typeToReturn == "UserId" or typeToReturn == "Id" then
			return User
		elseif typeToReturn == "Name" then
			return self:_getNameById(User)
		elseif typeToReturn == "Player" then
			return Players:GetPlayerByUserId(User) :: Player
		end
	end

	return User
end

--[=[
	@method _getUserIdByName
	Gets a player's user identifier via their username.
	@param username string
	@return number?

	@yields
	@private
	@within Ranking
]=]
---
function Class._getUserIdByName(_self: VibezRankingKind, username: string): number
	local isOk, userId = pcall(Players.GetUserIdFromNameAsync, Players, username)
	return isOk and userId or -1
end

--[=[
	@method _getNameById
	Gets a player's username by their userId
	@param userId number
	@return string?

	@yields
	@private
	@within Ranking
]=]
---
function Class._getNameById(_self: VibezRankingKind, userId: number): string
	local fixedUserId = tonumber(userId)
	if not fixedUserId then
		return tostring(userId)
	end

	local isOk, userName = pcall(Players.GetNameFromUserIdAsync, Players, fixedUserId)
	return isOk and userName or "Unknown"
end

--[=[
	@method _getRoleIdFromRank
	Gets the role id of a rank.
	@param rank number | string
	@return number?

	@yields
	@private
	@within Ranking
]=]
---
function Class._getRoleIdFromRank(self: VibezRankingKind, rank: number | string): number?
	-- Don't use normal HTTP function, it'll send the api key.
	local url = `https://groups.roproxy.com/v1/groups/{self.GroupId}/roles`
	local isOk, response = pcall(HttpService.GetAsync, HttpService, url)
	local decodedResponse = nil

	if not isOk then
		return nil
	end

	isOk, decodedResponse = pcall(HttpService.JSONDecode, HttpService, response)

	if not isOk then
		return nil
	end

	local toSearch = "rank"
	local canBeNumber = (tonumber(rank) ~= nil)

	if not canBeNumber then
		toSearch = "name"
	end

	for _, roleData in pairs(decodedResponse.roles) do
		if string.lower(tostring(roleData[toSearch])) == string.lower(tostring(rank)) then
			return roleData.id
		end
	end

	return nil
end

--[=[
	@method setLoggingOriginationText
	When triggering any method within this module, a header called 'origin' is sent to describe where the method took place in. (Default is the name of your game)
	@param rank number | string
	@return number?

	@yields
	@private
	@within Ranking
]=]
---
function Class.setLoggingOriginationText(self: VibezRankingKind, text: string): ()
	self._origin = tostring(text)
end

return Vibez
