# OAuth 2.0 + PKCE: шаг 2 (обмен `authCode` на токены)

После успешного `SBerId.instance.login()` мобильное приложение получает **authorization code** и параметры PKCE. Обмен code → tokens выполняется **только на бэкенде** (с `client_secret`). См. [документацию Sber ID](https://developers.sber.ru/docs/ru/sberid/service/overview).

## Что возвращает плагин

| Поле | Назначение |
|------|------------|
| `authCode` | Код авторизации (одноразовый, короткий TTL) |
| `codeVerifier` | Секрет PKCE — **тот же**, что использовался при `createLoginUri` / `SIDAuthRequest` |
| `state` | Защита от CSRF — бэкенд должен сверить с значением, отправленным в шаге 1 |
| `nonce` | Привязка к id_token (replay) — проверяется при разборе JWT |

`codeVerifier` генерируется в нативном SDK и возвращается в Dart; **не генерируйте verifier повторно на клиенте**.

## Flutter → бэкенд

```dart
import 'package:sber_id_sdk/sber_id_sdk.dart';

Future<void> signInWithSber() async {
  await SBerId.instance.initialize(
    SBerIdConfig(
      clientId: 'your-client-id',
      redirectUri: 'yourapp://auth',
      partnerName: 'Your App',
    ),
  );

  final response = await SBerId.instance.login();
  if (response == null || !response.isSuccess || !response.hasAuthCode) {
    if (response?.isCancelled == true) return;
    throw Exception('${response?.errorCode}: ${response?.error}');
  }

  // HTTPS only — ваш API / Firebase Callable / REST
  await exchangeOnBackend(
    authCode: response.authCode!,
    codeVerifier: response.codeVerifier!,
    state: response.state,
    nonce: response.nonce,
    redirectUri: 'yourapp://auth', // тот же, что в initialize и в кабинете Sber
  );
}
```

### Рекомендации по передаче

- Используйте **TLS** (HTTPS / Callable Functions).
- Не логируйте `authCode`, `codeVerifier`, `client_secret`.
- `redirect_uri` в запросе токена **байт-в-байт** совпадает с `redirectUri` при login и с зарегистрированным в Sber ID URI.
- Сохраняйте `state` (и при необходимости `nonce`) на сервере в шаге 1 или передавайте вместе с `authCode` и **сверяйте** на бэкенде.

## Бэкенд: запрос токена (псевдокод)

Эндпоинт Sber (prod): `POST https://oauth.sber.ru/ru/prod/tokens/v2/oidc`  
Тестовый контур (IFT): `https://oauth-ift.sber.ru/ru/prod/tokens/v2/oidc`

**Prod требует mTLS:** клиентский `.p12`, выпущенный в кабинете Sber ID для этого `client_id` (CN сертификата = client_id). См. [FAQ по сертификатам](https://developers.sber.ru/docs/ru/sberid/faq/a2-work-with-certificates). На сервере oauth.sber.ru — УЦ Минцифры; в trust store нужен корневой CA РФ.

```
POST /ru/prod/tokens/v2/oidc
Content-Type: application/x-www-form-urlencoded
Accept: application/json
rquid: <uuid без дефисов>

grant_type=authorization_code
&code=<authCode>
&client_id=<CLIENT_ID>
&client_secret=<CLIENT_SECRET>
&redirect_uri=<REDIRECT_URI>
&code_verifier=<codeVerifier из Flutter>
```

Псевдокод:

```text
function exchangeSberAuthCode(body):
  require body.authCode
  require body.codeVerifier
  redirectUri = body.redirectUri ?? CONFIG.REDIRECT_URI

  // Опционально: сверка state с сессией / одноразовым store
  if body.state and SESSION.expectedState and body.state != SESSION.expectedState:
    throw 400 "invalid_state"

  response = HTTP_POST(SBER_TOKEN_URL, form={
    grant_type: "authorization_code",
    code: body.authCode,
    client_id: CONFIG.CLIENT_ID,
    client_secret: CONFIG.CLIENT_SECRET,
    redirect_uri: redirectUri,
    code_verifier: body.codeVerifier,
  }, headers={ rquid: newUuidNoDashes(), Accept: "application/json" })

  if response.status in (400, 401):
    log response.body  // см. таблицу ошибок PKCE
    throw invalid_grant

  id_token = response.json.id_token
  payload = decodeJwt(id_token)

  if body.nonce and payload.nonce != body.nonce:
    throw 401 "nonce_mismatch"

  return { sub: payload.sub, email: payload.email, ... }
```

После обмена создайте сессию пользователя в своей БД по `sub` (OIDC subject), а не по `authCode`.

## Типичные ошибки PKCE / token endpoint

| Симптом / ответ Sber | Вероятная причина | Что проверить |
|----------------------|-------------------|---------------|
| `invalid_grant`, PKCE / `code_verifier` | Неверный `code_verifier` | Берите **только** `response.codeVerifier` из плагина; не пересоздавайте на клиенте |
| `invalid_grant`, code expired | Просрочен `authCode` | Обменивайте сразу; code одноразовый |
| `invalid_grant`, redirect_uri | Несовпадение redirect | `redirect_uri` в token = `SBerIdConfig.redirectUri` = Android/iOS deeplink = кабинет Sber |
| `invalid_client` | client_id / secret | `SBER_CLIENT_ID`, `SBER_CLIENT_SECRET` на сервере |
| 400 без PKCE в теле | Отсутствует `code_verifier` | PKCE обязателен для мобильного flow Sber ID |
| Challenge mismatch | Подменён challenge на шаге 1 | Не меняйте URI/login между стартом и обменом; один непрерывный login |
| Повторный обмен того же code | Code уже использован | Один `authCode` → один token request |
| `nonce` в id_token ≠ ожидаемому | Подмена ответа / другой login | Сверяйте `nonce` из `SBerIdAuthResponse` с JWT |

### Отладка

1. Логируйте на бэкенде только `status` и **обезличенный** `error` из ответа Sber, не `code_verifier`.
2. Убедитесь, что в Cloud Functions / `.env` тот же `redirect_uri`, что в приложении.
3. Для IFT используйте `SBER_TOKEN_URL` на oauth-ift и тестовый `client_id`.

## Пример в репозитории (ПЭС)

Текущий обмен кода идёт в БрендКарта API, не через Firebase Callable:

- Flutter: `brendkarta/pes/lib/providers/auth_provider.dart` вызывает `AuthRepository.signInWithSber`
- Запрос: `POST /auth/sber` (`brendkarta-api/src/routes/auth.ts`, обмен в `src/auth/sber.ts`)
- Env API: `SBER_CLIENT_ID`, `SBER_CLIENT_SECRET`, `SBER_REDIRECT_URI`, опционально `SBER_TOKEN_URL`, для prod mTLS — `SBER_P12_PATH` / `SBER_CERT_PATH`

Старый callable `exchangeSberAuthCode` остаётся в `brendkarta/pes/functions/src/sber.js`. Файла `pes/lib/services/sber_auth_service.dart` нет.
