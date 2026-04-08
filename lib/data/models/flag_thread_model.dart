import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FlagThreadModel {
  final String flagId;
  final List<String> participants;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final String lastSenderId;
  final Map<String, int> unreadCounts;
  final DateTime createdAt;
  final DateTime? closedAt;

  FlagThreadModel({
    required this.flagId,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageAt,
    this.lastSenderId = '',
    this.unreadCounts = const {},
    required this.createdAt,
    this.closedAt,
  });

  bool get isClosed => closedAt != null;

  int unreadFor(String userId) => unreadCounts[userId] ?? 0;

  String get formattedTime {
    if (lastMessageAt == null) return '';
    final diff = DateTime.now().difference(lastMessageAt!);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(lastMessageAt!);
  }

  Map<String, dynamic> toMap() => {
        'flagId': flagId,
        'participants': participants,
        'lastMessage': lastMessage,
        'lastMessageAt':
            lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
        'lastSenderId': lastSenderId,
        'unreadCounts': unreadCounts,
        'createdAt': Timestamp.fromDate(createdAt),
        'closedAt': closedAt != null ? Timestamp.fromDate(closedAt!) : null,
      };

  factory FlagThreadModel.fromMap(Map<String, dynamic> map) => FlagThreadModel(
        flagId: map['flagId'] as String? ?? '',
        participants: List<String>.from(map['participants'] ?? []),
        lastMessage: map['lastMessage'] as String? ?? '',
        lastMessageAt: map['lastMessageAt'] is Timestamp
            ? (map['lastMessageAt'] as Timestamp).toDate()
            : null,
        lastSenderId: map['lastSenderId'] as String? ?? '',
        unreadCounts: Map<String, int>.from(
          (map['unreadCounts'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, (v as num).toInt())),
        ),
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        closedAt: map['closedAt'] is Timestamp
            ? (map['closedAt'] as Timestamp).toDate()
            : null,
      );
}
