# Плагин Сбер ID для Flutter

Плагин [Сбер ID](https://developers.sber.ru/docs/ru/sberid/service/overview) для **iOS** и **Android**. Оборачивает нативные SDK:

**Поддержать проект:** [сбор в СберБанк Онлайн](https://messenger.sbrf.ru/sl/XMNhVd5RNSjvfnHRu)

- Android: [SIDSDK_CORE](https://developers.sber.ru/docs/ru/sberid/sdk/androidsdk/core/quick-start) и при необходимости ELK
- iOS: [SIDSDK](https://developers.sber.ru/docs/ru/sberid/sdk/iossdk/connection) через SPM или CocoaPods

## Возможности

- Инициализация SDK: `clientId`, `redirectUri`, scopes, стенд
- Вход с PKCE: в Dart возвращаются `authCode`, `state`, `nonce` и **`codeVerifier`**
- Режимы входа: `standard`, `web` (OIDC / Custom Tab), `webView`, `autoAuth`, **`seamless`**
- Бесшовный вход из приложения СберБанка (`extractSsoBaseUrl`, `loginSeamless`, deeplink при холодном старте на Android)
- Нативная кнопка **Сбер ID** (`SBerIdButton`, Platform View)
- Нативный **Единый личный кабинет** (`SBerIdElkContainer`, Platform View)
- Проверка, установлено ли приложение СберБанка
- Выход из сессии

## Платформы

| Платформа | Минимум | Нативный SDK |
|-----------|---------|--------------|
| iOS       | 15.0+   | SIDSDK ~> 4.0.2 |
| Android   | API 26+ | SIDSDK_CORE 1.8.0, SIDSDK_ELK 1.8.0 |

## Установка

```yaml
dependencies:
  sber_id_sdk: ^0.2.0
```

С GitHub, пока пакет не опубликован на pub.dev. Тега `v0.2.0` в репозитории нет: в `ref` укажите коммит, а не этот тег.

```yaml
dependencies:
  sber_id_sdk:
    git:
      url: https://github.com/Mihalcov/sber_id.git
      ref: <commit>
```

## Настройка iOS

Плагин собирается через **Swift Package Manager** (предпочтительно с Flutter 3.24+) и через **CocoaPods**.

```bash
flutter config --enable-swift-package-manager
```

Макет SPM: [`ios/sber_id/Package.swift`](ios/sber_id/Package.swift) (зависимости `SIDSDK` и `FlutterFramework` подключаются при сборке).

1. **Deployment target** 15.0+ (`ios/Podfile` или Xcode).
2. **URL scheme** в `Info.plist` должен совпадать с `redirectUri`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>yourapp</string>
    </array>
  </dict>
</array>
```

3. **LSApplicationQueriesSchemes** и **NSAppTransportSecurity** для `id.sber.ru` — см. [настройку проекта](https://developers.sber.ru/docs/ru/sberid/sdk/iossdk/configuration).
4. **AppToken / ELK** (необязательно): `AppIdentifierPrefix` и группа Keychain `ru.sid.iphone.shared` — см. [руководство ELK для iOS](https://developers.sber.ru/docs/ru/sberid/elk/ios/manualios).
5. Если приложение использует UIScene (как example), нужен **SceneDelegate**. Метод `application(_:open:options:)` в этом случае не вызывается: плагин не получает redirect, и `login()` завершается с `AUTH_CANCELLED`. Передайте URL в плагин и затем вызовите `super`, чтобы другой SDK мог обработать свою ссылку:

```swift
import sber_id

override func scene(
  _ scene: UIScene,
  openURLContexts URLContexts: Set<UIOpenURLContext>
) {
  for context in URLContexts {
    if SberIdPlugin.handleURL(context.url) { return }
  }
  super.scene(scene, openURLContexts: URLContexts)
}
```

До продакшена зарегистрируйте `clientId` и `redirectUri` в Сбер ID: **support_sberid@sber.ru**.

## Настройка Android

1. **minSdk 26** в `android/app/build.gradle`.
2. **`MainActivity` наследует `FlutterFragmentActivity`**, не `FlutterActivity`. Обычный вход вызывает `SIDLogin.loginWithID`, которому нужен `FragmentActivity`. С `FlutterActivity` плагин вернёт `NO_ACTIVITY` / `AUTH_ERROR`, и шторка Сбера не откроется.
3. **Видимость пакетов** (`<queries>`). На Android 11+ приложение Сбера не видно, пока его не объявить. Тогда `isSBerIdInstalled()` будет `false`, и нативный вход не откроет приложение банка:

```xml
<queries>
    <package android:name="ru.sberbankmobile" />
    <package android:name="ru.sberbank_sbbol" />
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="sberbankidexternallogin" />
    </intent>
    <intent>
        <action android:name="android.intent.action.VIEW" />
        <data android:scheme="sbolidexternallogin" />
    </intent>
</queries>
```

4. **Deeplink** на `MainActivity` ([быстрый старт, §5.1](https://developers.sber.ru/docs/ru/sberid/sdk/androidsdk/core/quick-start)). `android:launchMode="singleTop"`. Scheme и host должны совпадать со строкой `SBerIdConfig.redirectUri` (в example это `sberidexample://auth`):

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    ...>
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data
            android:scheme="yourapp"
            android:host="auth" />
    </intent-filter>
</activity>
```

5. **ELK** (необязательно): передайте `partnerProfileUrl` в `SBerIdConfig`. На Android вызывается `SIDELK.setProfileUrl`, на iOS — `applyMainPreferences(partnerProfileUrl:)`.
6. Если переопределяете `onNewIntent`, вызовите `setIntent(intent)` до `super.onNewIntent(intent)`. Иначе redirect останется на старом intent, `login()` вернётся с `AUTH_CANCELLED`, а код будет только в `takePendingAuthResult()`.

## ELK (Единый личный кабинет)

ELK не заменяет экран входа: сначала пользователь должен войти через Сбер ID. Для AppToken и перехода на сайт партнёра добавьте scope `mapp_sso` и смотрите документацию:

- Android: [ELK Android SDK](https://developers.sber.ru/docs/ru/sberid/elk/androidsdk/android)
- iOS: [руководство ELK](https://developers.sber.ru/docs/ru/sberid/elk/ios/manualios) (группа Keychain `ru.sid.iphone.shared`, `AppIdentifierPrefix` в Info.plist)

```dart
await SBerId.instance.initialize(
  SBerIdConfig(
    clientId: '...',
    redirectUri: 'yourapp://auth',
    partnerName: 'Ваше приложение',
    partnerProfileUrl: 'https://your-profile-url-from-sber',
    userId: 'необязательно при инициализации',
    scopes: ['openid', 'name', 'email', 'mapp_sso'],
  ),
);

// После входа: OIDC sub или id пользователя партнёра для виджетов ELK
await SBerId.instance.setUserId(userSub);

SBerIdElkContainer(
  containerName: 'offer', // Android: ELKContainerView; iOS: additionalPath
  containerVersion: 3,
  height: 400,
  onEvent: (e) => debugPrint('ELK: ${e.type} ${e.widgetName}'),
);
```

| Параметр | Android | iOS |
|----------|---------|-----|
| `partnerProfileUrl` | `SIDELK.setProfileUrl` при инициализации | `applyMainPreferences` |
| `userId` | `SID.Settings.setMainSettings(userID)` | `applyMainPreferences(userID:)` |
| `partnerName` | в SID 1.8 поля настроек нет, в Dart параметр всё равно обязательный | `applyMainPreferences(partnerName:)` |
| `setUserId()` | обновляет user id после входа | то же |

Экран в example: **демо ELK** (`example/lib/elk_screen.dart`).

## Использование

```dart
import 'package:sber_id_sdk/sber_id_sdk.dart';

await SBerId.instance.initialize(
  SBerIdConfig(
    clientId: 'your-client-id',
    redirectUri: 'yourapp://auth',
    partnerName: 'Ваше приложение',
    partnerProfileUrl: 'https://your-profile-url', // необязательно, для ELK
  ),
);

// Обычный вход: приложение Сбера, иначе веб
final response = await SBerId.instance.login(
  options: SBerIdLoginOptions(mode: SBerIdLoginMode.standard),
);

// Веб / OIDC
await SBerId.instance.login(
  options: SBerIdLoginOptions(
    mode: SBerIdLoginMode.web,
    customTabRedirectUri: 'yourapp://auth',
  ),
);

// Нативная кнопка: свой onPressed или автоматический вход
SBerIdButton(
  clientId: 'your-client-id',
  onPressed: () async {
    final r = await SBerId.instance.login();
    // обработайте r
  },
);
// Без onPressed нажатие само вызывает login(mode: SBerIdLoginMode.standard)

if (response?.isSuccess == true) {
  await yourBackend.exchange(
    authCode: response!.authCode!,
    codeVerifier: response.codeVerifier!,
    state: response.state,
    nonce: response.nonce,
    redirectUri: 'yourapp://auth',
  );
}
```

**Шаг 2 OAuth (обмен code на токены на сервере):** см. [doc/OAUTH_BACKEND.md](doc/OAUTH_BACKEND.md) — PKCE, `state`/`nonce`, типичные ошибки `invalid_grant`.

## Режимы входа

| Dart `SBerIdLoginMode` | Android | iOS |
|------------------------|---------|-----|
| `standard` | `SIDLogin.loginWithID` | `SID.login.auth` |
| `web` | `loginWithIDToCustomTab` | `webAuth` |
| `webView` | `loginWithIDToWebView` | `loginWithIDToWebView` |
| `autoAuth` | `autoAuth` | `autoAuth` |
| `seamless` | `getSeamlessUriScheme` + `autoAuth` | `SIDUtils.getSSOUrlStringFrom` + `autoAuth` |

## Бесшовный вход из приложения СберБанка

Если пользователь открыл ваше приложение из СберБанка по deeplink с параметром `sberIDRedirect`, используйте бесшовный вход:

```dart
// Базовый SSO URL из deeplink (необязательно: loginSeamless делает это сам)
final sso = await SBerId.instance.extractSsoBaseUrl(deeplink);

final response = await SBerId.instance.loginSeamless(
  seamlessDeeplink: deeplink,
);

// Холодный старт на Android: deeplink в intent запуска
final launchDeeplink = await SBerId.instance.getLaunchSeamlessDeeplink();
if (launchDeeplink != null) {
  await SBerId.instance.loginSeamless(seamlessDeeplink: launchDeeplink);
}
```

На iOS обратный URL должен попасть в `SberIdPlugin.handleURL` (см. SceneDelegate выше). `getLaunchSeamlessDeeplink` есть только на Android: на iOS метод возвращает `null`.

Нативный SDK часто завершает вход с `AUTH_CANCELLED` раньше, чем приходит redirect, либо Android пересоздаёт activity и `login()` не возобновляется. Код при этом сохраняется нативно. Не отправляйте код на бэкенд без `codeVerifier`. Прочитайте сохранённый результат после `login()` и ещё раз, когда приложение снова станет активным:

```dart
final pending = await SBerId.instance.takePendingAuthResult();
if (pending != null &&
    pending.isSuccess &&
    pending.hasAuthCode &&
    (pending.codeVerifier?.isNotEmpty ?? false)) {
  // обмен pending.authCode + pending.codeVerifier
}
```

`takePendingAuthResult()` отдаёт результат один раз. На iOS метод ничего не делает (`null`), пока результат не был сохранён. Example в этом репозитории после отмены несколько секунд опрашивает Android.

## Пример

```bash
cd example
flutter run
```

## Ошибки

`login()` всегда завершается объектом [SBerIdAuthResponse] и не бросает исключение при неуспешном входе. Смотрите `isSuccess`, `errorCode` и `isCancelled`.

| `errorCode` | Значение |
|-------------|----------|
| `AUTH_CANCELLED` | Пользователь закрыл веб или Safari, либо сценарий закончился без redirect |
| `LOGIN_SUPERSEDED` | Новый `login()` заменил ещё не завершённый |
| `INVALID_REDIRECT` | Scheme или host входящего URL не совпадает с `redirectUri` |
| `NOT_INITIALIZED` | Не вызван `initialize()` |
| `NO_ACTIVITY` / `NO_VIEW_CONTROLLER` | Нет Activity или контроллера на переднем плане |
| `AUTH_ERROR` | SDK или сервер отклонили вход |

`initialize()`, `setUserId()` и `logout()` при ошибке платформы бросают [SBerIdException].

```dart
final r = await SBerId.instance.login();
if (r?.isCancelled == true) {
  // пользователь закрыл вход
} else if (r?.isSuccess != true) {
  debugPrint('${r?.errorCode}: ${r?.error}');
}
```

## Поддержать проект

Сбор на развитие плагина в СберБанк Онлайн:  
https://messenger.sbrf.ru/sl/XMNhVd5RNSjvfnHRu

## Поддержка

- Вопросы по плагину: [GitHub](https://github.com/Mihalcov/sber_id/issues)
- SDK Сбер ID: support_sberid@sber.ru

## Лицензия

Код плагина: MIT (`LICENSE`).

Нативные SDK Сбер ID (SIDSDK, SIDSDK_CORE, SIDSDK_ELK) — сторонние библиотеки со своими лицензиями: [sid-sdk](https://github.com/sid-sdk/SIDSDK) и Maven Central. Проверьте их до публикации приложения, которое зависит от этого плагина.
