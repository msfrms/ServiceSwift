//
// Created by Radaev Mikhail on 25.03.2018.
// Copyright (c) 2018 msfrms. All rights reserved.
//

import Foundation
import ConcurrentSwift

public class TransformJsonTo<Model: Decodable>: Filter<URLRequest, Model, URLRequest, (Data, HTTPURLResponse)> {
    public override func apply(request: URLRequest, service: Service<URLRequest, (Data, HTTPURLResponse)>) -> Future<Model> {
        return service.apply(request: request).flatMap { data, _ -> Future<Model> in
            return TransformDataTo<Model>().apply(request: data)
        }
    }
}

public class TransformFailureIfNeededTo<Error: Decodable & Swift.Error, Model: Decodable>: SimpleFilter<URLRequest, Model> {
    public override func apply(request: URLRequest, service: Service<URLRequest, Model>) -> Future<Model> {
        return service.apply(request: request).rescue { (error: Swift.Error) -> Future<Model> in
            switch error {
            case ResponseError.decoding(_, let data):
                return TransformDataTo<Error>()
                        .apply(request: data)
                        .flatMap { model -> Future<Model> in
                            return Future.failed(ResponseError.other(model))
                        }
            default: return Future.failed(error)
            }
        }
    }
}