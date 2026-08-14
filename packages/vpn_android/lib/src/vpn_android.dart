import 'dart:async';

import 'package:flutter/services.dart';

import 'models.dart';

class VpnAndroid {
  VpnAndroid._();

  static final VpnAndroid instance = VpnAndroid._();

  static const MethodChannel _channel = MethodChannel('vpn_android');
  static const EventChannel _stageChannel = EventChannel('vpn_android/stage');
  static const EventChannel _logChannel = EventChannel('vpn_android/logs');

  Stream<dynamic>? _stageStream;
  Stream<String>? _logStream;

  Stream<dynamic> get stageEvents {
    _stageStream ??= _stageChannel.receiveBroadcastStream();
    return _stageStream!;
  }

  Stream<String> get logEvents {
    _logStream ??=
        _logChannel.receiveBroadcastStream().map((event) => event.toString());
    return _logStream!;
  }

  Future<bool> requestVpnPermission() async {
    final granted = await _channel.invokeMethod<bool>('requestVpnPermission');
    return granted ?? false;
  }

  Future<List<VpnProfile>> listProfiles() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('listProfiles');
    return (raw ?? const [])
        .map((e) => VpnProfile.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<VpnProfile?> getProfile(String id) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'getProfile',
      {'id': id},
    );
    if (raw == null) return null;
    return VpnProfile.fromMap(raw);
  }

  Future<VpnProfile> importProfile({
    required String name,
    required String ovpnConfig,
    String? username,
    String? password,
    AppFilterMode appFilterMode = AppFilterMode.all,
    List<String> packageNames = const [],
  }) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'importProfile',
      {
        'name': name,
        'ovpnConfig': ovpnConfig,
        'username': username,
        'password': password,
        'appFilterMode': appFilterMode.wire,
        'packageNames': packageNames,
      },
    );
    return VpnProfile.fromMap(raw!);
  }

  Future<VpnProfile> updateProfile(VpnProfile profile) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'updateProfile',
      profile.toMap(),
    );
    return VpnProfile.fromMap(raw!);
  }

  Future<bool> deleteProfile(String id) async {
    final ok = await _channel.invokeMethod<bool>('deleteProfile', {'id': id});
    return ok ?? false;
  }

  Future<VpnProfile?> setDefaultProfile(String id) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setDefaultProfile',
      {'id': id},
    );
    if (raw == null) return null;
    return VpnProfile.fromMap(raw);
  }

  Future<void> setSelectedProfile(String? id) async {
    await _channel.invokeMethod('setSelectedProfile', {'id': id});
  }

  Future<String?> getSelectedProfileId() async {
    return _channel.invokeMethod<String>('getSelectedProfileId');
  }

  Future<VpnProfile> updateAppFilter({
    required String id,
    required AppFilterMode appFilterMode,
    required List<String> packageNames,
  }) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'updateAppFilter',
      {
        'id': id,
        'appFilterMode': appFilterMode.wire,
        'packageNames': packageNames,
      },
    );
    return VpnProfile.fromMap(raw!);
  }

  Future<List<InstalledApp>> listInstalledApps({
    bool includeIcons = false,
  }) async {
    final raw = await _channel.invokeMethod<List<dynamic>>(
      'listInstalledApps',
      {'includeIcons': includeIcons},
    );
    return (raw ?? const [])
        .map((e) => InstalledApp.fromMap(Map<dynamic, dynamic>.from(e as Map)))
        .toList();
  }

  Future<VpnStatusSnapshot> connect({String? profileId}) async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'connect',
      {'profileId': profileId},
    );
    return VpnStatusSnapshot.fromMap(raw ?? const {});
  }

  Future<void> disconnect() async {
    await _channel.invokeMethod('disconnect');
  }

  Future<VpnStatusSnapshot> status() async {
    final raw = await _channel.invokeMethod<Map<dynamic, dynamic>>('status');
    return VpnStatusSnapshot.fromMap(raw ?? const {});
  }

  Future<List<String>> getLogs({int limit = 500}) async {
    final raw =
        await _channel.invokeMethod<List<dynamic>>('getLogs', {'limit': limit});
    return (raw ?? const []).map((e) => e.toString()).toList();
  }

  Future<void> clearLogs() async {
    await _channel.invokeMethod('clearLogs');
  }
}
