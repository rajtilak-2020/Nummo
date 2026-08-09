import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../core/security/app_lock_guard.dart';

Future<bool> saveAndDownloadFile({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) async {
  final ext = filename.contains('.') ? filename.split('.').last : '';
  final result = await AppLockGuard.runWithPickerGuard(
    () => FilePicker.platform.saveFile(
      dialogTitle: 'Save Exported File',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ext.isNotEmpty ? [ext] : null,
      bytes: Uint8List.fromList(bytes),
    ),
  );

  return result != null;
}
