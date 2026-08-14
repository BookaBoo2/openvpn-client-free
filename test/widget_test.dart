import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ovpn_client/main.dart';

void main() {
  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: OvpnApp()));
    expect(find.text('OpenVPN Client Free'), findsOneWidget);
  });
}
