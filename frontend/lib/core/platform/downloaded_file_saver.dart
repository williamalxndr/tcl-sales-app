import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

class DownloadedFileSaver {
  const DownloadedFileSaver();

  Future<void> save({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) async {
    final dot = fileName.lastIndexOf('.');
    final name = dot > 0 ? fileName.substring(0, dot) : fileName;
    final extension = dot > 0 ? fileName.substring(dot + 1) : '';
    await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: extension,
      mimeType: MimeType.custom,
      customMimeType: contentType,
    );
  }
}
