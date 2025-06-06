--!strict
--#selene: allow(unused_variable)
-- https://doc.rust-lang.org/std/result/enum.Result.html
-- Services
-- Packages
local Option = require(script.Parent:WaitForChild("Option")) -- Modules
-- Types

type Option<V> = Option.Option<V>
type State = "E" | "O"
type ResultImpl<V, E> = {
	__index: ResultImpl<V, E>,
	__tostring: (self: Result<V, E>) -> string,
	isOk: (self: Result<V, E>) -> boolean,
	isErr: (self: Result<V, E>) -> boolean,
	inspect: (self: Result<V, E>, fn: (ok: V) -> ()) -> Result<V, E>,
	inspectErr: (self: Result<V, E>, fn: (err: E) -> ()) -> Result<V, E>,
	match: <O>(self: Result<V, E>, ok: (ok: V) -> O, err: (err: E) -> O) -> O,
	--type swapping with map stuff is technically okay, but I can't get the type engine to recognize that
	map: (self: Result<V, E>, fn: (ok: V) -> V) -> Result<V, E>,
	mapErr: (self: Result<V, E>, fn: (err: E) -> E) -> Result<V, E>,
	mapOr: (self: Result<V, E>, mapFn: (ok: V) -> V, alt: V) -> Result<V, E>,
	mapOrElse: (self: Result<V, E>, mapFn: (ok: V) -> V, elseFn: () -> V) -> Result<V, E>,
	unwrap: (self: Result<V, E>) -> V,
	unwrapErr: (self: Result<V, E>) -> E,
	unwrapOr: (self: Result<V, E>, alt: V) -> V,
	unwrapOrElse: (self: Result<V, E>, fn: () -> V) -> V,
	expect: (self: Result<V, E>, msg: string) -> V,
}
export type Result<V, E> = typeof(setmetatable(
	{} :: {
		_state: string, --State, --replaced for performance reasons
		_ok: V?,
		_err: E?,
	},
	{} :: ResultImpl<V, E>
))

-- Constants
local STATE_OK: State = "O"
local STATE_ERR: State = "E"
-- Variables
-- References
-- Private Functions

-- Class
local Result = {} :: ResultImpl<unknown, unknown>
Result.__index = Result

-- non-construct interface methods
local isResult = function<V, E>(value: unknown?): boolean
	if typeof(value) == "table" then
		local tabl = value :: { [unknown]: unknown? }
		return getmetatable(tabl :: any) == Result and tabl._state == STATE_OK or tabl._state == STATE_ERR
	end
	return false
end

-- Constructors
local fromOk = function<V, E>(ok: V): Result<V, E>
	local self: Result<V, E> = setmetatable({
		_state = STATE_OK :: string,
		_ok = ok,
		_err = nil,
	}, Result :: ResultImpl<any, any>)
	table.freeze(self)
	return self
end
local fromErr = function<V, E>(err: E): Result<V, E>
	local self: Result<V, E> = setmetatable({
		_state = STATE_ERR :: string,
		_ok = nil,
		_err = err,
	}, Result :: ResultImpl<any, any>)
	table.freeze(self)
	return self
end
local try = function<V, string>(fn: () -> V): Result<V, string>
	local out: V
	local success, msg = pcall(function()
		out = fn()
	end)
	if success then
		return fromOk(out)
	else
		return fromErr(msg)
	end
end

-- methods
function Result:__tostring(): string
	if Result.isOk(self) then
		return `Ok<{self._ok}>`
	end
	return `Err<{self._err}>`
end

function Result:isOk(): boolean
	return self._state == STATE_OK
end

-- Returns true if the result is Err.
function Result:isErr(): boolean
	return self._state == STATE_ERR
end

function Result:inspect(fn: (ok: unknown) -> ())
	if Result.isOk(self) then
		fn(self._ok)
	end
	return self
end

function Result:inspectErr(fn: (err: unknown) -> ())
	if Result.isErr(self) then
		fn(self._err)
	end
	return self
end

function Result:match<O>(ok: (ok: unknown) -> O, err: (err: unknown) -> O): O
	if Result.isOk(self) then
		return ok(self._ok)
	else
		return err(self._err)
	end
end

function Result:map(fn: (ok: unknown) -> unknown): Result<unknown, unknown>
	return Result.match(self, function(ok)
		return fromOk(fn(self._ok))
	end, function(err)
		return fromErr(self._err)
	end)
end

function Result:mapOr(mapFn: (ok: unknown) -> unknown, alt: unknown): Result<unknown, unknown>
	if Result.isOk(self) then
		return fromOk(mapFn(self._ok))
	end
	return fromOk(alt)
end

function Result:mapOrElse(mapFn: (ok: unknown) -> unknown, elseFn: () -> unknown): Result<unknown, unknown>
	if Result.isOk(self) then
		return fromOk(mapFn(self._ok))
	end
	return fromOk(elseFn())
end

function Result:unwrap()
	if Result.isOk(self) then
		return self._ok
	end
	error(`{self._err}`)
end

function Result:unwrapErr()
	if Result.isErr(self) then
		return self._err
	end
	error(`result is not error`)
end

function Result:unwrapOr(alt: unknown)
	return Result.match(self, function(ok)
		return ok
	end, function(err)
		return alt
	end)
end

function Result:unwrapOrElse(fn: () -> unknown)
	return Result.match(self, function(ok)
		return ok
	end, function(err)
		return fn()
	end)
end

function Result:expect(msg: string)
	if Result.isOk(self) then
		return self._ok
	end
	error(msg)
end

return {
	ok = fromOk,
	err = fromErr,
	try = try,
	isResult = isResult,
}
