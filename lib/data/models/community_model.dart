import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class CommunityModel {
  final String id;
  final String name;
  final String description;
  final String creatorId;
  final double latitude;
  final double longitude;
  final double radius; // in kilometers
  final String address;
  final int memberCount;
  final bool isPublic;
  final bool requiresApproval;
  final DateTime createdAt;
  final String? imageUrl;
  final bool isBanned;
  final DateTime? bannedUntil;
  final String? banReason;

  CommunityModel({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.address,
    this.memberCount = 1,
    this.isPublic = true,
    this.requiresApproval = false,
    required this.createdAt,
    this.imageUrl,
    this.isBanned = false,
    this.bannedUntil,
    this.banReason,
  });

  bool get isActivelySuspended =>
      isBanned && (bannedUntil == null || bannedUntil!.isAfter(DateTime.now()));

  bool get isTempBanned => isBanned && bannedUntil != null;
  bool get isPermanentlyBanned => isBanned && bannedUntil == null;

  /// Check if a location is within this community's radius using Haversine formula
  bool isLocationWithinRadius(double lat, double lng) {
    final distance = calculateDistance(lat, lng);
    return distance <= radius;
  }

  /// Calculate distance in kilometers between this community's center and a point
  double calculateDistance(double lat, double lng) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double lat1Rad = _toRadians(latitude);
    final double lat2Rad = _toRadians(lat);
    final double deltaLat = _toRadians(lat - latitude);
    final double deltaLng = _toRadians(lng - longitude);

    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLng / 2) * sin(deltaLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  String get createdFormatted {
    final d = createdAt.day.toString().padLeft(2, '0');
    final m = createdAt.month.toString().padLeft(2, '0');
    return '$d-$m-${createdAt.year}';
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'creatorId': creatorId,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'address': address,
      'memberCount': memberCount,
      'isPublic': isPublic,
      'requiresApproval': requiresApproval,
      'createdAt': Timestamp.fromDate(createdAt),
      'imageUrl': imageUrl,
      'isBanned': isBanned,
      'bannedUntil': bannedUntil != null ? Timestamp.fromDate(bannedUntil!) : null,
      'banReason': banReason,
    };
  }

  factory CommunityModel.fromMap(Map<String, dynamic> map, String id) {
    return CommunityModel(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      creatorId: map['creatorId'] ?? '',
      latitude: (map['latitude'] ?? 0).toDouble(),
      longitude: (map['longitude'] ?? 0).toDouble(),
      radius: (map['radius'] ?? 1).toDouble(),
      address: map['address'] ?? '',
      memberCount: map['memberCount'] ?? 1,
      isPublic: map['isPublic'] ?? true,
      requiresApproval: map['requiresApproval'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      imageUrl: map['imageUrl'],
      isBanned: map['isBanned'] ?? false,
      bannedUntil: map['bannedUntil'] is Timestamp
          ? (map['bannedUntil'] as Timestamp).toDate()
          : null,
      banReason: map['banReason'],
    );
  }

  CommunityModel copyWith({
    String? id,
    String? name,
    String? description,
    String? creatorId,
    double? latitude,
    double? longitude,
    double? radius,
    String? address,
    int? memberCount,
    bool? isPublic,
    bool? requiresApproval,
    DateTime? createdAt,
    String? imageUrl,
    bool? isBanned,
    DateTime? bannedUntil,
    String? banReason,
  }) {
    return CommunityModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      creatorId: creatorId ?? this.creatorId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radius: radius ?? this.radius,
      address: address ?? this.address,
      memberCount: memberCount ?? this.memberCount,
      isPublic: isPublic ?? this.isPublic,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
      isBanned: isBanned ?? this.isBanned,
      bannedUntil: bannedUntil ?? this.bannedUntil,
      banReason: banReason ?? this.banReason,
    );
  }
}
