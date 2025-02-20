local Result = require(script.Parent.Packages.Result)

export type BaseHttpResponse = Result.Result<any, any>
export type InfoResponse = { success: boolean, message: string }
export type GroupIdResponse = { success: boolean, GroupId: number }
export type NitroBoosterResponse = { success: boolean, isBooster: boolean, message: string? }

export type BlacklistResponse = { success: boolean, data: { [string]: any } }
export type UserBlacklistResponse = InfoResponse

export type BooleanResponse = boolean
export type SaveUserActivityResponse = InfoResponse
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
}

return nil
