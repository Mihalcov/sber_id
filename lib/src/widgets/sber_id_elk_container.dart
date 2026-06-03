import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Native ELK (Единый личный кабинет) container.
///
/// Requires [SBerId.instance.initialize] with [partnerProfileUrl] (Android)
/// and optional [userId] after login. For AppToken / SSO see README § ELK.
class SBerIdElkContainer extends StatefulWidget {
  static const String _viewType = 'sber_id_elk';
  static const EventChannel _elkEvents = EventChannel('sber_id/elk');

  /// Android [ELKContainerView] / iOS [additionalPath] container name.
  final String? containerName;

  /// Container version (platform-specific ELK API).
  final int? containerVersion;

  /// Android horizontal padding in dp.
  final int horizontalPadding;

  /// Fixed height for the platform view slot.
  final double height;

  /// Called on ELK widget events from native SDK.
  final void Function(SBerIdElkEvent event)? onEvent;

  const SBerIdElkContainer({
    super.key,
    this.containerName,
    this.containerVersion,
    this.horizontalPadding = 16,
    this.height = 400,
    this.onEvent,
  });

  @override
  State<SBerIdElkContainer> createState() => _SBerIdElkContainerState();
}

class SBerIdElkEvent {
  final int viewId;
  final String type;
  final String? widgetName;
  final int? httpStatusCode;
  final String? partnerErrorCode;

  const SBerIdElkEvent({
    required this.viewId,
    required this.type,
    this.widgetName,
    this.httpStatusCode,
    this.partnerErrorCode,
  });

  factory SBerIdElkEvent.fromMap(Map<dynamic, dynamic> map) {
    return SBerIdElkEvent(
      viewId: (map['viewId'] as num).toInt(),
      type: map['type'] as String? ?? 'unknown',
      widgetName: map['widgetName'] as String?,
      httpStatusCode: (map['httpStatusCode'] as num?)?.toInt(),
      partnerErrorCode: map['partnerErrorCode'] as String?,
    );
  }
}

class _SBerIdElkContainerState extends State<SBerIdElkContainer> {
  StreamSubscription<dynamic>? _subscription;
  int? _platformViewId;

  Map<String, dynamic> get _creationParams => {
        if (widget.containerName != null) 'containerName': widget.containerName,
        if (widget.containerVersion != null) 'containerVersion': widget.containerVersion,
        'horizontalPadding': widget.horizontalPadding,
        'height': widget.height.round(),
      };

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && widget.onEvent != null && (Platform.isAndroid || Platform.isIOS)) {
      _subscription = SBerIdElkContainer._elkEvents.receiveBroadcastStream().listen(
        _onElkEvent,
      );
    }
  }

  void _onElkEvent(dynamic event) {
    if (event is! Map || widget.onEvent == null) return;
    final elkEvent = SBerIdElkEvent.fromMap(event);
    if (_platformViewId != null && elkEvent.viewId != _platformViewId) return;
    widget.onEvent!(elkEvent);
  }

  void _onPlatformViewCreated(int id) {
    setState(() => _platformViewId = id);
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
    final child = Platform.isAndroid
        ? AndroidView(
            viewType: SBerIdElkContainer._viewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          )
        : Platform.isIOS
            ? UiKitView(
                viewType: SBerIdElkContainer._viewType,
                creationParams: params,
                creationParamsCodec: const StandardMessageCodec(),
                onPlatformViewCreated: _onPlatformViewCreated,
              )
            : const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      height: widget.height,
      child: child,
    );
  }
}
