import 'package:cloud_firestore/cloud_firestore.dart';

enum MemberStatus { pending, approved, rejected }

enum MemberRole { member, admin }

class CommunityMemberModel {
  final String id;
  final String communityId;
  final String userId;
  final MemberStatus status;
  final MemberRole role;
  final DateTime requestedAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  CommunityMemberModel({
    required this.id,
    required this.communityId,
    required this.userId,
    this.status = MemberStatus.pending,
    this.role = MemberRole.member,
    required this.requestedAt,
    this.approvedAt,
    this.approvedBy,
  });

  bool get isPending => status == MemberStatus.pending;
  bool get isApproved => status == MemberStatus.approved;
  bool get isRejected => status == MemberStatus.rejected;
  bool get isAdmin => role == MemberRole.admin;

  String get statusLabel {
    switch (status) {
      case MemberStatus.pending:
        return 'Pending';
      case MemberStatus.approved:
        return 'Approved';
      case MemberStatus.rejected:
        return 'Rejected';
    }
  }

  String get roleLabel {
    switch (role) {
      case MemberRole.member:
        return 'Member';
      case MemberRole.admin:
        return 'Admin';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(requestedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  Map<String, dynamic> toMap() {
    return {
      'communityId': communityId,
      'userId': userId,
      'status': status.index,
      'role': role.index,
      'requestedAt': Timestamp.fromDate(requestedAt),
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
    };
  }

  factory CommunityMemberModel.fromMap(Map<String, dynamic> map, String id) {
    return CommunityMemberModel(
      id: id,
      communityId: map['communityId'] ?? '',
      userId: map['userId'] ?? '',
      status: MemberStatus.values[map['status'] ?? 0],
      role: MemberRole.values[map['role'] ?? 0],
      requestedAt: map['requestedAt'] is Timestamp
          ? (map['requestedAt'] as Timestamp).toDate()
          : DateTime.now(),
      approvedAt: map['approvedAt'] is Timestamp
          ? (map['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: map['approvedBy'],
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
    );
  }
}
