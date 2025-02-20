--!strict
--[=[
    @class VibezLightweight
    A lightweight module to handle all requests sent to https://vibez.dev/
]=]
local GroupService = game:GetService("GroupService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Packages = script.Packages
local Definitions = require(script.Definitions)
local Result = require(Packages.Result)

local Vibez = {}
local Class = {}

Class.__index = Class

type Public = { _key: string, GroupId: number, requestCaches: { [string]: any } }
type Private = typeof(Class)
export type VibezLightweightKind = typeof(setmetatable({} :: Public, {} :: Private))

--[=[
	@ignore
	@function unpackResult
	Unpacks a result value into a usable return value.
	@within VibezLightweight
]=]
local function unpackResult<T, E>(result: Result.Result<T, E>): T | E
	return result:isOk() and result:unwrap() or result:unwrapErr()
end

--[=[
	Constructor method
	@within VibezLightweight
]=]
function Vibez.new(apiKey: string): VibezLightweightKind
	local self = setmetatable({}, Class)

	self._key = apiKey
	self.requestCaches = {}
	self.GroupId = self:getGroupId()

	if self.GroupId == -1 then
		setmetatable(self :: any, nil)
		self = nil :: any
		error("Invalid API Key!", 2)
	end

	return self
end

--[=[
    Sends an HTTP request with the api key (if a vibez route was determined to be the host).
    @within VibezLightweight
    @private
]=]
function Class._sendHttpRequest<T>(
	self: VibezLightweightKind,
	route: string,
	method: string?,
	headers: { [string]: any }?,
	body: { [any]: any }?
): Definitions.BaseHttpResponse
	route = string.sub(route, 1, 1) == "/" and route or "/" .. route
	method = typeof(method) == "string" and string.upper(method) or "GET"

	local heads = headers or { ["Content-Type"] = "application/json" }
	heads["x-api-key"] = self._key

	if not body and method ~= "GET" and method ~= "HEAD" then
		body = {}
	elseif body ~= nil and (method == "GET" or method == "HEAD") then
		body = nil
	end

	local isOk, bodyJson = pcall(HttpService.JSONEncode, HttpService, body)
	if not isOk and body ~= nil then
		return Result.err("Invalid request body!")
	end

	if string.match(route, "http") == nil then
		route = "https://leina.vibez.dev" .. route
	else
		heads["x-api-key"] = nil :: any
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
	Fetches the group associated with the api key.
	@return number | -1

	@yields
	@within VibezLightweight
]=]
---
function Class.getGroupId(self: VibezLightweightKind): number
	if self.GroupId ~= nil and self.GroupId ~= -1 then
		warn("returned")
		return self.GroupId
	end

	local result = self:_sendHttpRequest("/ranking/groupid", "post")
	if result:isErr() then
		return -1
	end

	return result:unwrap().Body.groupId
end

--[=[
	Sets the rank of a player and `whoCalled` (Optional) is used for logging purposes.
	@param self VibezLightweight
	@param User Player | string | number
	@param whoCalled { userName: string, userId: number }?
	@return rankResponse

	@yields
	@within VibezLightweight
]=]
---
function Class.setRank(
	self: VibezLightweightKind,
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
	Promotes a player and `whoCalled` (Optional) is used for logging purposes.
	@param self VibezLightweight
	@param User Player | string | number
	@param whoCalled { userName: string, userId: number }?
	@return rankResponse

	@yields
	@within VibezLightweight
]=]
---
function Class.Promote(
	self: VibezLightweightKind,
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
	Demotes a player and `whoCalled` (Optional) is used for logging purposes.
	@param self VibezLightweight
	@param User Player | string | number
	@param whoCalled { userName: string, userId: number }?
	@return rankResponse

	@yields
	@within VibezLightweight
]=]
---
function Class.Demote(
	self: VibezLightweightKind,
	User: Player | string | number,
	whoCalled: { userName: string, userId: number }?
): Result.Result<any, string>
	local userId = self:_verifyUser(User, "UserId")
	local userName = self:_verifyUser(User, "Name")

	if not whoCalled then
		whoCalled = {
			userName = "SYSTEM",
			userId = -1,
		}
	end

	if not tonumber(userId) then
		return Result.err("Parameter 'userId' must be a valid number.")
	end

	local _, response: any = self:_sendHttpRequest("/ranking/demote", "post", nil, {
		userToRank = {
			userId = tostring(userId),
			userName = userName,
		},
		userWhoRanked = whoCalled,
		userId = tostring(userId),
	})

	return response.Body
end

--[=[
	Fires a player and `whoCalled` (Optional) is used for logging purposes.
	@param self VibezLightweight
	@param User Player | string | number
	@param whoCalled { userName: string, userId: number }?
	@return rankResponse

	@yields
	@within VibezLightweight
]=]
---
function Class.Fire(
	self: VibezLightweightKind,
	User: Player | string | number,
	whoCalled: { userName: string, userId: number }?
): Result.Result<any, string>
	local userId = self:_verifyUser(User, "UserId")
	local userName = self:_verifyUser(User, "Name")

	if not whoCalled then
		whoCalled = {
			userName = "SYSTEM",
			userId = -1,
		}
	end

	if not tonumber(userId) then
		return Result.err("Parameter 'userId' must be a valid number.")
	end

	local _, response: any = self:_sendHttpRequest("/ranking/fire", "post", nil, {
		userToRank = {
			userId = tostring(userId),
			userName = userName,
		},
		userWhoRanked = whoCalled,
		userId = tostring(userId),
	})

	return response.Body
end

--[=[
	Gets a player's or everyone's current activity
	@param User Player | string | number
	@return activityResponse

	@within VibezLightweight
	@since 0.3.0
]=]
---
function Class.getActivity(
	self: VibezLightweightKind,
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
	Negates the player's activity seconds & message counts. (Does not clear detail logs array.)
	@param User Player | string | number
	@return boolean

	@yields
	@within VibezLightweight
	@since 0.11.0
]=]
---
function Class.removeActivity(self: VibezLightweightKind, User: Player | string | number): Definitions.InfoResponse
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
	Saves the player's current activity
	@param User Player | string | number
	@param userRank number
	@param secondsSpent number
	@param messagesSent (number | { string })?
	@param shouldFetchGroupRank boolean?
	@return httpResponse

	@yields
	@within VibezLightweight
	@since 0.3.0
]=]
---
function Class.saveActivity(
	self: VibezLightweightKind,
	User: Player | string | number,
	userRank: number,
	secondsSpent: number?,
	messagesSent: (number | { string })?,
	shouldFetchGroupRank: boolean?
): Definitions.SaveUserActivityResponse
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

	local _, response: any = self:_sendHttpRequest("/activity/save2", "post", nil, {
		userId = userId,
		userRank = userRank,
		secondsUserHasSpent = secondsSpent,
		messagesUserHasSent = messagesSent,
	})

	return response.Body
end

--[=[
	Adds a blacklist to your api key.
	@param userToBlacklist (Player string | number)
	@param Reason string?
	@param blacklistExecutedBy (Player string | number)?
	@return blacklistResponse

	@within VibezLightweight
	@since 0.6.0
]=]
---
function Class.addBlacklist(
	self: VibezLightweightKind,
	userToBlacklist: Player | string | number,
	Reason: string?,
	blacklistExecutedBy: Player | string | number
): Definitions.BlacklistResponse
	local userId, reason, blacklistedBy =
		nil, (typeof(Reason) ~= "string" or Reason == "") and "Unknown." or Reason, nil

	if not userToBlacklist then
		return {
			success = false,
			message = "An invalid user was supplied.",
		} :: any
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
		return {
			success = false,
			message = response:unwrapErr(),
		} :: any
	end

	return response:unwrap().Body
end

--[=[
	Deletes a blacklist from your api key.
	@param userToDelete (Player string | number)
	@return blacklistResponse

	@within VibezLightweight
	@since 0.6.0
]=]
---
function Class.deleteBlacklist(
	self: VibezLightweightKind,
	userToDelete: Player | string | number
): Definitions.BooleanResponse
	if not userToDelete then
		-- An invalid user was supplied.
		return false
	end

	local userId = self:_verifyUser(userToDelete, "UserId")
	local response = self:_sendHttpRequest(`/blacklists/{userId}`, "delete")

	if response:isErr() then
		return false
	end

	return true
end

--[=[
	Gets either a full list of blacklists or checks if a player is currently blacklisted.
	@param userId (string | number | Player)?
	@return blacklistResponse

	@within VibezLightweight
	@since 0.6.0
]=]
---
function Class.getBlacklists(
	self: VibezLightweightKind,
	userId: (string | number | Player)?
): Definitions.BlacklistResponse
	userId = (userId ~= nil) and self:_verifyUser(userId, "UserId") or ""
	local response = self:_sendHttpRequest(`/blacklists/{userId}`)

	if response:isErr() then
		return {
			success = false,
			message = response:unwrapErr(),
		} :: any
	end

	warn(response)
	local unwrapped = response:unwrap()
	return unwrapped.Body
end

--[=[
	Gets either a full list of blacklists or checks if a player is currently blacklisted.
	@param User Player | string | number
	@return (boolean, string?, string?)

	@within VibezLightweight
	@since 0.6.0
]=]
---
function Class.isUserBlacklisted(self: VibezLightweightKind, User: Player | string | number): ...any
	local userId = self:_verifyUser(User, "Id")
	local blacklistData = self:getBlacklists(userId)

	if not blacklistData.success then
		return blacklistData
	end

	if blacklistData.success then
		local data = {
			blacklistData.data.blacklisted,
			blacklistData.data.reason,
			blacklistData.data.blacklistedBy,
		}

		return table.unpack(data)
	end

	return false, nil, nil
end

--[=[
	Uses roblox's group service to get a player's rank.
	@param groupId number
	@param userId number
	@return { Rank: number?, Role: string?, Id: number?, errMessage: string? }

	@yields
	@private
	@within VibezLightweight
	@since 0.1.0
]=]
---
--stylua: ignore
function Class._getGroupFromUser(
	self: VibezLightweightKind,
	groupId: number,
	userId: number,
	force: boolean?,
	useOverride: boolean?
): Result.Result<{ Rank: number, Role: string, Id: number }, string>
	if self.requestCaches.groupInfo[userId] ~= nil and not force then
		return self.requestCaches.groupInfo[userId]
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
		self.requestCaches.groupInfo[userId] = found
		return found
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
	Ensures that the parameter returns the proper type associated to the `typeToReturn`
	@param self VibezLightweight
	@param User Player | number | string
	@param typeToReturn "UserId" | "Player" | "Name"
	@return number | string | Player

	@private
	@within VibezLightweight
]=]
function Class._verifyUser(
	self: VibezLightweightKind,
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
	Gets a player's user identifier via their username.
	@param username string
	@return number?

	@yields
	@private
	@within VibezLightweight
]=]
---
function Class._getUserIdByName(self: VibezLightweightKind, username: string): number
	local isOk, userId = pcall(Players.GetUserIdFromNameAsync, Players, username)
	return isOk and userId or -1
end

--[=[
	Gets a player's username by their userId
	@param userId number
	@return string?

	@yields
	@private
	@within VibezLightweight
]=]
---
function Class._getNameById(self: VibezLightweightKind, userId: number): string
	local fixedUserId = tonumber(userId)
	if not fixedUserId then
		return tostring(userId)
	end

	local isOk, userName = pcall(Players.GetNameFromUserIdAsync, Players, fixedUserId)
	return isOk and userName or "Unknown"
end

--[=[
	Gets the role id of a rank.
	@param rank number | string
	@return number?

	@yields
	@private
	@within VibezLightweight
]=]
---
function Class._getRoleIdFromRank(self: VibezLightweightKind, rank: number | string): number?
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

return Vibez
