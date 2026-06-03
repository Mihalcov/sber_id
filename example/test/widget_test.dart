import 'package:flutter_test/flutter_test.dart';
import 'package:sber_id_example/main.dart';

void main() {
  testWidgets('Example app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SberIdExampleApp());
    expect(find.textContaining('Not initialized'), findsOneWidget);
  });
}
