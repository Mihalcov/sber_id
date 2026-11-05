import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sber_id_example/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('sber_id_auth');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Example app shows login after SDK init', (tester) async {
    await tester.pumpWidget(const SberIdExampleApp());
    expect(find.textContaining('Not initialized'), findsOneWidget);

    await tester.pump();

    expect(find.text('SDK initialized'), findsOneWidget);
    expect(find.text('Login (standard)'), findsOneWidget);
    expect(find.text('Login (web/OIDC)'), findsOneWidget);
    expect(find.text('ELK demo screen'), findsOneWidget);
  });
}
