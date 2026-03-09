--!strict
local RunService = game:GetService("RunService")

export type ScopedLogger = {
	__isLoggerScope: boolean,
	trace: (selfOrMessage: any, messageOrExtra: any?, ...any) -> (),
	info: (selfOrMessage: any, messageOrExtra: any?, ...any) -> (),
	warn: (selfOrMessage: any, messageOrExtra: any?, ...any) -> (),
	error: (selfOrMessage: any, messageOrExtra: any?, ...any) -> (),
}

local LEVEL_RANK: {[string]: number} = {
	TRACE = 1,
	INFO = 2,
	WARN = 3,
	ERROR = 4,
}

local Logger = {
	Enabled = true,
	MinLevel = "TRACE",
}

local function safeToString(value: any): string
	if value == nil then
		return "nil"
	end
	local ok, str = pcall(tostring, value)
	if not ok then
		return "<unstringable>"
	end
	if str == nil then
		return "nil"
	end
	return str
end

local function normalizeScope(scope: any): string
	if type(scope) ~= "string" or scope == "" then
		return "General"
	end
	return scope
end

local function normalizeLevel(level: any): string
	if type(level) ~= "string" or level == "" then
		return "INFO"
	end
	local upper = string.upper(level)
	if LEVEL_RANK[upper] == nil then
		return "INFO"
	end
	return upper
end

local function runtimeSide(): string
	local ok, isServer = pcall(function()
		return RunService:IsServer()
	end)
	if ok and isServer then
		return "Server"
	end
	return "Client"
end

local function canLog(levelName: string): boolean
	if Logger.Enabled ~= true then
		return false
	end
	local minLevelName = normalizeLevel(Logger.MinLevel)
	local minRank = LEVEL_RANK[minLevelName] or LEVEL_RANK.INFO
	local currentRank = LEVEL_RANK[levelName] or LEVEL_RANK.INFO
	return currentRank >= minRank
end

local function buildMessage(message: any, ...: any): string
	local text = if message == nil then "(no message)" else safeToString(message)

	local extraCount = select("#", ...)
	if extraCount <= 0 then
		return text
	end

	local extraParts = table.create(extraCount)
	for index = 1, extraCount do
		extraParts[index] = safeToString(select(index, ...))
	end
	return text .. " | " .. table.concat(extraParts, " ")
end

local function output(levelName: string, line: string)
	if levelName == "WARN" or levelName == "ERROR" then
		pcall(warn, line)
		return
	end
	pcall(print, line)
end

local function emit(scope: any, level: any, message: any, ...: any)
	local ok, err = pcall(function()
		local scopeName = normalizeScope(scope)
		local levelName = normalizeLevel(level)
		if not canLog(levelName) then
			return
		end

		local basePrefix = string.format("[GW][%s][%s]", scopeName, runtimeSide())
		local msg = buildMessage(message, ...)
		local line = basePrefix .. " " .. msg
		if levelName == "WARN" or levelName == "ERROR" then
			line = string.format("%s[%s] %s", basePrefix, levelName, msg)
		end
		output(levelName, line)
	end)

	if not ok then
		pcall(warn, "[GW][Logger][ERROR] logging failure: " .. safeToString(err))
	end
end

local function forward(scope: any, level: any, selfOrMessage: any, messageOrExtra: any?, ...: any)
	if type(selfOrMessage) == "table" and selfOrMessage.__isLoggerScope == true then
		emit(scope, level, messageOrExtra, ...)
		return
	end
	emit(scope, level, selfOrMessage, messageOrExtra, ...)
end

local function scoped(scope: any): ScopedLogger
	local safeScope = normalizeScope(scope)
	local s = {
		__isLoggerScope = true,
	} :: any

	function s.trace(selfOrMessage: any, messageOrExtra: any?, ...: any)
		forward(safeScope, "TRACE", selfOrMessage, messageOrExtra, ...)
	end

	function s.info(selfOrMessage: any, messageOrExtra: any?, ...: any)
		forward(safeScope, "INFO", selfOrMessage, messageOrExtra, ...)
	end

	function s.warn(selfOrMessage: any, messageOrExtra: any?, ...: any)
		forward(safeScope, "WARN", selfOrMessage, messageOrExtra, ...)
	end

	function s.error(selfOrMessage: any, messageOrExtra: any?, ...: any)
		forward(safeScope, "ERROR", selfOrMessage, messageOrExtra, ...)
	end

	return s :: ScopedLogger
end

function Logger.setEnabled(enabled: any)
	Logger.Enabled = enabled == true
end

function Logger.setMinLevel(level: any)
	Logger.MinLevel = normalizeLevel(level)
end

function Logger.scoped(scope: any): ScopedLogger
	return scoped(scope)
end

return Logger
