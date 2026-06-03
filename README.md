# Sber ID Flutter Plugin

Flutter plugin for [Sber ID](https://developers.sber.ru/docs/ru/sberid/service/overview) authentication on **iOS** and **Android**, wrapping native SDKs:

- Android: [SIDSDK_CORE](https://developers.sber.ru/docs/ru/sberid/sdk/androidsdk/core/quick-start) (+ optional ELK)
- iOS: [SIDSDK](https://developers.sber.ru/docs/ru/sberid/sdk/iossdk/connection) via SPM / CocoaPods

## Features

- Initialize SDK with `clientId`, `redirectUri`, scopes, stand
- PKCE login with `authCode`, `state`, `nonce`, **`codeVerifier`** returned to Dart
- Login modes: `standard`, `web` (OIDC/Custom Tab), `webView`, `autoAuth`, **`seamless`**
- Seamless SSO from Sber Bank app (`extractSsoBaseUrl`, `loginSeamless`, cold-start deeplink on Android)
- Native **Sber ID button** (`SBerIdButton` Platform View)
- Native **ELK personal cabinet** (`SBerIdElkContainer` Platform View)
- Check if Sber Bank app is installed
- Logout

## Platform support

| Platform | Min version | Native SDK |
|----------|-------------|------------|
| iOS      | 14.0+       | SIDSDK ~> 1.7.4 |
| Android  | 26+ (API)   | SIDSDK_CORE 1.3.0, SIDSDK_ELK 1.3.0 |

## Installation

```yaml
dependencies:
  sber_id:
    path: ../sber_id   # or pub.dev when published
```

## iOS setup

The plugin supports **Swift Package Manager** (recommended when using Flutter 3.24+) and **CocoaPods**.

```bash
flutter config --enable-swift-package-manager
```

SPM layout: [`ios/sber_id/Package.swift`](ios/sber_id/Package.swift) (depends on `SIDSDK` and `FlutterFramework` at build time).

1. **Deployment target** 14.0+ (`ios/Podfile` or Xcode).
2. **URL scheme** in `Info.plist` (must match `redirectUri`):

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

3. **LSApplicationQueriesSchemes**, **NSAppTransportSecurity** for `id.sber.ru` — see [project configuration](https://developers.sber.ru/docs/ru/sberid/sdk/iossdk/configuration).
4. **AppToken / ELK** (optional): add `AppIdentifierPrefix`, Keychain group `ru.sid.iphone.shared` — see [ELK iOS manual](https://developers.sber.ru/docs/ru/sberid/elk/ios/manualios).
5. **SceneDelegate** (if used):

```swift
import sber_id

func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    guard let url = URLContexts.first?.url else { return }
    SberIdPlugin.handleURL(url)
}
```

Register `clientId` and `redirectUri` with Sber ID before production: **support_sberid@sber.ru**.

## Android setup

1. **minSdk 26** in `android/app/build.gradle`.
2. **Deeplink** on `MainActivity` ([quick start §5.1](https://developers.sber.ru/docs/ru/sberid/sdk/androidsdk/core/quick-start)):

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

3. **ELK** (optional): pass `partnerProfileUrl` in `SBerIdConfig` — calls `SIDELK.setProfileUrl` on Android; iOS uses `applyMainPreferences(partnerProfileUrl:)`.

## ELK (Единый личный кабинет)

ELK is **separate from OAuth UI** — users must be logged in via Sber ID first. For AppToken / partner SSO, add scope `mapp_sso` and follow:

- Android: [ELK Android SDK](https://developers.sber.ru/docs/ru/sberid/elk/androidsdk/android)
- iOS: [ELK iOS manual](https://developers.sber.ru/docs/ru/sberid/elk/ios/manualios) (Keychain group `ru.sid.iphone.shared`, `AppIdentifierPrefix` in Info.plist)

```dart
await SBerId.instance.initialize(
  SBerIdConfig(
    clientId: '...',
    redirectUri: 'yourapp://auth',
    partnerName: 'Your App',
    partnerProfileUrl: 'https://your-profile-url-from-sber',
    userId: 'optional-at-init',
    scopes: ['openid', 'name', 'email', 'mapp_sso'],
  ),
);

// After login — set OIDC sub / partner user id for ELK widgets
await SBerId.instance.setUserId(userSub);

SBerIdElkContainer(
  containerName: 'offer', // Android ELKContainerView; iOS additionalPath
  containerVersion: 3,
  height: 400,
  onEvent: (e) => debugPrint('ELK: ${e.type} ${e.widgetName}'),
);
```

| Parameter | Android | iOS |
|-----------|---------|-----|
| `partnerProfileUrl` | `SIDELK.setProfileUrl` at init | `applyMainPreferences` |
| `userId` | `SID.Settings.setMainSettings(userID)` | `applyMainPreferences(userID:)` |
| `setUserId()` | Updates user id after login | Same |

Example app: **ELK demo screen** (`example/lib/elk_screen.dart`).

## Usage

```dart
import 'package:sber_id/sber_id.dart';

await SBerId.instance.initialize(
  SBerIdConfig(
    clientId: 'your-client-id',
    redirectUri: 'yourapp://auth',
    partnerName: 'Your App',
    partnerProfileUrl: 'https://your-profile-url', // optional ELK
  ),
);

// Standard login (Sber app → web fallback)
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

// Native button — onPressed or auto login (standard)
SBerIdButton(
  clientId: 'your-client-id',
  onPressed: () async {
    final r = await SBerId.instance.login();
    // handle r
  },
);
// Without onPressed: tap starts login(mode: SBerIdLoginMode.standard) automatically

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

**Шаг 2 OAuth (обмен code → tokens на сервере):** см. [docs/OAUTH_BACKEND.md](docs/OAUTH_BACKEND.md) — PKCE, `state`/`nonce`, типичные ошибки `invalid_grant`.

## Login modes

| Dart `SBerIdLoginMode` | Android | iOS |
|------------------------|---------|-----|
| `standard` | `SIDLogin.loginWithID` | `SID.login.auth` |
| `web` | `loginWithIDToCustomTab` | `webAuth` |
| `webView` | `loginWithIDToWebView` | `loginWithIDToWebView` |
| `autoAuth` | `autoAuth` | `autoAuth` |
| `seamless` | `getSeamlessUriScheme` + `autoAuth` | `SIDUtils.getSSOUrlStringFrom` + `autoAuth` |

## Seamless SSO (from Sber Bank app)

When the user opens your app from Sber Bank with a deeplink containing `sberIDRedirect`, use seamless login:

```dart
// Parse SSO base URL from deeplink (optional; loginSeamless does this)
final sso = await SBerId.instance.extractSsoBaseUrl(deeplink);

// After user returns from Sber Bank with your redirectUri
final response = await SBerId.instance.loginSeamless(
  seamlessDeeplink: deeplink,
);

// Android cold start: deeplink in launch intent
final launchDeeplink = await SBerId.instance.getLaunchSeamlessDeeplink();
if (launchDeeplink != null) {
  await SBerId.instance.loginSeamless(seamlessDeeplink: launchDeeplink);
}
```

On iOS, handle the incoming URL in `SceneDelegate` / `AppDelegate` (e.g. with `uni_links`) and pass the full URL string to `loginSeamless`. `getLaunchSeamlessDeeplink` is Android-only.

## Example

```bash
cd example
flutter run
```

## Error handling

`login()` always completes with [SBerIdAuthResponse] (no throw on auth failure). Check `isSuccess`, `errorCode`, and `isCancelled`.

| `errorCode` | Meaning |
|-------------|---------|
| `AUTH_CANCELLED` | User closed web/Safari or flow ended without redirect |
| `LOGIN_SUPERSEDED` | New `login()` replaced a pending one |
| `INVALID_REDIRECT` | Incoming URL scheme/host ≠ `redirectUri` |
| `NOT_INITIALIZED` | `initialize()` not called |
| `NO_ACTIVITY` / `NO_VIEW_CONTROLLER` | No foreground Activity / VC |
| `AUTH_ERROR` | SDK or server rejected login |

`initialize()`, `setUserId()`, `logout()` throw [SBerIdException] on platform errors.

```dart
final r = await SBerId.instance.login();
if (r?.isCancelled == true) {
  // user dismissed
} else if (r?.isSuccess != true) {
  debugPrint('${r?.errorCode}: ${r?.error}');
}
```

## Support

- Plugin issues: [GitHub](https://github.com/nurullohabduvohidov/sber_id)
- Sber ID: support_sberid@sber.ru

## License

MIT License
