import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String incidentId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String content;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.incidentId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.content,
    required this.createdAt,
  });

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Map<String, dynamic> toMap() {
    return {
      'incidentId': incidentId,
      'authorId': authorId,
      'authorName': authorName,
      'authorPhotoUrl': authorPhotoUrl,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map, String id) {
    return CommentModel(
      id: id,
      incidentId: map['incidentId'] ?? '',
      authorId: map['authorId'] ?? '',
      authorName: map['authorName'] ?? 'Anonymous',
      authorPhotoUrl: map['authorPhotoUrl'],
      content: map['content'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  CommentModel copyWith({
    String? id,
    String? incidentId,
    String? authorId,
    String? authorName,
    String? authorPhotoUrl,
    String? content,
    DateTime? createdAt,
  }) {
    return CommentModel(
      id: id ?? this.id,
      incidentId: incidentId ?? this.incidentId,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
