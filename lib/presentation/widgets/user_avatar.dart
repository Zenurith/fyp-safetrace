import 'package:flutter/material.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? borderWidth;
  final Color? borderColor;

  const UserAvatar({
    super.key,
    this.photoUrl,
    required this.initials,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.borderWidth,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.teal;
    final fgColor = foregroundColor ?? Colors.white;

    Widget avatar;
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        backgroundImage: NetworkImage(photoUrl!),
        onBackgroundImageError: (_, __) {},
        child: null,
      );
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: Text(
          initials,
          style: TextStyle(
            fontSize: radius * 0.7,
            fontWeight: FontWeight.bold,
            color: fgColor,
          ),
        ),
      );
    }

    if (borderWidth != null && borderWidth! > 0) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? Colors.amber,
            width: borderWidth!,
          ),
        ),
        child: avatar,
      );
    }

    return avatar;
  }
}
