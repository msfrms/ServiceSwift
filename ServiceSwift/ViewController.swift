//
//  ViewController.swift
//  ServiceSwift
//
//  Created by Radaev Mikhail on 25.03.2018.
//  Copyright © 2018 msfrms. All rights reserved.
//

import UIKit
import ConcurrentSwift

extension String: Swift.Error {}
extension URL {
    func with(pagination: Pagination) -> URL {
        if (self.absoluteString.contains("?")) {
            return URL(string: self.absoluteString + "&offset=\(pagination.offset)&limit=\(pagination.limit)")!
        } else {
            return URL(string: self.absoluteString + "?offset=\(pagination.offset)&limit=\(pagination.limit)")!
        }
    }
}

class LongOperationService: Service<Int, String> {
    override func apply(request: Int) -> Future<String> {
        return Future<String> { complete in
            sleep(2)
            complete(.success("ok"))
        }
    }

    override func cancel() -> Future<Void> {
        print("cancel")
        return Future.success(())
    }
}

class TestRetryService: Service<Void, String> {

    private var attempt: Int = 0

    override func apply(request: Void) -> Future<String> {
        self.attempt = self.attempt + 1

        print("attempt \(self.attempt)")

        if (self.attempt > 2) {
            return Future<String>.success("ok")
        } else {
            return Future.failed("error")
        }
    }
}

struct AuthError: Swift.Error {}

protocol Authorize {
    func authorize() -> Future<String>
}

// пример фильтра обработки ошибки авторизации
class AuthFilter<Req, Rep>: SimpleFilter<Req, Rep> {

    let auth: Authorize

    init(auth: Authorize) {
        self.auth = auth
    }

    override func apply(request: Req, service: Service<Req, Rep>) -> Future<Rep> {
        return service.apply(request: request).rescue { (error: Error) -> Future<Rep> in
            switch error {
            case is AuthError:
                return self.auth.authorize().flatMap { token -> Future<Rep> in
                    // после авторизации запускаем операцию снова
                    return service.apply(request: request)
                }
            // если не ошибка авторизации передаем ее дальше по цепочке фильтров
            default: return Future.failed(error)
            }
        }
    }
}

class RefreshTokenAuthorize: Authorize {
    func authorize() -> Future<String> {
        return Future<String> { complete in
            // логика обновления токена через апи refresh token
            // как правило у такого апи на вход поступает старый токен на выходе получаем новый
            sleep(3)
            complete(.success("new token"))
        }
    }
}

// UI авторизация для теста представлена просто alert'ом при нажатии на кнопку OK авторизация считается успешной
class LoginPasswordUIAuthorize: Authorize {

    weak var parentViewController: UIViewController?

    init(parentViewController: UIViewController) {
       self.parentViewController = parentViewController
    }

    func authorize() -> Future<String> {
        return Future(queue: .main) { complete in
            let alert = UIAlertController(title: "Авторизация", message: "тестовый пример ui авторизации", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { action in
                complete(.success("new token"))
            })

            self.parentViewController?.present(alert, animated: true)
        }
    }
}

// Симуляция сетевого запроса чувствительного к авторизации
class AuthTestService: Service<Void, String> {

    private var attempt = 0

    override func apply(request: Void) -> Future<String> {

        self.attempt = self.attempt + 1

        if self.attempt == 1 {
            return Future.failed(AuthError())
        } else {
            return Future<String>.success("OK")
        }
    }
}

struct Pagination {
    let offset: Int
    let limit: Int

    var next: Pagination { return Pagination(offset: self.offset + 1, limit: self.limit) }
    var start: Pagination { return Pagination(offset: 1, limit: 15) }
    var prev: Pagination {
        guard self.offset > 1 else { return self.start }
        return Pagination(offset: self.offset - 1, limit: self.limit)
    }
}

enum PagingAction {
    case prev
    case next
    case start
}
// простой пример пагинации в фильтре, добавляется в цепочку фильтров через andThen
class PaginationFilter<Rep>: Filter<PagingAction, Rep, URLRequest, Rep> {

    private var pagination = Pagination(offset: 1, limit: 15)
    private var request: URLRequest

    init(request: URLRequest) {
        self.request = request
    }

    override func apply(request: PagingAction, service: Service<URLRequest, Rep>) -> Future<Rep> {
        var req = self.request
        switch request {
        case .next: self.pagination = self.pagination.next
        case .prev: self.pagination = self.pagination.prev
        case .start: self.pagination = self.pagination.start
        }
        req.url = self.request.url?.with(pagination: self.pagination)
        return service.apply(request: req)
    }
}

class NetworkTestService: Service<URLRequest, String> {
    override func apply(request: URLRequest) -> Future<String> {
        return Future<String> { complete in
            sleep(3)
            complete(.success(request.url.flatMap { url -> String? in url.absoluteString }!))
        }
    }
}

// содержит тестовые кейсы работы с Service и Filter
class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        TimeoutFilter<Int, String>(.seconds(1), byQueue: .global())
                .andThen(LongOperationService())
                .apply(request: 42)
                .respond { result in print("result is \(result)") }

        RetryFilter<Void, String>(attempt: 3)
                .andThen(TestRetryService())
                .apply().respond { result in print("result is \(result)") }

        // вместо LoginPasswordUIAuthorize можно использовать RefreshTokenAuthorize
        AuthFilter<Void, String>(auth: LoginPasswordUIAuthorize(parentViewController: self))
                .andThen(AuthTestService())
                .apply()
                .respond { result in print("result is \(result)") }

        let service = PaginationFilter<String>(request: URLRequest(url: URL(string: "http://test.com/v1/api/feeds")!))
                .andThen(NetworkTestService())

        service.apply(request: .start).onSuccess { response in print("pagination start response is \(response)") }
        service.apply(request: .next).onSuccess { response in print("pagination next response is \(response)") }

        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

