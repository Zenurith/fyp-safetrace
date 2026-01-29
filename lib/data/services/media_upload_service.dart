import 'package:firebase_storage/firebase_storage.dart';
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
      final extension = file.path.split('.').last.toLowerCase();
      final isVideo = ['mp4', 'mov', 'avi', 'mkv'].contains(extension);
      final folder = isVideo ? 'videos' : 'images';
      final fileName = '${_uuid.v4()}.$extension';
      final ref = _storage.ref('incidents/$incidentId/$folder/$fileName');

      // Use readAsBytes() and putData() for cross-platform compatibility
      final bytes = await file.readAsBytes();
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(
          contentType: isVideo ? 'video/$extension' : 'image/$extension',
        ),
      );

      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> uploadMultipleFiles(
      List<XFile> files, String incidentId) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadFile(file, incidentId);
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }

  Future<void> deleteFile(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {}
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
    } catch (_) {}
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
      print('Upload profile photo error: $e');
      print('Stack trace: $stackTrace');
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
      print('deleteProfilePhoto (ignored): $e');
    }
  }
}
