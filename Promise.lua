local Exports = require(script.Exports)

local Promise = {}
Promise.__index = Promise

local Private = setmetatable({}, { __mode = "k" })

function Promise.new<T>(exec: Exports.Executor<T>, opt: Exports.PromiseOptions?): Exports.Promise<T>

	local internal: Exports.PromiseInternal<T> = {
		Status = "Pending",
		Value = nil,
		Error = nil,
		Cancelled = false,
		SuccessCallbacks = {},
		ErrorCallbacks = {},
	}

	local self = setmetatable({}, Promise)
	Private[self] = internal

	local function resolve(newValue: T)
		local d = Private[self]
		if d.Status ~= "Pending" then return end
		d.Status = "Fulfilled"
		d.Value = newValue
		for _, c in d.SuccessCallbacks do
			c(newValue)
		end
	end

	local function reject(errValue: any)
		local d = Private[self]
		if d.Status ~= "Pending" then return end
		d.Status = "Rejected"
		d.Error = errValue
		for _, c in d.ErrorCallbacks do
			c(errValue)
		end
	end

	task.spawn(function()
		local success, result = pcall(function()
			exec(resolve, reject)
		end)
		if not success then
			reject(result)
		end
	end)

	return self :: Exports.Promise<T>
end

function Promise.andThen<T, U>(self: Exports.Promise<T>, callback: (T) -> U): Exports.Promise<U>
	local d = Private[self]

	return Promise.new(function(resolve: (U) -> (), reject: (any) -> ())
		table.insert(d.SuccessCallbacks, function(value: T)
			local success, result = pcall(callback, value)
			if success then resolve(result) else reject(result) end
		end)
		table.insert(d.ErrorCallbacks, reject)
	end)
end

function Promise.catch<T, U>(self: Exports.Promise<T>, callback: (any) -> U): Exports.Promise<T | U>
	local d = Private[self]

	return Promise.new(function(resolve: (T | U) -> (), reject: (any) -> ())
		table.insert(d.ErrorCallbacks, function(err: any)
			local success, result = pcall(callback, err)
			if success then resolve(result) else reject(result) end
		end)
		table.insert(d.SuccessCallbacks, resolve)
	end)
end

return Promise
