export type PromiseOptions = {
	
	cancellable: boolean?,
	
}

export type PromiseStatus = "Pending" | "Fulfilled" | "Rejected"

export type ErrorTypes = "ValidationError" | "RuntimeError" | "CancelledError" | "TimeoutError" | "UnknownError"

export type Error = {
	
	type: ErrorTypes,
	message: string?,
	trace: string?,
	context: string?,
	
}

export type Executor<T> = (
	
	resolve: (T) -> (),
	reject: (any) -> ()
	
) -> ()

export type PromiseInternal<T> = {
	
	Status: PromiseStatus,
	Value: T?,
	Error: any,
	Cancelled: boolean,
	SuccessCallbacks: { (T) -> () },
	ErrorCallbacks: { (any) -> () },
	
}

export type Promise<T> = {
	
	andThen: <U>(self: Promise<T>, callback: (T) -> U) -> Promise<U>,
	catch: (self: Promise<T>, callback: (Error) -> ()) -> Promise<T>,
	
}

return {}
