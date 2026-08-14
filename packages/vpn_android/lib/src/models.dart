enum AppFilterMode {
  all,
  whitelist,
  blacklist;

  static AppFilterMode fromWire(String? value) {
    switch (value) {
      case 'whitelist':
        return AppFilterMode.whitelist;
      case 'blacklist':
        return AppFilterMode.blacklist;
      default:
        return AppFilterMode.all;
    }
  }

  String get wire {
    switch (this) {
      case AppFilterMode.all:
        return 'all';
      case AppFilterMode.whitelist:
        return 'whitelist';
      case AppFilterMode.blacklist:
        return 'blacklist';
    }
  }

  String get label {
    switch (this) {
      case AppFilterMode.all:
        return 'Все приложения';
      case AppFilterMode.whitelist:
        return 'Белый список';
      case AppFilterMode.blacklist:
        return 'Чёрный список';
    }
  }
}

class VpnProfile {
  VpnProfile({
    required this.id,
    required this.name,
    required this.ovpnConfig,
    this.appFilterMode = AppFilterMode.all,
    this.packageNames = const [],
    this.username,
    this.password,
    this.createdAt,
    this.lastUsedAt,
    this.isDefault = false,
  });

  final String id;
  final String name;
  final String ovpnConfig;
  final AppFilterMode appFilterMode;
  final List<String> packageNames;
  final String? username;
  final String? password;
  final int? createdAt;
  final int? lastUsedAt;
  final bool isDefault;

  factory VpnProfile.fromMap(Map<dynamic, dynamic> map) {
    return VpnProfile(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Profile',
      ovpnConfig: map['ovpnConfig'] as String? ?? '',
      appFilterMode: AppFilterMode.fromWire(map['appFilterMode'] as String?),
      packageNames: (map['packageNames'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      username: map['username'] as String?,
      password: map['password'] as String?,
      createdAt: (map['createdAt'] as num?)?.toInt(),
      lastUsedAt: (map['lastUsedAt'] as num?)?.toInt(),
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'ovpnConfig': ovpnConfig,
        'appFilterMode': appFilterMode.wire,
        'packageNames': packageNames,
        'username': username,
        'password': password,
        'createdAt': createdAt,
        'lastUsedAt': lastUsedAt,
        'isDefault': isDefault,
      };

  VpnProfile copyWith({
    String? id,
    String? name,
    String? ovpnConfig,
    AppFilterMode? appFilterMode,
    List<String>? packageNames,
    String? username,
    String? password,
    int? createdAt,
    int? lastUsedAt,
    bool? isDefault,
    bool clearCredentials = false,
  }) {
    return VpnProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      ovpnConfig: ovpnConfig ?? this.ovpnConfig,
      appFilterMode: appFilterMode ?? this.appFilterMode,
      packageNames: packageNames ?? this.packageNames,
      username: clearCredentials ? null : (username ?? this.username),
      password: clearCredentials ? null : (password ?? this.password),
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}

class InstalledApp {
  InstalledApp({
    required this.packageName,
    required this.label,
    this.systemApp = false,
    this.iconBase64,
  });

  final String packageName;
  final String label;
  final bool systemApp;
  final String? iconBase64;

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) {
    return InstalledApp(
      packageName: map['packageName'] as String,
      label: map['label'] as String? ?? map['packageName'] as String,
      systemApp: map['systemApp'] as bool? ?? false,
      iconBase64: map['iconBase64'] as String?,
    );
  }
}

class VpnStatusSnapshot {
  VpnStatusSnapshot({
    required this.stage,
    this.profileId,
    this.rawStatus,
    this.duration,
    this.byteIn,
    this.byteOut,
    this.lastPacketReceive,
  });

  final String stage;
  final String? profileId;
  final String? rawStatus;
  final String? duration;
  final String? byteIn;
  final String? byteOut;
  final String? lastPacketReceive;

  bool get isConnected => stage == 'connected';
  bool get isBusy =>
      stage == 'connecting' ||
      stage == 'authenticating' ||
      stage == 'wait_connection' ||
      stage == 'reconnect' ||
      stage == 'disconnecting';

  factory VpnStatusSnapshot.fromMap(Map<dynamic, dynamic> map) {
    return VpnStatusSnapshot(
      stage: map['stage'] as String? ?? 'disconnected',
      profileId: map['profileId'] as String?,
      rawStatus: map['rawStatus'] as String?,
      duration: map['duration'] as String?,
      byteIn: map['byteIn'] as String?,
      byteOut: map['byteOut'] as String?,
      lastPacketReceive: map['lastPacketReceive'] as String?,
    );
  }

  static VpnStatusSnapshot disconnected() =>
      VpnStatusSnapshot(stage: 'disconnected');
}
