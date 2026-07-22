import 'dart:typed_data';

class ExportedDataFile {
  const ExportedDataFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;
}

abstract interface class DataFileGateway {
  Future<void> share(ExportedDataFile file);

  Future<Uint8List?> pickBackup();
}
