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
Фильтры - `Service` преобразователи, нужны для представления `Service` в различных состояниях.

Бывает полезно изолировать некоторые этапы операций от самих операций, это позволяет повторно использовать этапы операций в других операциях.

К примеру, есть сетевой запрос у которого токен истек и при выполнении запроса будет ошибка, поэтому необходимо переавторизоваться и получить новый токен, авторизцацию можно представить в виде фильтра и тогда запрос будет выглядеть следующим образом:
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

### Создание произвольного фильтра
Чтобы создать фильтр нужно унаследоваться от `Filter<ReqIn, RepOut, ReqOut, RepIn>`

![](https://raw.githubusercontent.com/twitter/finagle/master/doc/Filters.png)

Для композиции фильтров между собой у них должны совпадать некоторые типы

Например, Filter1.RequestOut должен совпадать с Filter2.RequestIn и тд, цепочка прохождения и преобразований запросов и ответов изображена на рисунке сверху, к примеру фильтру на вход может поступить `URL`  и этот фильтр на вход следующего фильтра в цепочке может передать уже в `URLRequest`, также происходит и с ответами.

`SimpleFilter` - это фильтр, который не преобразует типы запросов и ответов.

Идея с `Service`и `Filter` была взята у проекта `Finagle` от twitter (https://github.com/twitter/finagle)
