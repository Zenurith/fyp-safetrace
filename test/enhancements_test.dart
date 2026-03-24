import 'package:flutter_test/flutter_test.dart';
import 'package:fyp_safetrace/data/models/user_model.dart';
import 'package:fyp_safetrace/data/models/community_model.dart';
import 'package:fyp_safetrace/data/models/post_model.dart';
import 'package:fyp_safetrace/data/models/incident_model.dart';

void main() {
  group('UserModel level thresholds (Enhancement: fix all 10 levels)', () {
    test('pointsToNextLevel works for levels 1-6', () {
      final user = UserModel(
        id: '1',
        name: 'Test',
        handle: 'test',
        memberSince: DateTime.now(),
        points: 50,
      );
      // Level 1: needs 100 points to reach level 2
      expect(user.pointsToNextLevel, 100 - 50);
    });

    test('pointsToNextLevel works for levels 7-10', () {
      final user7 = UserModel(
        id: '1',
        name: 'Test',
        handle: 'test',
        memberSince: DateTime.now(),
        points: 2600,
      );
      // Level 7: needs 4000 points to reach level 8
      expect(user7.pointsToNextLevel, 4000 - 2600);

      final user9 = UserModel(
        id: '1',
        name: 'Test',
        handle: 'test',
        memberSince: DateTime.now(),
        points: 7000,
      );
      // Level 9: needs 10000 points to reach level 10
      expect(user9.pointsToNextLevel, 10000 - 7000);
    });

    test('pointsToNextLevel returns 0 at max level', () {
      final user = UserModel(
        id: '1',
        name: 'Test',
        handle: 'test',
        memberSince: DateTime.now(),
        points: 15000,
      );
      expect(user.pointsToNextLevel, 0);
    });

    test('levelProgress works for high levels', () {
      final user = UserModel(
        id: '1',
        name: 'Test',
        handle: 'test',
        memberSince: DateTime.now(),
        points: 3250, // Midway between 2500 (level 7) and 4000 (level 8)
      );
      // Progress = (3250 - 2500) / (4000 - 2500) = 750 / 1500 = 0.5
      expect(user.levelProgress, 0.5);
    });

    test('levelProgress returns 1.0 at max level', () {
      final user = UserModel(
        id: '1',
        name: 'Test',
        handle: 'test',
        memberSince: DateTime.now(),
        points: 15000,
      );
      expect(user.levelProgress, 1.0);
    });
  });

  group('CommunityModel requiresApproval (Enhancement: configurable join)', () {
    test('defaults to false', () {
      final community = CommunityModel(
        id: '1',
        name: 'Test',
        description: 'Test community',
        creatorId: 'user1',
        latitude: 3.0,
        longitude: 101.0,
        radius: 5.0,
        address: 'Test',
        createdAt: DateTime.now(),
      );
      expect(community.requiresApproval, false);
    });

    test('serializes and deserializes requiresApproval', () {
      final community = CommunityModel(
        id: '1',
        name: 'Test',
        description: 'Test community',
        creatorId: 'user1',
        latitude: 3.0,
        longitude: 101.0,
        radius: 5.0,
        address: 'Test',
        requiresApproval: true,
        createdAt: DateTime.now(),
      );

      final map = community.toMap();
      expect(map['requiresApproval'], true);

      // fromMap reads it back (simulate Firestore)
      final restored = CommunityModel.fromMap({
        ...map,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      }, '1');
      expect(restored.requiresApproval, true);
    });

    test('copyWith preserves requiresApproval', () {
      final community = CommunityModel(
        id: '1',
        name: 'Test',
        description: 'Desc',
        creatorId: 'user1',
        latitude: 3.0,
        longitude: 101.0,
        radius: 5.0,
        address: 'Test',
        requiresApproval: true,
        createdAt: DateTime.now(),
      );
      final updated = community.copyWith(name: 'Updated');
      expect(updated.requiresApproval, true);
      expect(updated.name, 'Updated');
    });

    test('copyWith can change requiresApproval', () {
      final community = CommunityModel(
        id: '1',
        name: 'Test',
        description: 'Desc',
        creatorId: 'user1',
        latitude: 3.0,
        longitude: 101.0,
        radius: 5.0,
        address: 'Test',
        requiresApproval: false,
        createdAt: DateTime.now(),
      );
      final updated = community.copyWith(requiresApproval: true);
      expect(updated.requiresApproval, true);
    });
  });

  group('PostModel (Enhancement: community post feed)', () {
    test('creates with default values', () {
      final post = PostModel(
        id: '1',
        authorId: 'user1',
        communityId: 'community1',
        title: 'Hello',
        content: 'World',
        createdAt: DateTime.now(),
      );
      expect(post.visibility, PostVisibility.public);
      expect(post.upvotes, 0);
      expect(post.downvotes, 0);
      expect(post.mediaUrls, isEmpty);
      expect(post.isPublic, true);
      expect(post.isPrivate, false);
    });

    test('voteScore calculates correctly', () {
      final post = PostModel(
        id: '1',
        authorId: 'user1',
        communityId: 'community1',
        title: 'Hello',
        content: 'World',
        upvotes: 10,
        downvotes: 3,
        createdAt: DateTime.now(),
      );
      expect(post.voteScore, 7);
    });

    test('serializes and deserializes correctly', () {
      final post = PostModel(
        id: '1',
        authorId: 'user1',
        communityId: 'community1',
        visibility: PostVisibility.private,
        title: 'Test Title',
        content: 'Test Content',
        upvotes: 5,
        downvotes: 2,
        createdAt: DateTime.now(),
      );

      final map = post.toMap();
      expect(map['authorId'], 'user1');
      expect(map['visibility'], PostVisibility.private.index);
      expect(map['title'], 'Test Title');
    });

    test('timeAgo formats correctly', () {
      final post = PostModel(
        id: '1',
        authorId: 'user1',
        communityId: 'community1',
        title: 'Hello',
        content: 'World',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(post.timeAgo, '3 hours ago');
    });
  });

  group('IncidentModel verification fields (Enhancement: admin verification display)', () {
    test('needsImageReview returns true for low scores', () {
      final incident = IncidentModel(
        id: '1',
        title: 'Test',
        category: IncidentCategory.crime,
        severity: SeverityLevel.high,
        description: 'Test',
        latitude: 3.0,
        longitude: 101.0,
        address: 'Test',
        reportedAt: DateTime.now(),
        reporterId: 'user1',
        imageVerified: false,
        verificationScore: 0.3,
      );
      expect(incident.needsImageReview, true);
    });

    test('needsImageReview returns false for high scores', () {
      final incident = IncidentModel(
        id: '1',
        title: 'Test',
        category: IncidentCategory.crime,
        severity: SeverityLevel.high,
        description: 'Test',
        latitude: 3.0,
        longitude: 101.0,
        address: 'Test',
        reportedAt: DateTime.now(),
        reporterId: 'user1',
        imageVerified: true,
        verificationScore: 0.85,
      );
      expect(incident.needsImageReview, false);
    });

    test('verificationLabel returns correct labels', () {
      expect(
        IncidentModel(
          id: '1', title: '', category: IncidentCategory.crime,
          severity: SeverityLevel.low, description: '', latitude: 0,
          longitude: 0, address: '', reportedAt: DateTime.now(),
          reporterId: '', verificationScore: 0.8,
        ).verificationLabel,
        'High',
      );
      expect(
        IncidentModel(
          id: '1', title: '', category: IncidentCategory.crime,
          severity: SeverityLevel.low, description: '', latitude: 0,
          longitude: 0, address: '', reportedAt: DateTime.now(),
          reporterId: '', verificationScore: 0.5,
        ).verificationLabel,
        'Medium',
      );
      expect(
        IncidentModel(
          id: '1', title: '', category: IncidentCategory.crime,
          severity: SeverityLevel.low, description: '', latitude: 0,
          longitude: 0, address: '', reportedAt: DateTime.now(),
          reporterId: '', verificationScore: 0.2,
        ).verificationLabel,
        'Low',
      );
    });

    test('verificationLabel returns null when no score', () {
      final incident = IncidentModel(
        id: '1',
        title: 'Test',
        category: IncidentCategory.crime,
        severity: SeverityLevel.high,
        description: 'Test',
        latitude: 3.0,
        longitude: 101.0,
        address: 'Test',
        reportedAt: DateTime.now(),
        reporterId: 'user1',
      );
      expect(incident.verificationLabel, null);
    });
  });
}
