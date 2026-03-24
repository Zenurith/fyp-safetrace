import 'package:cloud_firestore/cloud_firestore.dart';

enum VoteType { upvote, downvote }

enum VoteTargetType { incident, post }

class VoteModel {
  final String id;
  final String targetId;
  final VoteTargetType targetType;
  final String voterId;
  final VoteType type;
  final DateTime votedAt;

  VoteModel({
    required this.id,
    required this.targetId,
    required this.targetType,
    required this.voterId,
    required this.type,
    required this.votedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'targetId': targetId,
      'targetType': targetType.index,
      'voterId': voterId,
      'type': type.index,
      'votedAt': Timestamp.fromDate(votedAt),
    };
  }

  factory VoteModel.fromMap(Map<String, dynamic> map, String id) {
    // Backward compat: old documents used 'incidentId' instead of 'targetId'
    final rawTargetType = map['targetType'];
    return VoteModel(
      id: id,
      targetId: map['targetId'] ?? map['incidentId'] ?? '',
      targetType: rawTargetType != null
          ? VoteTargetType.values[rawTargetType as int]
          : VoteTargetType.incident, // old documents are always incident votes
      voterId: map['voterId'] ?? '',
      type: VoteType.values[map['type'] ?? 0],
      votedAt: map['votedAt'] is Timestamp
          ? (map['votedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  VoteModel copyWith({
    String? id,
    String? targetId,
    VoteTargetType? targetType,
    String? voterId,
    VoteType? type,
    DateTime? votedAt,
  }) {
    return VoteModel(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      voterId: voterId ?? this.voterId,
      type: type ?? this.type,
      votedAt: votedAt ?? this.votedAt,
    );
  }
}
