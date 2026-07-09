local Exports = require(script.Exports)

local Promise = {}
Promise.__index = Promise

local Private: { [Exports.Promise<any>]: Exports.PromiseInternal<any> } = setmetatable({}, { __mode = "k" }) :: any
local PrivateOptions: { [Exports.Promise<any>]: Exports.PromiseOptions } = setmetatable({}, { __mode = "k" }) :: any

local function generateErrorData<T>(promise: Exports.Promise<T>, eType: string?, warnTrace: boolean?): Exports.Error
	
	local d: Exports.PromiseOptions = PrivateOptions[promise]
	
	local errData: Exports.Error = {
		errType = eType or "UnknownError",
		status = "Rejected",
		message = d and d.errorMessage or "",
		trace = debug.traceback("A promise error has occured. See error trace for more information.", 2),
	}
	
	if warnTrace ~= false then
		warn(("%s\n(%s)"):format(errData.trace, errData.message))
	end
	
	return errData
end

local function isTimedOut<T>(promise: Exports.Promise<T>): boolean?
	
	local d: Exports.PromiseInternal<T> = Private[promise]
	if not d then return nil end
	
	local o: Exports.PromiseOptions = PrivateOptions[promise]
	if not o then return false end
	
	if not o.timeout then return false end
	
	if os.clock() - d.StartTime >= o.timeout then
		return true
	end
	
	return false
end

function Promise.new<T>(exec: Exports.Executor<T>, opt: Exports.PromiseOptions?): Exports.Promise<T>

	local internal: Exports.PromiseInternal<T> = {
		Status = "Pending",
		Value = nil,
		Error = nil,
		Cancelled = false,
		TimedOut = false,
		StartTime = os.clock(),
		SuccessCallbacks = {},
		ErrorCallbacks = {},
		FinallyCallbacks = {},
	}

	local self = setmetatable({}, Promise)
	Private[self] = internal
	PrivateOptions[self] = opt or {}
	
	local function callFinally(promiseInternal: Exports.PromiseInternal<T>)
		
		if not promiseInternal or not promiseInternal.FinallyCallbacks then return end
		
		for _, callback in promiseInternal.FinallyCallbacks do
			local success, err = pcall(callback)
			if not success then
				warn(err)
			end
		end
	end
	
	local function callSuccesses<N>(promiseInternal: Exports.PromiseInternal<T>)
		
		if not promiseInternal then return end
		
		for _, callback in internal.SuccessCallbacks do
			callback(promiseInternal.Value)
		end
		
		callFinally(promiseInternal)
	end
	
	local function callErrors<E>(promiseInternal: Exports.PromiseInternal<E>)
		
		for _, callback in internal.ErrorCallbacks do
			callback(promiseInternal.Error)
		end
		
		callFinally(promiseInternal)
	end

	local function resolve(newValue: T)
		local d: Exports.PromiseInternal<T> = Private[self]
		if not d or d.Status ~= "Pending" then return end
		d.Status = "Fulfilled"
		d.Value = newValue
		callSuccesses(d)
	end

	local function reject(errValue: Exports.Error)
		local d: Exports.PromiseInternal<any> = Private[self]
		if not d or d.Status ~= "Pending" then return end
		d.Status = "Rejected"
		d.Error = errValue
		callErrors(d)
	end

	task.spawn(function()
		local success, result = pcall(function()
			exec(resolve, reject)
		end)
		if not success then
			reject(result)
		end
	end)
	
	task.spawn(function()
		while true do
			local d: Exports.PromiseInternal<T> = Private[self]
			if not d or d.Status ~= "Pending" then
				break
			end

			if isTimedOut(self) then
				reject(generateErrorData(self, "TimeoutError", false))
				break
			end

			task.wait()
		end
	end)

	return self :: Exports.Promise<T>
end

function Promise.andThen<T, U>(self: Exports.Promise<T>, callback: (T) -> U): Exports.Promise<U>
	
	local d: Exports.PromiseInternal<T> = Private[self]
	if not d then return self end
	
	local newPromise: Exports.Promise<U> = Promise.new(function(resolve: (U) -> (), reject: (any) -> ())
		
		if d.Status == "Fulfilled" then
			local success, result = pcall(callback, d.Value)
			if success then resolve(result) else reject(generateErrorData(self, "RuntimeError", false)) end
		elseif d.Status == "Rejected" then
			reject(generateErrorData(self, "RuntimeError", false))
		elseif d.Status == "Pending" then
			table.insert(d.SuccessCallbacks, function(value: T)
				local success, result = pcall(callback, value)
				if success then resolve(result) else reject(generateErrorData(self, "RuntimeError", false)) end
			end)
			table.insert(d.ErrorCallbacks, reject)
		end
	end)

	return newPromise
end

function Promise.catch<T>(self: Exports.Promise<T>, callback: (Exports.Error) -> ()): Exports.Promise<T>
	
	local d: Exports.PromiseInternal<T> = Private[self]
	if not d then return self end

	local newPromise: Exports.Promise<T> = Promise.new(function(resolve: (T) -> (), reject: (any) -> ())
		if d.Status == "Rejected" then
			local success, result = pcall(callback, d.Error)
			if success then
				resolve(result)
			else
				reject(generateErrorData(self, "RuntimeError", false))
			end
		elseif d.Status == "Fulfilled" then
			resolve(d.Value)
		else
			table.insert(d.ErrorCallbacks, function(err: Exports.Error)
				local success, result = pcall(callback, err)
				if success then resolve(result) else reject(generateErrorData(self, "RuntimeError", false)) end
			end)
			table.insert(d.SuccessCallbacks, resolve)
		end
	end)

	return newPromise
end

function Promise.finally<T>(self: Exports.Promise<T>, callback: () -> ()): Exports.Promise<T>

	local d: Exports.PromiseInternal<T> = Private[self]
	if not d then
		return self
	end

	local newPromise: Exports.Promise<T> = Promise.new(function(resolve: (T) -> (), reject: (Exports.Error) -> ())
		
		if d.Status == "Fulfilled" then
			pcall(callback)
			resolve(d.Value)
		elseif d.Status == "Rejected" then
			local success, result = pcall(callback)
			if success then
				reject(generateErrorData(self, "RuntimeError", false))
			else
				reject(generateErrorData(self, "RuntimeError", false))
			end
		else
			table.insert(d.FinallyCallbacks, function()

				local success, result = pcall(callback)

				if success then
					if d.Status == "Fulfilled" then
						resolve(d.Value)
					else
						reject(generateErrorData(self, "RuntimeError", false))
					end
				else
					reject(generateErrorData(self, "RuntimeError", false))
				end
			end)
		end
	end)

	return newPromise
end

function Promise.error<T>(self: Exports.Promise<T>, eType: string?, warnTrace: boolean?): Exports.Error | nil
	
	local d: Exports.PromiseInternal<T> = Private[self]
	if not d then
		warn("Attempted to call Promise:error() on a cancelled/dropped promise")
		return nil
	end
	
	local generated = generateErrorData(self, eType, warnTrace)
	if not generated then return nil end
	
	return generated
end

function Promise.forceDestroy<T>(self: Exports.Promise<T>): nil
	
	local d: Exports.PromiseInternal<T> = Private[self]
	
	d.SuccessCallbacks = {}
	d.ErrorCallbacks = {}
	
	Private[self] = nil
	
	return nil
end

return Promise
