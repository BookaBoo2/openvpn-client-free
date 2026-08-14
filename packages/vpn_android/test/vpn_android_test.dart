import 'package:flutter_test/flutter_test.dart';
import 'package:vpn_android/vpn_android.dart';

void main() {
  test('AppFilterMode wire roundtrip', () {
    expect(AppFilterMode.fromWire('whitelist'), AppFilterMode.whitelist);
    expect(AppFilterMode.fromWire('blacklist'), AppFilterMode.blacklist);
    expect(AppFilterMode.fromWire(null), AppFilterMode.all);
    expect(AppFilterMode.whitelist.wire, 'whitelist');
  });

  test('VpnProfile fromMap / toMap', () {
    final profile = VpnProfile.fromMap({
      'id': '1',
      'name': 'Home',
      'ovpnConfig': 'client',
      'appFilterMode': 'blacklist',
      'packageNames': ['com.example.app'],
      'isDefault': true,
    });
    expect(profile.name, 'Home');
    expect(profile.appFilterMode, AppFilterMode.blacklist);
    expect(profile.packageNames, ['com.example.app']);
    expect(profile.toMap()['appFilterMode'], 'blacklist');
  });
}
