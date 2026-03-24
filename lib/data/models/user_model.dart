class UserModel {
  final String id;
  final String name;
  final String handle;
  final DateTime memberSince;
  final int reports;
  final int votes;
  final int points;
  final bool isTrusted;
  final String role;
  final String? profilePhotoUrl;
  final bool isBanned;
  final bool isSuspended;
  final DateTime? suspendedUntil;
  final String? banReason;
  final String? fcmToken;
  final double? lastLatitude;
  final double? lastLongitude;
  final Map<String, dynamic>? alertSettings;

  UserModel({
    required this.id,
    required this.name,
    required this.handle,
    required this.memberSince,
    this.reports = 0,
    this.votes = 0,
    this.points = 0,
    this.isTrusted = false,
    this.role = 'user',
    this.profilePhotoUrl,
    this.isBanned = false,
    this.isSuspended = false,
    this.suspendedUntil,
    this.banReason,
    this.fcmToken,
    this.lastLatitude,
    this.lastLongitude,
    this.alertSettings,
  });

  bool get isAdmin => role == 'admin' || role == 'superadmin';

  bool get isSuperAdmin => role == 'superadmin';

  bool get isActivelyBanned => isBanned;

  bool get isActivelySuspended {
    if (!isSuspended) return false;
    if (suspendedUntil == null) return false;
    return DateTime.now().isBefore(suspendedUntil!);
  }

  bool get canAccessApp => !isActivelyBanned && !isActivelySuspended;

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      handle: map['handle'] ?? '',
      memberSince: map['memberSince'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['memberSince'])
          : DateTime.now(),
      reports: map['reports'] ?? 0,
      votes: map['votes'] ?? 0,
      points: map['points'] ?? 0,
      isTrusted: map['isTrusted'] ?? false,
      role: map['role'] ?? 'user',
      profilePhotoUrl: map['profilePhotoUrl'],
      isBanned: map['isBanned'] ?? false,
      isSuspended: map['isSuspended'] ?? false,
      suspendedUntil: map['suspendedUntil'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['suspendedUntil'])
          : null,
      banReason: map['banReason'],
      fcmToken: map['fcmToken'],
      lastLatitude: (map['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (map['lastLongitude'] as num?)?.toDouble(),
      alertSettings: map['alertSettings'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'handle': handle,
      'memberSince': memberSince.millisecondsSinceEpoch,
      'reports': reports,
      'votes': votes,
      'points': points,
      'isTrusted': isTrusted,
      'role': role,
      'profilePhotoUrl': profilePhotoUrl,
      'isBanned': isBanned,
      'isSuspended': isSuspended,
      'suspendedUntil': suspendedUntil?.millisecondsSinceEpoch,
      'banReason': banReason,
      'fcmToken': fcmToken,
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'alertSettings': alertSettings,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? handle,
    DateTime? memberSince,
    int? reports,
    int? votes,
    int? points,
    bool? isTrusted,
    String? role,
    String? profilePhotoUrl,
    bool clearProfilePhoto = false,
    bool? isBanned,
    bool? isSuspended,
    DateTime? suspendedUntil,
    bool clearSuspendedUntil = false,
    String? banReason,
    bool clearBanReason = false,
    String? fcmToken,
    double? lastLatitude,
    double? lastLongitude,
    Map<String, dynamic>? alertSettings,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      memberSince: memberSince ?? this.memberSince,
      reports: reports ?? this.reports,
      votes: votes ?? this.votes,
      points: points ?? this.points,
      isTrusted: isTrusted ?? this.isTrusted,
      role: role ?? this.role,
      profilePhotoUrl: clearProfilePhoto ? null : (profilePhotoUrl ?? this.profilePhotoUrl),
      isBanned: isBanned ?? this.isBanned,
      isSuspended: isSuspended ?? this.isSuspended,
      suspendedUntil: clearSuspendedUntil ? null : (suspendedUntil ?? this.suspendedUntil),
      banReason: clearBanReason ? null : (banReason ?? this.banReason),
      fcmToken: fcmToken ?? this.fcmToken,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      alertSettings: alertSettings ?? this.alertSettings,
    );
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  static const _levelThresholds = [0, 100, 300, 600, 1000, 1500, 2500, 4000, 6000, 10000];
  static const _levelTitles = ['Newcomer', 'Observer', 'Reporter', 'Contributor', 'Guardian', 'Protector', 'Sentinel', 'Champion', 'Hero', 'Legend'];

  int get level {
    for (int i = _levelThresholds.length - 1; i >= 0; i--) {
      if (points >= _levelThresholds[i]) return i + 1;
    }
    return 1;
  }

  String get levelTitle => _levelTitles[(level - 1).clamp(0, _levelTitles.length - 1)];

  int get pointsToNextLevel {
    if (level >= _levelThresholds.length) return 0;
    return _levelThresholds[level] - points;
  }

  double get levelProgress {
    if (level >= _levelThresholds.length) return 1.0;
    final prev = _levelThresholds[level - 1];
    final next = _levelThresholds[level];
    final range = next - prev;
    if (range <= 0) return 1.0;
    return ((points - prev) / range).clamp(0.0, 1.0);
  }
}
