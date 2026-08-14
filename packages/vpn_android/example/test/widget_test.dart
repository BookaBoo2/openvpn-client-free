import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_android_example/main.dart';

void main() {
  testWidgets('example builds', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ExampleHome()));
    expect(find.textContaining('vpn_android'), findsOneWidget);
  });
}
