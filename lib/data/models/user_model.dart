class UserModel {
  final String id;
  final String name;
  final String handle;
  final DateTime memberSince;
  final int reports;
  final int votes;
  final int points;
  final int level;
  final String levelTitle;
  final bool isTrusted;

  UserModel({
    required this.id,
    required this.name,
    required this.handle,
    required this.memberSince,
    this.reports = 0,
    this.votes = 0,
    this.points = 0,
    this.level = 1,
    this.levelTitle = 'Newcomer',
    this.isTrusted = false,
  });

  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  int get pointsToNextLevel {
    const thresholds = [0, 100, 300, 600, 1000, 1500];
    if (level < thresholds.length) {
      return thresholds[level] - points;
    }
    return 0;
  }

  double get levelProgress {
    const thresholds = [0, 100, 300, 600, 1000, 1500];
    if (level >= thresholds.length) return 1.0;
    final prev = level > 0 ? thresholds[level - 1] : 0;
    final next = thresholds[level];
    final range = next - prev;
    if (range <= 0) return 1.0;
    return ((points - prev) / range).clamp(0.0, 1.0);
  }
}
