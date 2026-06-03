import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sber_id/sber_id.dart';
import 'package:sber_id/sber_id_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelSBerId platform = MethodChannelSBerId();
  const MethodChannel channel = MethodChannel('sber_id_auth');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'startSberIDAuth':
            return {
              'isSuccess': true,
              'authCode': 'test_auth_code',
              'state': 'test_state',
              'nonce': 'test_nonce',
              'codeVerifier': 'test_verifier',
            };
          case 'isSberIdInstalled':
            return true;
          case 'logout':
            return null;
          case 'extractSsoBaseUrl':
            return 'test://sso-scheme';
          case 'getLaunchSeamlessDeeplink':
            return 'partner://auth?sberIDRedirect=...';
          default:
            return null;
        }
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('login success', () async {
    final result = await platform.login();
    expect(result?.isSuccess, true);
    expect(result?.authCode, 'test_auth_code');
    expect(result?.codeVerifier, 'test_verifier');
  });

  test('login cancelled from native map', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'startSberIDAuth') {
          return {
            'isSuccess': false,
            'errorCode': 'AUTH_CANCELLED',
            'error': 'User closed Safari',
          };
        }
        return null;
      },
    );
    final result = await platform.login();
    expect(result?.isCancelled, true);
    expect(result?.errorCode, SBerIdErrorCode.authCancelled);
  });

  test('login PlatformException NOT_INITIALIZED', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'startSberIDAuth') {
          throw PlatformException(code: 'NOT_INITIALIZED', message: 'call initialize');
        }
        return null;
      },
    );
    final result = await platform.login();
    expect(result?.isSuccess, false);
    expect(result?.errorCode, SBerIdErrorCode.notInitialized);
  });

  test('initialize throws SBerIdException', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (call) async {
        if (call.method == 'initialize') {
          throw PlatformException(code: 'INIT_FAILED', message: 'SDK init failed');
        }
        return null;
      },
    );
    expect(
      () => platform.initialize(
        const SBerIdConfig(
          clientId: 'x',
          redirectUri: 'app://auth',
          partnerName: 'Test',
        ),
      ),
      throwsA(isA<SBerIdException>().having((e) => e.code, 'code', 'INIT_FAILED')),
    );
  });

  test('isSberIdInstalled', () async {
    final result = await platform.isSBerIdInstalled();
    expect(result, true);
  });

  test('logout', () async {
    await platform.logout();
  });

  test('extractSsoBaseUrl', () async {
    final sso = await platform.extractSsoBaseUrl('https://example/deeplink');
    expect(sso, 'test://sso-scheme');
  });

  test('getLaunchSeamlessDeeplink', () async {
    final deeplink = await platform.getLaunchSeamlessDeeplink();
    expect(deeplink, contains('partner://'));
  });

  test('login seamless passes mode', () async {
    final result = await platform.login(
      options: const SBerIdLoginOptions(
        mode: SBerIdLoginMode.seamless,
        seamlessDeeplink: 'app://open',
        ssoBaseUrl: 'test://sso-scheme',
      ),
    );
    expect(result?.isSuccess, true);
  });
}
