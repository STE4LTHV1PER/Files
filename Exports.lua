export type PromiseOptions = {
	
	timeout: boolean?,
	delay: number?,
	retries: number?,
	errorMessage: string?,
	
}

export type PromiseStatus = "Pending" | "Fulfilled" | "Rejected"

export type ErrorTypes = "ValidationError" | "RuntimeError" | "CancelledError" | "TimeoutError" | "UnknownError"

export type Error = {
	
	errType: ErrorTypes,
	status: PromiseStatus,
	message: string?,
	trace: string?,
	
}

export type Executor<T> = (
	
	resolve: (T) -> (),
	reject: (any) -> ()
	
) -> ()

export type PromiseInternal<T> = {
	
	Status: PromiseStatus,
	StartTime: number,
	Value: T?,
	Error: any,
	Cancelled: boolean,
	TimedOut: boolean,
	SuccessCallbacks: { (T) -> () },
	ErrorCallbacks: { (any) -> () },
	FinallyCallbacks: { (T) -> () },
	
}

export type Promise<T> = {
	
	andThen: <U>(self: Promise<T>, callback: (T) -> U) -> Promise<U>,
	catch: (self: Promise<T>, callback: (Error) -> ()) -> Promise<T>,
	finally: (self: Promise<T>, callback: (T) -> ()) -> Promise<T>,
	cancel: (self: Promise<T>, callback: () -> ()) -> (),
	
}

return {}
