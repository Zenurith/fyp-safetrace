import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<String?> saveExportFile(String filename, List<int> bytes) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (e) {
    return null;
  }
}

Future<void> shareExportFile(String filePath) async {
  await Share.shareXFiles([XFile(filePath)]);
}
