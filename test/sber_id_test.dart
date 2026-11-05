import 'package:flutter_test/flutter_test.dart';
import 'package:sber_id_sdk/sber_id_sdk.dart';

void main() {
  test('SBerId instance test', () {
    expect(SBerId.instance, isNotNull);
  });
}