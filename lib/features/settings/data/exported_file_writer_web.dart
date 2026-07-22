import 'package:file_picker/file_picker.dart';

import '../domain/data_file_gateway.dart';

Future<void> writeExportedFile(ExportedDataFile file) async {
  await FilePicker.platform.saveFile(fileName: file.name, bytes: file.bytes);
}
