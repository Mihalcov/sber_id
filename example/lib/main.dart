import 'package:flutter/material.dart';
import 'package:sber_id_sdk/sber_id_sdk.dart';

import 'elk_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SberIdExampleApp());
}

class SberIdExampleApp extends StatefulWidget {
  const SberIdExampleApp({super.key});

  @override
  State<SberIdExampleApp> createState() => _SberIdExampleAppState();
}

class _SberIdExampleAppState extends State<SberIdExampleApp> with WidgetsBindingObserver {
  static const _clientId = 'YOUR_CLIENT_ID';
  static const _redirectUri = 'sberidexample://auth';
  static const _partnerName = 'Sber ID Example';
  /// URL from Sber ELK cabinet; required for Android ELK widgets.
  static const _partnerProfileUrl = 'https://your-partner-profile-url';

  final _seamlessController = TextEditingController();

  String _status = 'Not initialized';
  bool _initialized = false;
  bool _loginInProgress = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _seamlessController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _initialized && !_loginInProgress) {
      _recoverPending();
    }
  }

  Future<void> _init() async {
    try {
      await SBerId.instance.initialize(
        const SBerIdConfig(
          clientId: _clientId,
          redirectUri: _redirectUri,
          partnerName: _partnerName,
          partnerProfileUrl: _partnerProfileUrl,
          scopes: ['openid', 'name', 'email', 'mapp_sso'],
        ),
      );
      setState(() {
        _initialized = true;
        _status = 'SDK initialized';
      });
      await _recoverPending();
    } catch (e) {
      setState(() => _status = 'Init error: $e');
    }
  }

  /// SDK often reports cancel before the redirect is delivered, or the activity
  /// is recreated and login() never resumes. The code then sits in native storage.
  bool _shouldWait(SBerIdAuthResponse? response) {
    if (_canExchange(response)) return false;
    if (response == null || response.isCancelled) return true;
    return response.isSuccess &&
        response.hasAuthCode &&
        (response.codeVerifier == null || response.codeVerifier!.isEmpty);
  }

  bool _canExchange(SBerIdAuthResponse? response) {
    return response != null &&
        response.isSuccess &&
        response.hasAuthCode &&
        (response.codeVerifier?.isNotEmpty ?? false);
  }

  Future<SBerIdAuthResponse?> _waitForPending() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final late = await SBerId.instance.takePendingAuthResult();
      if (_canExchange(late)) return late;
    }
    return null;
  }

  Future<void> _recoverPending() async {
    final pending = await SBerId.instance.takePendingAuthResult();
    if (!_canExchange(pending) || !mounted) return;
    setState(() => _status = _format(pending));
  }

  String _format(SBerIdAuthResponse? response) {
    if (_canExchange(response)) {
      return 'Success\nauthCode: ${response!.authCode}\ncodeVerifier: ${response.codeVerifier}';
    }
    if (response?.isSuccess == true && response!.hasAuthCode) {
      return 'Code without codeVerifier. Do not exchange it; call takePendingAuthResult() again.';
    }
    return 'Failed: ${response?.errorCode ?? "unknown"} ${response?.error ?? ""}'.trim();
  }

  Future<SBerIdAuthResponse?> _loginAndRecover(SBerIdLoginMode mode) async {
    var response = await SBerId.instance.takePendingAuthResult();
    if (!_canExchange(response)) {
      response = await SBerId.instance.login(
        options: SBerIdLoginOptions(mode: mode),
      );
    }
    if (_shouldWait(response)) {
      response = await _waitForPending() ?? response;
    }
    return response;
  }

  Future<void> _loginSeamlessFromField(TextEditingController controller) async {
    if (!_initialized || _loginInProgress) return;
    final deeplink = controller.text.trim();
    if (deeplink.isEmpty) {
      setState(() => _status = 'Enter seamless deeplink from Sber Bank');
      return;
    }
    _loginInProgress = true;
    setState(() => _status = 'Parsing SSO...');
    try {
      final sso = await SBerId.instance.extractSsoBaseUrl(deeplink);
      setState(() => _status = 'ssoBaseUrl: ${sso ?? "(null)"}\nStarting seamless login...');
      final response = await SBerId.instance.loginSeamless(seamlessDeeplink: deeplink);
      final ready = _shouldWait(response) ? (await _waitForPending() ?? response) : response;
      if (!mounted) return;
      setState(() => _status = 'Seamless\n${_format(ready)}');
    } finally {
      _loginInProgress = false;
    }
  }

  Future<void> _checkLaunchSeamless() async {
    if (!_initialized) return;
    final deeplink = await SBerId.instance.getLaunchSeamlessDeeplink();
    setState(() => _status = deeplink == null
        ? 'No launch seamless deeplink (Android intent)'
        : 'Launch deeplink:\n$deeplink');
  }

  Future<void> _login(SBerIdLoginMode mode) async {
    if (!_initialized || _loginInProgress) return;
    _loginInProgress = true;
    setState(() => _status = 'Authenticating (${mode.name})...');
    try {
      final response = await _loginAndRecover(mode);
      if (!mounted) return;
      setState(() => _status = _format(response));
    } finally {
      _loginInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Sber ID Example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(_status),
              const SizedBox(height: 16),
              SBerIdButton(
                clientId: _clientId,
                onPressed: _initialized ? () => _login(SBerIdLoginMode.standard) : null,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _initialized ? () => _login(SBerIdLoginMode.standard) : null,
                child: const Text('Login (standard)'),
              ),
              FilledButton(
                onPressed: _initialized ? () => _login(SBerIdLoginMode.web) : null,
                child: const Text('Login (web/OIDC)'),
              ),
              FilledButton(
                onPressed: _initialized
                    ? () async {
                        final installed = await SBerId.instance.isSBerIdInstalled();
                        setState(() => _status = 'Sber app installed: $installed');
                      }
                    : null,
                child: const Text('Check Sber app'),
              ),
              const Divider(),
              const Text('Seamless SSO (deeplink from Sber Bank)'),
              TextField(
                controller: _seamlessController,
                decoration: const InputDecoration(
                  hintText: 'Paste deeplink with sberIDRedirect',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              FilledButton(
                onPressed: _initialized
                    ? () => _loginSeamlessFromField(_seamlessController)
                    : null,
                child: const Text('Login seamless'),
              ),
              OutlinedButton(
                onPressed: _initialized ? _checkLaunchSeamless : null,
                child: const Text('Check launch deeplink (Android)'),
              ),
              const Divider(),
              OutlinedButton(
                onPressed: _initialized
                    ? () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const ElkDemoScreen(
                              clientId: _clientId,
                              redirectUri: _redirectUri,
                              partnerName: _partnerName,
                              partnerProfileUrl: _partnerProfileUrl,
                            ),
                          ),
                        );
                      }
                    : null,
                child: const Text('ELK demo screen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
