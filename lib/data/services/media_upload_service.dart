import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

class MediaUploadService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final _uuid = const Uuid();

  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) async {
    return await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
  }

  Future<XFile?> pickVideo({ImageSource source = ImageSource.gallery}) async {
    return await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 2),
    );
  }

  Future<List<XFile>> pickMultipleImages() async {
    return await _picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );
  }

  Future<String?> uploadFile(XFile file, String incidentId) async {
    try {
      debugPrint('MediaUpload: Starting upload for incident $incidentId');
      debugPrint('MediaUpload: File path: ${file.path}');

      final extension = file.path.split('.').last.toLowerCase();
      final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(extension);
      final folder = isVideo ? 'videos' : 'images';
      final fileName = '${_uuid.v4()}.$extension';
      final ref = _storage.ref('incidents/$incidentId/$folder/$fileName');

      // Use readAsBytes() and putData() for cross-platform compatibility
      final bytes = await file.readAsBytes();
      debugPrint('MediaUpload: Read ${bytes.length} bytes, uploading...');

      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(
          contentType: isVideo ? 'video/$extension' : 'image/$extension',
        ),
      );

      final snapshot = await uploadTask;
      final url = await snapshot.ref.getDownloadURL();
      debugPrint('MediaUpload: Success! URL: $url');
      return url;
    } catch (e, stackTrace) {
      debugPrint('MediaUpload: FAILED - $e');
      debugPrint('MediaUpload: Stack trace - $stackTrace');
      return null;
    }
  }

  Future<List<String>> uploadMultipleFiles(
      List<XFile> files, String incidentId) async {
    debugPrint('MediaUpload: Uploading ${files.length} files for incident $incidentId');
    final urls = <String>[];
    for (int i = 0; i < files.length; i++) {
      debugPrint('MediaUpload: Uploading file ${i + 1}/${files.length}');
      final url = await uploadFile(files[i], incidentId);
      if (url != null) {
        urls.add(url);
      }
    }
    debugPrint('MediaUpload: Completed. ${urls.length}/${files.length} successful');
    return urls;
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e) {
      debugPrint('deleteFile error (ignored): $e');
    }
  }

  Future<void> deleteIncidentMedia(String incidentId) async {
    try {
      final imagesRef = _storage.ref('incidents/$incidentId/images');
      final videosRef = _storage.ref('incidents/$incidentId/videos');

      final imagesList = await imagesRef.listAll();
      for (final item in imagesList.items) {
        await item.delete();
      }

      final videosList = await videosRef.listAll();
      for (final item in videosList.items) {
        await item.delete();
      }
    } catch (e) {
      debugPrint('deleteIncidentMedia error (ignored): $e');
    }
  }

  Future<XFile?> pickProfilePhoto({ImageSource source = ImageSource.gallery}) async {
    return await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
  }

  Future<String?> uploadProfilePhoto(String userId, XFile file) async {
    try {
      // Try to delete existing photo first, but don't fail if it doesn't exist
      await deleteProfilePhoto(userId);

      final extension = file.path.split('.').last.toLowerCase();
      final ref = _storage.ref('profile_photos/$userId/profile.$extension');

      // Use readAsBytes() and putData() for cross-platform compatibility
      final bytes = await file.readAsBytes();
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$extension'),
      );

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e, stackTrace) {
      debugPrint('Upload profile photo error: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> deleteProfilePhoto(String userId) async {
    try {
      final folderRef = _storage.ref('profile_photos/$userId');
      final listResult = await folderRef.listAll();
      for (final item in listResult.items) {
        await item.delete();
      }
    } catch (e) {
      // Ignore errors - folder may not exist yet for new users
      debugPrint('deleteProfilePhoto (ignored): $e');
    }
  }
}
