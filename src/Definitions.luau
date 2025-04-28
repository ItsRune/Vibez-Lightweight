local Result = require(script.Parent.Packages.Result)

export type Error = string | Result.Result<any, string>
export type BaseHttpResponse = Result.Result<any, any>
export type InfoResponse = { success: boolean, message: string }
export type GroupIdResponse = number
export type BlacklistResponse = {
	isBlacklisted: boolean,
	details: { reason: string?, blacklisted: boolean?, blacklistedBy: string? },
}
export type UserBlacklistResponse = InfoResponse
export type SaveUserActivityResponse = {
	detailedLogs: { { timestampLeftAt: number, secondsUserHasSpent: number, messagesUserHasSent: number }? },
	messagesUserHasSent: number,
	secondsUserHasSpent: number,
}

export type FetchUserActivityResponse = {
	success: boolean,
	userId: number?,
	secondsUserHasSpent: number,
	messagesUserHasSent: number,
	detailedLogs: {
		{
			timestampLeftAt: number,
			secondsUserHasSpent: number,
			messagesUserHasSent: number,
		}
	},
}

export type SetRankResponse = {
	success: boolean,
	message: string?,
	data: {
		newRank: {
			id: number,
			name: string,
			rank: number,
			memberCount: number,
		},
		oldRank: {
			id: number,
			name: string,
			rank: number,
			groupInformation: {
				id: number,
				name: string,
				memberCount: number,
				hasVerifiedBadge: boolean,
			},
		},
	},
}

return nil

--[=[
	@type errorKind string | Result<any, string>
	@within Ranking
]=]
--[=[
	@type BaseHttpResponse Result<any,any>
	@within Ranking
]=]
--[=[
	@type InfoResponse { success: boolean, message: string }
	@within Ranking
]=]
--[=[
	@type GroupIdResponse number
	@within Ranking
]=]
--[=[
	@type BlacklistResponse { success: boolean, data: { [string]: any } }
	@within Ranking
]=]
--[=[
	@type UserBlacklistResponse { isUserBlacklisted: boolean, success: boolean, [any]: any }
	@within Ranking
]=]
--[=[
	@type SaveUserActivityResponse {detailedLogs: { { timestampLeftAt: number, secondsUserHasSpent: number, messagesUserHasSent: number }? },messagesUserHasSent: number,secondsUserHasSpent: number}
	@within Ranking
]=]
--[=[
	@type FetchUserActivityResponse {success: boolean,userId: number?,secondsUserHasSpent: number,messagesUserHasSent: number,detailedLogs: {{timestampLeftAt: number,secondsUserHasSpent: number,messagesUserHasSent: number}}}
	@within Ranking
]=]
--[=[
	@type SetRankResponse {success: boolean,message: string?,data:{newRank: {id: number,name: string,rank: number,memberCount: number,},oldRank: {id: number,name: string,rank: number,groupInformation: {id: number,name: string,memberCount: number,hasVerifiedBadge: boolean}}}}
	@within Ranking
]=]

-- Result Implementation
--[=[
    @class Result
    A basic port of the rust Result class
]=]

--[=[
    @method ok
    @param item T
    @return Result<T, E>
    @within Result
]=]

--[=[
    @method err
    @param err E
    @return Result<T, E>
    @within Result
]=]

--[=[
    @method try
    @param fn () -> T
    @return Result<T, E>
    @within Result
]=]

--[=[
    @method isOk
    @return boolean
    @within Result
]=]

--[=[
    @method isErr
    @return boolean
    @within Result
]=]

--[=[
    @method inspect
    @param fn (ok: T) -> ()
    @return Result<T,E>
    @within Result
]=]

--[=[
    @method inspectErr
    @param fn (err: E) -> ()
    @return Result<T,E>
    @within Result
]=]

--[=[
    @method match<O>
    @param ok (ok: T) -> O
    @param err (err: E) -> O
    @return O
    @within Result
]=]

--[=[
    @method map
    @param fn (ok: T) -> T
    @return Result<T,E>
    @within Result
]=]

--[=[
    @method mapErr
    @param fn (err: E) -> E
    @return Result<T,E>
    @within Result
]=]

--[=[
    @method mapOr
    @param fn (ok: T) -> T
    @param alt T
    @return Result<T,E>
    @within Result
]=]

--[=[
    @method mapOrElse
    @param mapFn (ok: T) -> T
    @param elseFn () -> T
    @return Result<T,E>
    @within Result
]=]

--[=[
    @method unwrap
    @return T
    @within Result
]=]

--[=[
    @method unwrapErr
    @return E
    @within Result
]=]

--[=[
    @method unwrapOr
    @param alt T
    @return T
    @within Result
]=]

--[=[
    @method unwrapOrElse
    @param fn () -> T
    @return T
    @within Result
]=]

--[=[
    @method expect
    @param fn () -> T
    @return T
    @within Result
]=]

--[=[
    @prop _ok T
    @private
    @within Result
]=]

--[=[
    @prop _err E
    @private
    @within Result
]=]

--[=[
    @prop _state string
    @private
    @within Result
]=]
