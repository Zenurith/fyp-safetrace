import 'package:cloud_firestore/cloud_firestore.dart';

enum VoteType { upvote, downvote }

class VoteModel {
  final String id;
  final String incidentId;
  final String voterId;
  final VoteType type;
  final DateTime votedAt;

  VoteModel({
    required this.id,
    required this.incidentId,
    required this.voterId,
    required this.type,
    required this.votedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'voterId': voterId,
      'type': type.index,
      'votedAt': Timestamp.fromDate(votedAt),
    };
  }

  factory VoteModel.fromMap(Map<String, dynamic> map, String id) {
    return VoteModel(
      id: id,
      incidentId: map['incidentId'] ?? '',
      voterId: map['voterId'] ?? '',
      type: VoteType.values[map['type'] ?? 0],
      votedAt: map['votedAt'] is Timestamp
          ? (map['votedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  VoteModel copyWith({
    String? id,
    String? incidentId,
    String? voterId,
    VoteType? type,
    DateTime? votedAt,
  }) {
    return VoteModel(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      voterId: voterId ?? this.voterId,
      type: type ?? this.type,
      votedAt: votedAt ?? this.votedAt,
    );
  }
}
