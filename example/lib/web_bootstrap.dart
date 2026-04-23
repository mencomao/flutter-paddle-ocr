import 'package:flutter_paddle_ocr/flutter_paddle_ocr.dart';

/// Web build: paddleocr-js fetches its own models based on lang + version,
/// so there's no filesystem work to do up-front.
Future<ModelSource> prepareModelSource({
  required void Function(String) onStatus,
}) async {
  return const ModelSource.bundled(lang: 'ch', version: 'PP-OCRv5');
}
