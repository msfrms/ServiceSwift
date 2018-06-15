//
// Created by Radaev Mikhail on 26.01.2018.
// Copyright (c) 2018 ListOK. All rights reserved.
//

import Foundation
import ConcurrentSwift

public extension Future {
    static var never: Future { return Future<R> { _ in } }
}

public class Service<Req, Rep> {

    public init() {}

    public func apply(request: Req) -> Future<Rep> { return .never }

    @discardableResult
    public func cancel() -> Future<Void> { return .never }
}

public extension Service where Req == Void {
    public func apply() -> Future<Rep> { return self.apply(request: ()) }
}

