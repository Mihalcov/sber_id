# sber_id_example

Хост для проверки `sber_id_sdk`. Перед запуском замените `YOUR_CLIENT_ID` в `lib/main.dart` и зарегистрируйте redirect `sberidexample://auth` в кабинете Sber ID.

Сборка повторяет то, без чего вход в хост-приложении обрывался:

- Android `MainActivity` — `FlutterFragmentActivity`, не `FlutterActivity`
- `minSdk` 26, `launchMode=singleTop`, intent-filter `sberidexample://auth`
- `<queries>` на `ru.sberbankmobile`, `ru.sberbank_sbbol` и схемы Сбера
- iOS 15+, URL scheme `sberidexample`, `LSApplicationQueriesSchemes`
- `SceneDelegate` передаёт redirect в `SberIdPlugin.handleURL`
- после `login()` пример читает `takePendingAuthResult()`, если SDK успел вернуть отмену раньше redirect

Обмен `authCode` на токены в пример не входит. Его делает только бэкенд: [doc/OAUTH_BACKEND.md](../doc/OAUTH_BACKEND.md). Код без `codeVerifier` на сервер не отправляют.

ELK-экран не включает keychain group `ru.sid.iphone.shared`. Для AppToken на iOS entitlement нужно добавить в своё приложение.
