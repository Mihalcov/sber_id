import 'package:flutter/material.dart';
import 'package:sber_id/sber_id.dart';

/// Minimal ELK demo. Requires real [clientId], login, and [partnerProfileUrl] from Sber.
class ElkDemoScreen extends StatefulWidget {
  const ElkDemoScreen({
    super.key,
    required this.clientId,
    required this.redirectUri,
    required this.partnerName,
    this.partnerProfileUrl,
  });

  final String clientId;
  final String redirectUri;
  final String partnerName;
  final String? partnerProfileUrl;

  @override
  State<ElkDemoScreen> createState() => _ElkDemoScreenState();
}

class _ElkDemoScreenState extends State<ElkDemoScreen> {
  String _elkEventLog = 'ELK events will appear here';
  final _userIdController = TextEditingController(text: 'demo-user-id');

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _applyUserId() async {
    final id = _userIdController.text.trim();
    if (id.isEmpty) return;
    await SBerId.instance.setUserId(id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('userId set: $id')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ELK (личный кабинет)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '1. Initialize with partnerProfileUrl\n'
            '2. Login (scope mapp_sso for AppToken on iOS/Android)\n'
            '3. setUserId after login\n'
            '4. ELK container below',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _userIdController,
            decoration: const InputDecoration(
              labelText: 'userId for ELK',
              border: OutlineInputBorder(),
            ),
          ),
          FilledButton(
            onPressed: _applyUserId,
            child: const Text('Apply userId'),
          ),
          const SizedBox(height: 8),
          Text(_elkEventLog, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 12),
          SBerIdElkContainer(
            containerName: 'offer',
            containerVersion: 3,
            height: 420,
            onEvent: (e) {
              setState(() => _elkEventLog = '${e.type}${e.widgetName != null ? " ${e.widgetName}" : ""}');
            },
          ),
        ],
      ),
    );
  }
}
