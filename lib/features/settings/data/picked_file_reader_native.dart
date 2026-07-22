import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readPickedFilePath(String path) => File(path).readAsBytes();
