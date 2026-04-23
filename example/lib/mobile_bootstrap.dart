import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_paddle_ocr/flutter_paddle_ocr.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// PP-OCRv2 slim mobile bundle (det_db.nb + rec_crnn.nb + cls.nb) + Chinese dict.
// Mirrors PaddleOCR/deploy/android_demo/app/build.gradle.
const _modelArchiveUrl = 'https://paddleocr.bj.bcebos.com/PP-OCRv2/lite/ch_PP-OCRv2.tar.gz';
const _dictArchiveUrl = 'https://paddleocr.bj.bcebos.com/dygraph_v2.0/lite/ch_dict.tar.gz';

Future<ModelSource> prepareModelSource({
  required void Function(String) onStatus,
}) async {
  final dir = await getApplicationSupportDirectory();
  final modelsDir = Directory('${dir.path}/paddle_ocr')..createSync(recursive: true);

  final det = File('${modelsDir.path}/det_db.nb');
  final rec = File('${modelsDir.path}/rec_crnn.nb');
  final cls = File('${modelsDir.path}/cls.nb');
  final dict = File('${modelsDir.path}/ppocr_keys_v1.txt');

  if (!det.existsSync() || !rec.existsSync() || !cls.existsSync()) {
    onStatus('Downloading PP-OCRv2 models (~7 MB)...');
    await _downloadAndExtract(_modelArchiveUrl, modelsDir);
  }
  if (!dict.existsSync()) {
    onStatus('Downloading Chinese dictionary...');
    await _downloadAndExtract(_dictArchiveUrl, modelsDir);
  }

  return ModelSource.filePaths(
    det: det.path,
    rec: rec.path,
    cls: cls.path,
    dict: dict.path,
  );
}

Future<void> _downloadAndExtract(String url, Directory into) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode} downloading $url');
  }
  final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(response.bodyBytes));
  for (final entry in archive) {
    if (!entry.isFile) continue;
    final slash = entry.name.indexOf('/');
    final name = slash >= 0 ? entry.name.substring(slash + 1) : entry.name;
    if (name.isEmpty) continue;
    File('${into.path}/$name')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(entry.content as List<int>);
  }
}
