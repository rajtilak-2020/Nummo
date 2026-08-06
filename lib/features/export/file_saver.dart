import 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart'
    if (dart.library.io) 'file_saver_io.dart';

Future<bool> downloadExportFile({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) =>
    saveAndDownloadFile(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
