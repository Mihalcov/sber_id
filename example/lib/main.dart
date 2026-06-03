import 'package:flutter/material.dart';
import 'package:sber_id/sber_id.dart';

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

class _SberIdExampleAppState extends State<SberIdExampleApp> {
  static const _clientId = 'YOUR_CLIENT_ID';
  static const _redirectUri = 'sberidexample://auth';
  static const _partnerName = 'Sber ID Example';
  /// URL from Sber ELK cabinet; required for Android ELK widgets.
  static const _partnerProfileUrl = 'https://your-partner-profile-url';

  final _seamlessController = TextEditingController();

  String _status = 'Not initialized';
  bool _initialized = false;

  @override
  void dispose() {
    _seamlessController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _init();
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
    } catch (e) {
      setState(() => _status = 'Init error: $e');
    }
  }

  Future<void> _loginSeamlessFromField(TextEditingController controller) async {
    if (!_initialized) return;
    final deeplink = controller.text.trim();
    if (deeplink.isEmpty) {
      setState(() => _status = 'Enter seamless deeplink from Sber Bank');
      return;
    }
    setState(() => _status = 'Parsing SSO...');
    final sso = await SBerId.instance.extractSsoBaseUrl(deeplink);
    setState(() => _status = 'ssoBaseUrl: ${sso ?? "(null)"}\nStarting seamless login...');
    final response = await SBerId.instance.loginSeamless(seamlessDeeplink: deeplink);
    setState(() {
      if (response?.isSuccess == true) {
        _status =
            'Seamless OK\nauthCode: ${response?.authCode}\ncodeVerifier: ${response?.codeVerifier}';
      } else {
        _status = 'Seamless failed: ${response?.error ?? "unknown"}';
      }
    });
  }

  Future<void> _checkLaunchSeamless() async {
    if (!_initialized) return;
    final deeplink = await SBerId.instance.getLaunchSeamlessDeeplink();
    setState(() => _status = deeplink == null
        ? 'No launch seamless deeplink (Android intent)'
        : 'Launch deeplink:\n$deeplink');
  }

  Future<void> _login(SBerIdLoginMode mode) async {
    if (!_initialized) return;
    setState(() => _status = 'Authenticating (${mode.name})...');
    final response = await SBerId.instance.login(
      options: SBerIdLoginOptions(mode: mode),
    );
    setState(() {
      if (response?.isSuccess == true) {
        _status =
            'Success\nauthCode: ${response?.authCode}\ncodeVerifier: ${response?.codeVerifier}';
      } else {
        _status = 'Failed: ${response?.error ?? "unknown"}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Sber ID Example')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
