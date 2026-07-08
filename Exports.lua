export type PromiseStatus = "Pending" | "Fulfilled" | "Rejected"

export type PromiseOptions = {
	cancellable: boolean?,
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
	catch: <U>(self: Promise<T>, callback: (any) -> U) -> Promise<T | U>,
}

return {}
