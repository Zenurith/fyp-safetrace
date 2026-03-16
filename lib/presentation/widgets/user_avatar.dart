import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class UserAvatar extends StatefulWidget {
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
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _imageError = false;
  bool _imageLoaded = false;

  @override
  void didUpdateWidget(UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      setState(() {
        _imageError = false;
        _imageLoaded = false;
      });
    }
  }

  bool get _hasValidUrl =>
      widget.photoUrl != null && widget.photoUrl!.isNotEmpty;

  bool get _shouldShowImage => _hasValidUrl && !_imageError;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppTheme.primaryDark;
    final fgColor = widget.foregroundColor ?? Colors.white;
    final size = widget.radius * 2;

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: _shouldShowImage
          ? ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Show initials as fallback while loading
                  if (!_imageLoaded)
                    Center(
                      child: Text(
                        widget.initials,
                        style: TextStyle(
                          fontSize: widget.radius * 0.7,
                          fontWeight: FontWeight.bold,
                          color: fgColor,
                        ),
                      ),
                    ),
                  // Network image with proper error handling
                  Image.network(
                    widget.photoUrl!,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        // Image loaded successfully
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && !_imageLoaded) {
                            setState(() => _imageLoaded = true);
                          }
                        });
                        return child;
                      }
                      // Still loading - show nothing (initials are behind)
                      return const SizedBox.shrink();
                    },
                    errorBuilder: (context, error, stackTrace) {
                      // Error loading image - will show initials
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_imageError) {
                          setState(() => _imageError = true);
                        }
                      });
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            )
          : Center(
              child: Text(
                widget.initials,
                style: TextStyle(
                  fontSize: widget.radius * 0.7,
                  fontWeight: FontWeight.bold,
                  color: fgColor,
                ),
              ),
            ),
    );

    if (widget.borderWidth != null && widget.borderWidth! > 0) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.borderColor ?? AppTheme.cardBorder,
            width: widget.borderWidth!,
          ),
        ),
        child: avatar,
      );
    }

    return avatar;
  }
}
