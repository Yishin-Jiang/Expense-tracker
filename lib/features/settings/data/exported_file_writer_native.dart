import 'dart:ui';

import 'package:share_plus/share_plus.dart';

import '../domain/data_file_gateway.dart';

Future<void> writeExportedFile(ExportedDataFile file) async {
  await SharePlus.instance.share(
    ShareParams(
      title: file.name,
      files: [XFile.fromData(file.bytes, mimeType: file.mimeType)],
      fileNameOverrides: [file.name],
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    ),
  );
}
