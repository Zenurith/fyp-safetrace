class UserModel {
  final String id;
  final String name;
  final String handle;
  final DateTime memberSince;
  final int reports;
  final int votes;
  final int points;
  final int level;
  final String levelTitle;
  final bool isTrusted;
  final String role;
  final String? profilePhotoUrl;
  final bool isBanned;
  final bool isSuspended;
  final DateTime? suspendedUntil;
  final String? banReason;
  final String? fcmToken;

  UserModel({
    required this.id,
    required this.name,
    required this.handle,
    required this.memberSince,
    this.reports = 0,
    this.votes = 0,
    this.points = 0,
    this.level = 1,
    this.levelTitle = 'Newcomer',
    this.isTrusted = false,
    this.role = 'user',
    this.profilePhotoUrl,
    this.isBanned = false,
    this.isSuspended = false,
    this.suspendedUntil,
    this.banReason,
    this.fcmToken,
  });

  bool get isAdmin => role == 'admin';

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
      level: map['level'] ?? 1,
      levelTitle: map['levelTitle'] ?? 'Newcomer',
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
      'level': level,
      'levelTitle': levelTitle,
      'isTrusted': isTrusted,
      'role': role,
      'profilePhotoUrl': profilePhotoUrl,
      'isBanned': isBanned,
      'isSuspended': isSuspended,
      'suspendedUntil': suspendedUntil?.millisecondsSinceEpoch,
      'banReason': banReason,
      'fcmToken': fcmToken,
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
    int? level,
    String? levelTitle,
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
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      memberSince: memberSince ?? this.memberSince,
      reports: reports ?? this.reports,
      votes: votes ?? this.votes,
      points: points ?? this.points,
      level: level ?? this.level,
      levelTitle: levelTitle ?? this.levelTitle,
      isTrusted: isTrusted ?? this.isTrusted,
      role: role ?? this.role,
      profilePhotoUrl: clearProfilePhoto ? null : (profilePhotoUrl ?? this.profilePhotoUrl),
      isBanned: isBanned ?? this.isBanned,
      isSuspended: isSuspended ?? this.isSuspended,
      suspendedUntil: clearSuspendedUntil ? null : (suspendedUntil ?? this.suspendedUntil),
      banReason: clearBanReason ? null : (banReason ?? this.banReason),
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  int get pointsToNextLevel {
    const thresholds = [0, 100, 300, 600, 1000, 1500];
    if (level < thresholds.length) {
      return thresholds[level] - points;
    }
    return 0;
  }

  double get levelProgress {
    const thresholds = [0, 100, 300, 600, 1000, 1500];
    if (level >= thresholds.length) return 1.0;
    final prev = level > 0 ? thresholds[level - 1] : 0;
    final next = thresholds[level];
    final range = next - prev;
    if (range <= 0) return 1.0;
    return ((points - prev) / range).clamp(0.0, 1.0);
  }
}
