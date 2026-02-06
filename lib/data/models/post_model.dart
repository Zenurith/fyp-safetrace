import 'package:cloud_firestore/cloud_firestore.dart';

enum PostVisibility { public, private }

class PostModel {
  final String id;
  final String authorId;
  final String communityId;
  final PostVisibility visibility;
  final String title;
  final String content;
  final List<String> mediaUrls;
  final int upvotes;
  final int downvotes;
  final DateTime createdAt;

  PostModel({
    required this.id,
    required this.authorId,
    required this.communityId,
    this.visibility = PostVisibility.public,
    required this.title,
    required this.content,
    this.mediaUrls = const [],
    this.upvotes = 0,
    this.downvotes = 0,
    required this.createdAt,
  });

  int get voteScore => upvotes - downvotes;

  bool get isPublic => visibility == PostVisibility.public;
  bool get isPrivate => visibility == PostVisibility.private;

  String get visibilityLabel {
    switch (visibility) {
      case PostVisibility.public:
        return 'Public';
      case PostVisibility.private:
        return 'Private';
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'communityId': communityId,
      'visibility': visibility.index,
      'title': title,
      'content': content,
      'mediaUrls': mediaUrls,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map, String id) {
    return PostModel(
      id: id,
      authorId: map['authorId'] ?? '',
      communityId: map['communityId'] ?? '',
      visibility: PostVisibility.values[map['visibility'] ?? 0],
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      mediaUrls: List<String>.from(map['mediaUrls'] ?? []),
      upvotes: map['upvotes'] ?? 0,
      downvotes: map['downvotes'] ?? 0,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  PostModel copyWith({
    String? id,
    String? authorId,
    String? communityId,
    PostVisibility? visibility,
    String? title,
    String? content,
    List<String>? mediaUrls,
    int? upvotes,
    int? downvotes,
    DateTime? createdAt,
  }) {
    return PostModel(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      communityId: communityId ?? this.communityId,
      visibility: visibility ?? this.visibility,
      title: title ?? this.title,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
