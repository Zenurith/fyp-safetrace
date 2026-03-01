import 'dart:io';
import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class PhotoGalleryViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const PhotoGalleryViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
  });

  static void show(BuildContext context, List<String> imageUrls, {int initialIndex = 0}) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return PhotoGalleryViewer(
            imageUrls: imageUrls,
            initialIndex: initialIndex,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  State<PhotoGalleryViewer> createState() => _PhotoGalleryViewerState();
}

class _PhotoGalleryViewerState extends State<PhotoGalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isLocalFile(String url) {
    return url.startsWith('/') || url.startsWith('file://');
  }

  bool _isVideo(String url) {
    return url.contains('/videos/') ||
        url.toLowerCase().endsWith('.mp4') ||
        url.toLowerCase().endsWith('.mov');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismiss on tap background
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),

          // Image PageView
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              final url = widget.imageUrls[index];
              final isVideo = _isVideo(url);
              final isLocal = _isLocalFile(url);

              return Center(
                child: isVideo
                    ? _buildVideoPlaceholder()
                    : InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: isLocal
                            ? Image.file(
                                File(url.replaceFirst('file://', '')),
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildErrorWidget('Failed to load image');
                                },
                              )
                            : Image.network(
                                url,
                                fit: BoxFit.contain,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                      color: Colors.white,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildErrorWidget('Failed to load image');
                                },
                              ),
                      ),
              );
            },
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Counter
          if (widget.imageUrls.length > 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),

          // Dots indicator
          if (widget.imageUrls.length > 1)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 32,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.imageUrls.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _currentIndex ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == _currentIndex
                          ? AppTheme.primaryRed
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

          // Navigation arrows for desktop
          if (widget.imageUrls.length > 1) ...[
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavigationArrow(
                  icon: Icons.chevron_left,
                  onTap: _currentIndex > 0
                      ? () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
              ),
            ),
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: _NavigationArrow(
                  icon: Icons.chevron_right,
                  onTap: _currentIndex < widget.imageUrls.length - 1
                      ? () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam, color: Colors.white, size: 48),
          SizedBox(height: 8),
          Text(
            'Video playback not available',
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image, color: Colors.white54, size: 48),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}

class _NavigationArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _NavigationArrow({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.black54 : Colors.black26,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isEnabled ? Colors.white : Colors.white38,
          size: 28,
        ),
      ),
    );
  }
}
