import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/data_file_gateway.dart';

class PlatformDataFileGateway implements DataFileGateway {
  const PlatformDataFileGateway();

  @override
  Future<void> share(ExportedDataFile file) async {
    await SharePlus.instance.share(
      ShareParams(
        title: file.name,
        files: [XFile.fromData(file.bytes, mimeType: file.mimeType)],
        fileNameOverrides: [file.name],
      ),
    );
  }

  @override
  Future<Uint8List?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.single;
    if (picked.bytes != null) return picked.bytes;
    final path = picked.path;
    if (path == null) return null;
    return File(path).readAsBytes();
  }
}
