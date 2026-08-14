import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vpn_android/vpn_android.dart';

final vpnApiProvider = Provider<VpnAndroid>((ref) => VpnAndroid.instance);

final profilesProvider =
    AsyncNotifierProvider<ProfilesNotifier, List<VpnProfile>>(
  ProfilesNotifier.new,
);

class ProfilesNotifier extends AsyncNotifier<List<VpnProfile>> {
  @override
  Future<List<VpnProfile>> build() => VpnAndroid.instance.listProfiles();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await VpnAndroid.instance.listProfiles());
  }

  Future<VpnProfile> importProfile({
    required String name,
    required String ovpnConfig,
    String? username,
    String? password,
  }) async {
    final profile = await VpnAndroid.instance.importProfile(
      name: name,
      ovpnConfig: ovpnConfig,
      username: username,
      password: password,
    );
    await refresh();
    return profile;
  }

  Future<void> updateProfile(VpnProfile profile) async {
    await VpnAndroid.instance.updateProfile(profile);
    await refresh();
  }

  Future<void> delete(String id) async {
    await VpnAndroid.instance.deleteProfile(id);
    await refresh();
  }

  Future<void> setDefault(String id) async {
    await VpnAndroid.instance.setDefaultProfile(id);
    await refresh();
  }
}

final selectedProfileIdProvider =
    AsyncNotifierProvider<SelectedProfileNotifier, String?>(
  SelectedProfileNotifier.new,
);

class SelectedProfileNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => VpnAndroid.instance.getSelectedProfileId();

  Future<void> select(String? id) async {
    await VpnAndroid.instance.setSelectedProfile(id);
    state = AsyncData(id);
  }
}

final connectionProvider =
    NotifierProvider<ConnectionNotifier, VpnStatusSnapshot>(
  ConnectionNotifier.new,
);

class ConnectionNotifier extends Notifier<VpnStatusSnapshot> {
  StreamSubscription<dynamic>? _sub;

  @override
  VpnStatusSnapshot build() {
    _sub?.cancel();
    _sub = VpnAndroid.instance.stageEvents.listen((event) {
      if (event is String) {
        state = VpnStatusSnapshot(
          stage: event,
          profileId: state.profileId,
          duration: state.duration,
          byteIn: state.byteIn,
          byteOut: state.byteOut,
        );
      } else if (event is Map) {
        final map = Map<dynamic, dynamic>.from(event);
        if (map['type'] == 'stats') {
          state = VpnStatusSnapshot(
            stage: state.stage,
            profileId: state.profileId,
            duration: map['duration'] as String?,
            byteIn: map['byteIn'] as String?,
            byteOut: map['byteOut'] as String?,
            lastPacketReceive: map['lastPacketReceive'] as String?,
          );
        } else {
          state = VpnStatusSnapshot.fromMap(map);
        }
      }
    });
    ref.onDispose(() => _sub?.cancel());
    Future.microtask(() async {
      state = await VpnAndroid.instance.status();
    });
    return VpnStatusSnapshot.disconnected();
  }

  Future<void> connect(String? profileId) async {
    state = VpnStatusSnapshot(stage: 'connecting', profileId: profileId);
    try {
      final snap = await VpnAndroid.instance.connect(profileId: profileId);
      state = snap;
    } catch (e) {
      state = VpnStatusSnapshot(stage: 'error', profileId: profileId);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    state = VpnStatusSnapshot(stage: 'disconnecting', profileId: state.profileId);
    await VpnAndroid.instance.disconnect();
    state = VpnStatusSnapshot.disconnected();
  }
}

final logsProvider =
    AsyncNotifierProvider<LogsNotifier, List<String>>(LogsNotifier.new);

class LogsNotifier extends AsyncNotifier<List<String>> {
  StreamSubscription<String>? _sub;

  @override
  Future<List<String>> build() async {
    _sub?.cancel();
    final initial = await VpnAndroid.instance.getLogs();
    _sub = VpnAndroid.instance.logEvents.listen((line) {
      final current = state.valueOrNull ?? initial;
      state = AsyncData([...current, line]);
    });
    ref.onDispose(() => _sub?.cancel());
    return initial;
  }

  Future<void> clear() async {
    await VpnAndroid.instance.clearLogs();
    state = const AsyncData([]);
  }

  Future<void> refresh() async {
    state = AsyncData(await VpnAndroid.instance.getLogs());
  }
}

final installedAppsProvider =
    FutureProvider.family<List<InstalledApp>, bool>((ref, includeIcons) {
  return VpnAndroid.instance.listInstalledApps(includeIcons: includeIcons);
});
