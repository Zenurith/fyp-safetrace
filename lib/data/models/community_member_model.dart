import 'package:cloud_firestore/cloud_firestore.dart';

enum MemberStatus { pending, approved, rejected, banned }

enum MemberRole { member, moderator, headModerator, owner }

class CommunityMemberModel {
  final String id;
  final String communityId;
  final String userId;
  final MemberStatus status;
  final MemberRole role;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  /// null = permanent ban; non-null = temporary ban expiry
  final DateTime? bannedUntil;

  CommunityMemberModel({
    required this.id,
    required this.communityId,
    required this.userId,
    this.status = MemberStatus.pending,
    this.role = MemberRole.member,
    required this.requestedAt,
    this.approvedAt,
    this.approvedBy,
    this.bannedUntil,
  });

  bool get isPending => status == MemberStatus.pending;
  bool get isApproved => status == MemberStatus.approved;
  bool get isRejected => status == MemberStatus.rejected;
  bool get isBanned => status == MemberStatus.banned;
  bool get isTempBanned =>
      isBanned && bannedUntil != null && bannedUntil!.isAfter(DateTime.now());
  bool get isPermanentlyBanned => isBanned && bannedUntil == null;

  bool get isOwner => role == MemberRole.owner;
  bool get isHeadModerator => role == MemberRole.headModerator;
  bool get isModerator => role == MemberRole.moderator;
  bool get isStaff => isOwner || isHeadModerator || isModerator;

  String get statusLabel {
    switch (status) {
      case MemberStatus.pending:
        return 'Pending';
      case MemberStatus.approved:
        return 'Approved';
      case MemberStatus.rejected:
        return 'Rejected';
      case MemberStatus.banned:
        return bannedUntil != null ? 'Temp Banned' : 'Banned';
    }
  }

  String get roleLabel {
    switch (role) {
      case MemberRole.owner:
        return 'Owner';
      case MemberRole.headModerator:
        return 'Head Mod';
      case MemberRole.moderator:
        return 'Moderator';
      case MemberRole.member:
        return 'Member';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(requestedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  /// Parses role from either a string name (new) or legacy int index.
  static MemberRole _parseRole(dynamic value) {
    if (value is String) {
      return MemberRole.values.firstWhere(
        (r) => r.name == value,
        orElse: () => MemberRole.member,
      );
    }
    // Legacy int: 0=member, 1=admin → map to owner for creator, otherwise member.
    return (value as int? ?? 0) == 1 ? MemberRole.owner : MemberRole.member;
  }

  Map<String, dynamic> toMap() {
    return {
      'communityId': communityId,
      'userId': userId,
      'status': status.index,
      'role': role.name,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'bannedUntil':
          bannedUntil != null ? Timestamp.fromDate(bannedUntil!) : null,
    };
  }

  factory CommunityMemberModel.fromMap(Map<String, dynamic> map, String id) {
    return CommunityMemberModel(
      id: id,
      communityId: map['communityId'] ?? '',
      userId: map['userId'] ?? '',
      status: MemberStatus.values[map['status'] ?? 0],
      role: _parseRole(map['role']),
      requestedAt: map['requestedAt'] is Timestamp
          ? (map['requestedAt'] as Timestamp).toDate()
          : DateTime.now(),
      approvedAt: map['approvedAt'] is Timestamp
          ? (map['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: map['approvedBy'],
      bannedUntil: map['bannedUntil'] is Timestamp
          ? (map['bannedUntil'] as Timestamp).toDate()
          : null,
    );
  }

  CommunityMemberModel copyWith({
    String? id,
    String? communityId,
    String? userId,
    MemberStatus? status,
    MemberRole? role,
    DateTime? requestedAt,
    DateTime? approvedAt,
    String? approvedBy,
    DateTime? bannedUntil,
  }) {
    return CommunityMemberModel(
      id: id ?? this.id,
      communityId: communityId ?? this.communityId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      role: role ?? this.role,
      requestedAt: requestedAt ?? this.requestedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      bannedUntil: bannedUntil ?? this.bannedUntil,
    );
  }
}
