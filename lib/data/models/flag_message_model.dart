import 'package:cloud_firestore/cloud_firestore.dart';

class FlagMessageModel {
  final String id;
  final String flagId;
  final String senderId;
  final String senderName;

  /// 'admin' | 'staff' | 'reporter'
  final String senderRole;
  final String content;
  final DateTime createdAt;
  final List<String> readBy;

  FlagMessageModel({
    required this.id,
    required this.flagId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.createdAt,
    this.readBy = const [],
  });

  bool isReadBy(String userId) => readBy.contains(userId);

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Map<String, dynamic> toMap() => {
        'flagId': flagId,
        'senderId': senderId,
        'senderName': senderName,
        'senderRole': senderRole,
        'content': content,
        'createdAt': Timestamp.fromDate(createdAt),
        'readBy': readBy,
      };

  factory FlagMessageModel.fromMap(Map<String, dynamic> map, String id) =>
      FlagMessageModel(
        id: id,
        flagId: map['flagId'] as String? ?? '',
        senderId: map['senderId'] as String? ?? '',
        senderName: map['senderName'] as String? ?? '',
        senderRole: map['senderRole'] as String? ?? 'reporter',
        content: map['content'] as String? ?? '',
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        readBy: List<String>.from(map['readBy'] ?? []),
      );
}
