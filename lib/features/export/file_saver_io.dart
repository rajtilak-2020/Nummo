import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> saveAndDownloadFile({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) async {
  final ext = filename.contains('.') ? filename.split('.').last : '';
  final result = await FilePicker.platform.saveFile(
    dialogTitle: 'Save Exported File',
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: ext.isNotEmpty ? [ext] : null,
    bytes: Uint8List.fromList(bytes),
  );

  if (result != null) {
    final file = File(result);
    await file.writeAsBytes(bytes);
  }
}
