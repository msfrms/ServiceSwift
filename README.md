# ServiceSwift
### Service
`Service` - это абстракция для представления асинхронных операций

Простой пример сервиса:
```swift
class TestService: Service<Int, String> {
    override func apply(request: Int) -> Future<String> {
        return Future<String>.success("test ok")
    }
}
```

### Filter
Фильтры - сервис преобразователи, нужны для представления сервиса в различных состояниях.

Бывает полезно изолировать некоторые этапы операций от самих операций, в качестве этапов могут выступать фильтров, также это позволяет переиспользовать фильтры в похожих операциях, к примеру если сделать фильтр для авторизации, то его можно применить к любому сервису, в случае если сервис реализует какое - либо апи.

### Примеры фильтров
#### Фильтр авторизации
Есть сетевой запрос у которого истек токен и при выполнении запроса будет ошибка о необходимости авторизоваться, поэтому  авторизцацию можно представить в виде фильтра и тогда запрос будет выглядеть следующим образом:
```swift
AuthFilter<Void, String>()
        .andThen(TestService())
        .apply()
        .respond { result in print("result is \(result)") }
```
с помощью метода `andThen` происходит композиция фильтров, к примеру к запросу выше можно добавить фильтр `RetryFilter`, для того чтобы задать количество попыток для выполнения запроса при ошибке:
```swift
AuthFilter<Void, String>()
        .andThen(RetryFilter<Void, String>(attempt: 3))
        .andThen(TestService())
        .apply()
        .respond { result in print("result is \(result)") }
```
при возникновении ошибки запрос будет выполнен 3 раза, если все равно не удалось успешно выполнить то будет возвращена ошибка

#### Простой сетевой запрос к апи
```swift
TransformFailureIfNeededTo<UserError, User>()
                .andThen(TransformJsonTo<User>())
                .andThen(NetworkDataService())
                .apply(request: URLRequest(url: URL(string: "<url>")!))
                .respond { result in print("result is \(result)") }
```

`NetworkDataService` передает `(Data, HTTPURLResponse)` в `TransformJsonTo<User>`, фильтр пытается преобразовать `Data`к `User`, если не получилось, то `TransformFailureIfNeededTo<UserError, User>` пытается преобразовать `Data` к `UserError`, это полезно в случае если апи всегда возвращает http статус 200 и в http body может приходить и модель, и ошибка, в данном примере это 2 модели `User`и `UserError`. 

_Уточнение_

В случае когда возвращается `NSError`, то нужно вместо фильтра `TransformFailureIfNeededTo`, написать свой фильтр который правильно преобразует из `NSError` к нужному типу.


### Создание произвольного фильтра
Чтобы создать фильтр нужно унаследоваться от `Filter<ReqIn, RepOut, ReqOut, RepIn>`

![](https://raw.githubusercontent.com/twitter/finagle/master/doc/Filters.png)

К примеру, есть сервис для записи какой - либо модели в БД, `RequestIn` будет такого же типа как модель, а `RequestOut` будет типом понятный БД, например `Dictionary<Key, Value>`, в этом примере фильтр будет выступать в качестве `map(RequestIn) -> RequestOut`, аналогичная ситуация и с `ResponseIn` и `ResponseOut`

`SimpleFilter` - это фильтр, который не преобразует типы запросов и ответов. (`RequestIn == RequestOut`, `ResponseIn == ResponseOut`)

Идея с `Service`и `Filter` была взята у проекта `Finagle` от twitter (https://github.com/twitter/finagle)
