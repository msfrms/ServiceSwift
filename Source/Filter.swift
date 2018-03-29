//
// Created by Radaev Mikhail on 29.01.2018.
// Copyright (c) 2018 ListOK. All rights reserved.
//

import Foundation
import ConcurrentSwift

public class Filter<ReqIn, RepOut, ReqOut, RepIn> {

    public init() {}

    public func apply(request: ReqIn, service: Service<ReqOut, RepIn>) -> Future<RepOut> {
        return Future.never
    }

    public func andThen<Req2, Rep2>(_ next: Filter<ReqOut, RepIn, Req2, Rep2>) -> Filter<ReqIn, RepOut, Req2, Rep2> {
        return AndThenFilter { service -> Service<ReqIn, RepOut> in self.andThen(next.andThen(service)) }
    }

    public func andThen(_ service: Service<ReqOut, RepIn>) -> Service<ReqIn, RepOut> {
        return  AndThenService { request -> Future<RepOut> in self.apply(request: request, service: service) }
    }

    private class AndThenFilter<ReqIn, RepOut, ReqOut, RepIn>: Filter<ReqIn, RepOut, ReqOut, RepIn> {

        private let build: (Service<ReqOut, RepIn>) -> Service<ReqIn, RepOut>

        init(build: @escaping (Service<ReqOut, RepIn>) -> Service<ReqIn, RepOut>) {
            self.build = build
        }

        override func apply(request: ReqIn, service: Service<ReqOut, RepIn>) -> Future<RepOut> {
            return self.build(service).apply(request: request)
        }

        override func andThen<Req2, Rep2>(_ next: Filter<ReqOut, RepIn, Req2, Rep2>) -> Filter<ReqIn, RepOut, Req2, Rep2> {
            return AndThenFilter<ReqIn, RepOut, Req2, Rep2> { service -> Service<ReqIn, RepOut> in
                return self.build(next.andThen(service))
            }
        }

        override func andThen(_ service: Service<ReqOut, RepIn>) -> Service<ReqIn, RepOut> {
            return self.build(service)
        }
    }

    private class AndThenService: Service<ReqIn, RepOut> {

        let build: (ReqIn) -> Future<RepOut>

        init(build: @escaping (ReqIn) -> Future<RepOut>) {
            self.build = build
        }

        override func apply(request: ReqIn) -> Future<RepOut> {
            return self.build(request)
        }
    }
}

public class SimpleFilter<Req, Rep>: Filter<Req, Rep, Req, Rep> {
    public override func apply(request: Req, service: Service<Req, Rep>) -> Future<Rep> {
        return Future.never
    }
}

public class RetryFilter<Req, Rep>: SimpleFilter<Req, Rep> {

    private let attempt: Int

    public init(attempt: Int) {
        self.attempt = attempt
    }

    private func retry(request: Req, attempt: Int, service: Service<Req, Rep>) -> Future<Rep> {
        return service.apply(request: request).rescue { (error: Error) -> Future<Rep> in
            guard attempt > 1 else { return Future.failed(error) }
            return self.retry(request: request, attempt: attempt - 1, service: service)
        }
    }

    public override func apply(request: Req, service: Service<Req, Rep>) -> Future<Rep> {
        return self.retry(request: request, attempt: self.attempt, service: service)
    }
}

public class TimeoutFilter<Req, Rep>: SimpleFilter<Req, Rep> {

    private let timeout: DispatchTimeInterval
    private let queue: DispatchQueue

    public init(_ timeout: DispatchTimeInterval, byQueue: DispatchQueue) {
        self.timeout = timeout
        self.queue = byQueue
    }

    public override func apply(request: Req, service: Service<Req, Rep>) -> Future<Rep> {
        return service.apply(request: request)
                .timeout(self.timeout, forQueue: self.queue)
                .rescue { (error: Error) -> Future<Rep> in
                    switch error {
                    case is Future<Rep>.TimeoutError: service.cancel()
                    default: ()
                    }
                    return Future.failed(error)
                }
    }
}
