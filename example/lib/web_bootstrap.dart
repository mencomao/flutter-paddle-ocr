import 'package:flutter_paddle_ocr_v5/flutter_paddle_ocr_v5.dart';

/// Web build: paddleocr-js fetches its own models based on lang + version,
/// so there's no filesystem work to do up-front.
Future<ModelSource> prepareModelSource({
  required void Function(String) onStatus,
}) async {
  return const ModelSource.bundled(lang: 'ch', version: 'PP-OCRv5');
}
