# Sber ID plugin for Flutter

Russian guide: [doc/README.ru.md](doc/README.ru.md)

Flutter plugin for [Sber ID](https://developers.sber.ru/docs/ru/sberid/service/overview) on **iOS** and **Android**. It wraps the native SDKs:

**Support the project:** [SberBank Online collection](https://messenger.sbrf.ru/sl/XMNhVd5RNSjvfnHRu)

- Android: [SIDSDK_CORE](https://developers.sber.ru/docs/ru/sberid/sdk/androidsdk/core/quick-start) and, when needed, ELK
- iOS: [SIDSDK](https://developers.sber.ru/docs/ru/sberid/sdk/iossdk/connection) via Swift Package Manager or CocoaPods

## Features

- SDK setup: `clientId`, `redirectUri`, scopes, stand
- PKCE login: Dart receives `authCode`, `state`, `nonce`, and **`codeVerifier`**
- Login modes: `standard`, `web` (OIDC / Custom Tab), `webView`, `autoAuth`, **`seamless`**
- Seamless sign-in from the SberBank app (`extractSsoBaseUrl`, `loginSeamless`, cold-start deeplink on Android)
- Native **Sber ID** button (`SBerIdButton`, platform view)
- Native personal cabinet (`SBerIdElkContainer`, platform view)
- Check whether the SberBank app is installed
- Logout

## Platforms

| Platform | Minimum | Native SDK |
|----------|---------|------------|
| iOS      | 15.0+   | SIDSDK ~> 4.0.2 |
| Android  | API 26+ | SIDSDK_CORE 1.8.0, SIDSDK_ELK 1.8.0 |

## Install

```yaml
dependencies:
  sber_id_sdk: ^0.2.1
```

From GitHub, when you need a specific revision. Put a commit in `ref`.

```yaml
dependencies:
  sber_id_sdk:
    git:
      url: https://github.com/Mihalcov/sber_id.git
      ref: <commit>
```

## iOS setup

The plugin builds with **Swift Package Manager** (preferred on Flutter 3.24+) and with **CocoaPods**.

```bash
flutter config --enable-swift-package-manager
```

SPM manifest: [`ios/sber_id_sdk/Package.swift`](ios/sber_id_sdk/Package.swift). `SIDSDK` and `FlutterFramework` are linked at build time.

1. **Deployment target** 15.0+ (`ios/Podfile` or Xcode).
2. The **URL scheme** in `Info.plist` must match `redirectUri`:

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

3. **LSApplicationQueriesSchemes** and **NSAppTransportSecurity** for `id.sber.ru`. See the [project setup guide](https://developers.sber.ru/docs/ru/sberid/sdk/iossdk/configuration).
4. **AppToken / ELK** (optional): `AppIdentifierPrefix` and the Keychain group `ru.sid.iphone.shared`. See the [iOS ELK guide](https://developers.sber.ru/docs/ru/sberid/elk/ios/manualios).
5. If the app uses UIScene (the example does), add a **SceneDelegate**. `application(_:open:options:)` is not called, the plugin never sees the redirect, and `login()` finishes with `AUTH_CANCELLED`. Pass the URL to the plugin, then call `super`, so another SDK can handle its own link:

```swift
import sber_id_sdk

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

Before production, register `clientId` and `redirectUri` with Sber ID: **support_sberid@sber.ru**.

## Android setup

1. **minSdk 26** in `android/app/build.gradle`.
2. **`MainActivity` extends `FlutterFragmentActivity`**, not `FlutterActivity`. The standard login calls `SIDLogin.loginWithID`, which needs a `FragmentActivity`. With `FlutterActivity` the plugin returns `NO_ACTIVITY` / `AUTH_ERROR` and the Sber sheet does not open.
3. **Package visibility** (`<queries>`). On Android 11+ the Sber app is invisible until you declare it. Then `isSBerIdInstalled()` is `false` and native login does not open the bank app:

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

4. **Deeplink** on `MainActivity` ([quick start, section 5.1](https://developers.sber.ru/docs/ru/sberid/sdk/androidsdk/core/quick-start)). `android:launchMode="singleTop"`. Scheme and host must match `SBerIdConfig.redirectUri` (the example uses `sberidexample://auth`):

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

5. **ELK** (optional): pass `partnerProfileUrl` in `SBerIdConfig`. Android calls `SIDELK.setProfileUrl`. iOS calls `applyMainPreferences(partnerProfileUrl:)`.
6. If you override `onNewIntent`, call `setIntent(intent)` before `super.onNewIntent(intent)`. Otherwise the redirect stays on the old intent, `login()` returns `AUTH_CANCELLED`, and the code is only available from `takePendingAuthResult()`.

## ELK (personal cabinet)

ELK does not replace the login screen: the user signs in with Sber ID first. For AppToken and the jump to the partner site, add the `mapp_sso` scope and follow the docs:

- Android: [ELK Android SDK](https://developers.sber.ru/docs/ru/sberid/elk/androidsdk/android)
- iOS: [ELK guide](https://developers.sber.ru/docs/ru/sberid/elk/ios/manualios) (Keychain group `ru.sid.iphone.shared`, `AppIdentifierPrefix` in Info.plist)

```dart
await SBerId.instance.initialize(
  SBerIdConfig(
    clientId: '...',
    redirectUri: 'yourapp://auth',
    partnerName: 'Your app',
    partnerProfileUrl: 'https://your-profile-url-from-sber',
    userId: 'optional at init',
    scopes: ['openid', 'name', 'email', 'mapp_sso'],
  ),
);

// After login: OIDC sub or the partner user id for ELK widgets
await SBerId.instance.setUserId(userSub);

SBerIdElkContainer(
  containerName: 'offer', // Android: ELKContainerView; iOS: additionalPath
  containerVersion: 3,
  height: 400,
  onEvent: (e) => debugPrint('ELK: ${e.type} ${e.widgetName}'),
);
```

| Parameter | Android | iOS |
|-----------|---------|-----|
| `partnerProfileUrl` | `SIDELK.setProfileUrl` during init | `applyMainPreferences` |
| `userId` | `SID.Settings.setMainSettings(userID)` | `applyMainPreferences(userID:)` |
| `partnerName` | SID 1.8 has no settings field for it; the Dart parameter is still required | `applyMainPreferences(partnerName:)` |
| `setUserId()` | updates the user id after login | same |

Example screen: **ELK demo** (`example/lib/elk_screen.dart`).

## Usage

```dart
import 'package:sber_id_sdk/sber_id_sdk.dart';

await SBerId.instance.initialize(
  SBerIdConfig(
    clientId: 'your-client-id',
    redirectUri: 'yourapp://auth',
    partnerName: 'Your app',
    partnerProfileUrl: 'https://your-profile-url', // optional, for ELK
  ),
);

// Standard login: Sber app, otherwise web
final response = await SBerId.instance.login(
  options: SBerIdLoginOptions(mode: SBerIdLoginMode.standard),
);

// Web / OIDC
await SBerId.instance.login(
  options: SBerIdLoginOptions(
    mode: SBerIdLoginMode.web,
    customTabRedirectUri: 'yourapp://auth',
  ),
);

// Native button: your own onPressed, or automatic login
SBerIdButton(
  clientId: 'your-client-id',
  onPressed: () async {
    final r = await SBerId.instance.login();
    // handle r
  },
);
// Without onPressed, a tap calls login(mode: SBerIdLoginMode.standard)

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

**OAuth step 2 (exchange the code for tokens on your server):** see [doc/OAUTH_BACKEND.md](doc/OAUTH_BACKEND.md). It covers PKCE, `state` / `nonce`, and typical `invalid_grant` errors.

## Login modes

| Dart `SBerIdLoginMode` | Android | iOS |
|------------------------|---------|-----|
| `standard` | `SIDLogin.loginWithID` | `SID.login.auth` |
| `web` | `loginWithIDToCustomTab` | `webAuth` |
| `webView` | `loginWithIDToWebView` | `loginWithIDToWebView` |
| `autoAuth` | `autoAuth` | `autoAuth` |
| `seamless` | `getSeamlessUriScheme` + `autoAuth` | `SIDUtils.getSSOUrlStringFrom` + `autoAuth` |

## Seamless sign-in from the SberBank app

If the user opened your app from SberBank by a deeplink with `sberIDRedirect`, use seamless login:

```dart
// Base SSO URL from the deeplink (optional: loginSeamless does this itself)
final sso = await SBerId.instance.extractSsoBaseUrl(deeplink);

final response = await SBerId.instance.loginSeamless(
  seamlessDeeplink: deeplink,
);

// Android cold start: deeplink from the launch intent
final launchDeeplink = await SBerId.instance.getLaunchSeamlessDeeplink();
if (launchDeeplink != null) {
  await SBerId.instance.loginSeamless(seamlessDeeplink: launchDeeplink);
}
```

On iOS the return URL must reach `SberIdPlugin.handleURL` (see SceneDelegate above). `getLaunchSeamlessDeeplink` exists only on Android. On iOS it returns `null`.

The native SDK often finishes login with `AUTH_CANCELLED` before the redirect arrives, or Android recreates the activity and `login()` does not resume. The code is still stored natively. Do not send a code to the backend without `codeVerifier`. Read the stored result after `login()`, and again when the app becomes active:

```dart
final pending = await SBerId.instance.takePendingAuthResult();
if (pending != null &&
    pending.isSuccess &&
    pending.hasAuthCode &&
    (pending.codeVerifier?.isNotEmpty ?? false)) {
  // exchange pending.authCode + pending.codeVerifier
}
```

`takePendingAuthResult()` returns the result once. On iOS it does nothing (`null`) until a result has been stored. The example in this repo polls Android for a few seconds after a cancel.

## Example

```bash
cd example
flutter run
```

## Errors

`login()` always completes with a [SBerIdAuthResponse] and does not throw when sign-in fails. Check `isSuccess`, `errorCode`, and `isCancelled`.

| `errorCode` | Meaning |
|-------------|---------|
| `AUTH_CANCELLED` | The user closed web or Safari, or the flow ended without a redirect |
| `LOGIN_SUPERSEDED` | A new `login()` replaced one that had not finished |
| `INVALID_REDIRECT` | Scheme or host of the incoming URL does not match `redirectUri` |
| `NOT_INITIALIZED` | `initialize()` was not called |
| `NO_ACTIVITY` / `NO_VIEW_CONTROLLER` | No foreground Activity or view controller |
| `AUTH_ERROR` | The SDK or the server rejected the login |

`initialize()`, `setUserId()`, and `logout()` throw [SBerIdException] on a platform error.

```dart
final r = await SBerId.instance.login();
if (r?.isCancelled == true) {
  // the user closed the login
} else if (r?.isSuccess != true) {
  debugPrint('${r?.errorCode}: ${r?.error}');
}
```

## Support the project

SberBank Online collection for this plugin:

https://messenger.sbrf.ru/sl/XMNhVd5RNSjvfnHRu

## Support

- Plugin issues: [GitHub](https://github.com/Mihalcov/sber_id/issues)
- Sber ID SDK: support_sberid@sber.ru

## License

Plugin code: MIT (`LICENSE`).

The Sber ID native SDKs (SIDSDK, SIDSDK_CORE, SIDSDK_ELK) are third-party libraries with their own licenses: [sid-sdk](https://github.com/sid-sdk/SIDSDK) and Maven Central. Check them before you ship an app that depends on this plugin.
