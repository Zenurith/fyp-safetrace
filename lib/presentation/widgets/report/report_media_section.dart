import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ReportMediaSection extends StatelessWidget {
  final List<XFile> selectedMedia;
  final int maxMediaFiles;
  final VoidCallback onAddMedia;
  final void Function(int index) onRemoveMedia;

  const ReportMediaSection({
    super.key,
    required this.selectedMedia,
    required this.maxMediaFiles,
    required this.onAddMedia,
    required this.onRemoveMedia,
  });

  bool _isVideo(XFile file) {
    final ext = file.path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    if (selectedMedia.isNotEmpty) {
      return SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: selectedMedia.length + 1,
          itemBuilder: (context, index) {
            if (index == selectedMedia.length) {
              return _AddMediaButton(onTap: onAddMedia);
            }
            final file = selectedMedia[index];
            final isVideo = _isVideo(file);
            return _MediaPreviewItem(
              file: file,
              isVideo: isVideo,
              onRemove: () => onRemoveMedia(index),
            );
          },
        ),
      );
    }

    return GestureDetector(
      onTap: onAddMedia,
      child: Container(
        width: double.infinity,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 32, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              'Add Photo/Video',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreviewItem extends StatelessWidget {
  final XFile file;
  final bool isVideo;
  final VoidCallback onRemove;

  const _MediaPreviewItem({
    required this.file,
    required this.isVideo,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        image: isVideo
            ? null
            : DecorationImage(
                image: FileImage(File(file.path)),
                fit: BoxFit.cover,
              ),
        color: isVideo ? Colors.grey[800] : null,
      ),
      child: Stack(
        children: [
          if (isVideo)
            const Center(
              child: Icon(Icons.videocam, color: Colors.white, size: 32),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMediaButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddMediaButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Icon(Icons.add, size: 32, color: Colors.grey),
      ),
    );
  }
}
