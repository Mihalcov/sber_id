import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/sber_id_login_mode.dart';
import '../models/sber_id_login_options.dart';
import '../sber_id_api.dart';

/// Native Sber ID login button ([SIDButton] on Android, [SIDLoginButton] on iOS).
///
/// On tap, [onPressed] is called if provided; otherwise [SBerId.instance.login] runs
/// with [loginMode] (default [SBerIdLoginMode.standard]).
class SBerIdButton extends StatefulWidget {
  static const String _viewType = 'sber_id_button';
  static const EventChannel _buttonEvents = EventChannel('sber_id/button');

  final String? clientId;
  final double width;
  final double height;
  final double cornerRadius;

  /// iOS: `green` or `white`.
  final String style;

  /// iOS: `general`, `short`, `filling`, or `pursue`.
  final String textType;

  /// Called when the native button is pressed. If null, starts [loginMode] auth.
  final VoidCallback? onPressed;

  /// Used when [onPressed] is null.
  final SBerIdLoginMode loginMode;

  const SBerIdButton({
    super.key,
    this.clientId,
    this.width = 300,
    this.height = 60,
    this.cornerRadius = 4,
    this.style = 'green',
    this.textType = 'general',
    this.onPressed,
    this.loginMode = SBerIdLoginMode.standard,
  });

  @override
  State<SBerIdButton> createState() => _SBerIdButtonState();
}

class _SBerIdButtonState extends State<SBerIdButton> {
  StreamSubscription<dynamic>? _subscription;
  int? _platformViewId;

  Map<String, dynamic> get _creationParams => {
        if (widget.clientId != null) 'clientId': widget.clientId,
        'width': widget.width,
        'height': widget.height,
        'cornerRadius': widget.cornerRadius,
        'style': widget.style,
        'textType': widget.textType,
      };

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _subscription = SBerIdButton._buttonEvents.receiveBroadcastStream().listen(
        _onButtonEvent,
      );
    }
  }

  void _onButtonEvent(dynamic event) {
    if (event is! Map) return;
    final viewId = event['viewId'];
    if (viewId == null || _platformViewId == null) return;
    final eventId = viewId is int ? viewId : (viewId as num).toInt();
    if (eventId != _platformViewId) return;

    if (widget.onPressed != null) {
      widget.onPressed!();
      return;
    }
    unawaited(
      SBerId.instance.login(
        options: SBerIdLoginOptions(mode: widget.loginMode),
      ),
    );
  }

  void _onPlatformViewCreated(int id) {
    _platformViewId = id;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }
    final params = _creationParams;
    if (Platform.isAndroid) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: AndroidView(
          viewType: SBerIdButton._viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      );
    }
    if (Platform.isIOS) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: UiKitView(
          viewType: SBerIdButton._viewType,
          creationParams: params,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
