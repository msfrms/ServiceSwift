//
// Created by Radaev Mikhail on 26.01.2018.
// Copyright (c) 2018 ListOK. All rights reserved.
//

import Foundation
import ConcurrentSwift

public class NetworkDataService: Service<URLRequest, (Data, HTTPURLResponse)> {

    public enum Error: Swift.Error {
        case unknown
        case stopped
    }

    private var task: URLSessionDataTask?

    public override func apply(request: URLRequest) -> Future<(Data, HTTPURLResponse)> {
        return Future { complete in
            self.task = URLSession.shared.dataTask(with: request) { data, response, error in
                switch (response, data, error) {
                case (.some(let response as HTTPURLResponse), .some(let data), _): complete(.success((data, response)))
                case (_, _, .some(let error)): complete(.failure(error))
                default: complete(.failure(Error.unknown))
                }
            }

            self.task?.resume()
        }
    }

    public override func cancel() -> Future<Void> {
        switch self.task {
        case .none:
            return Future.failed(Error.stopped)
        case .some(let task):
            task.cancel()
            return Future.success(())
        }
    }
}

public enum ResponseError: Swift.Error {
    case decoding(DecodingError, Data)
    case other(Swift.Error)
}

public class TransformDataTo<Model: Decodable>: Service<Data, Model> {
    public override func apply(request: Data) -> Future<Model> {
        return Future<Data>(value: .success(request)).flatMap { data  -> Future<Model> in
            do {
                let value = try JSONDecoder().decode(Model.self, from: data)
                return Future.success(value)
            }
            catch let error as DecodingError {
                return Future.failed(ResponseError.decoding(error, data))
            }
            catch let error {
                return Future.failed(ResponseError.other(error))
            }
        }
    }
}




