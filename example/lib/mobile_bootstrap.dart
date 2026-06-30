import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_paddleocr/flutter_paddleocr.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// Same PP-OCRv5 mobile ONNX assets that paddleocr-js uses for the web backend.
const _detArchiveUrl =
    'https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/PP-OCRv5_mobile_det_onnx_infer.tar';
const _recArchiveUrl =
    'https://paddle-model-ecology.bj.bcebos.com/paddlex/official_inference_model/paddle3.0.0/PP-OCRv5_mobile_rec_onnx_infer.tar';

Future<ModelSource> prepareModelSource({
  required void Function(String) onStatus,
}) async {
  final dir = await getApplicationSupportDirectory();
  final modelsDir = Directory('${dir.path}/paddle_ocr')
    ..createSync(recursive: true);

  final det = File('${modelsDir.path}/PP-OCRv5_mobile_det.onnx');
  final rec = File('${modelsDir.path}/PP-OCRv5_mobile_rec.onnx');
  final dict = File('${modelsDir.path}/ppocr_keys_v5_utf8.txt');

  if (!det.existsSync()) {
    onStatus('Downloading PP-OCRv5 detection model (~5 MB)...');
    await _downloadModel(_detArchiveUrl, det);
  }
  if (!rec.existsSync() || !dict.existsSync()) {
    onStatus('Downloading PP-OCRv5 recognition model (~16 MB)...');
    final recConfig = await _downloadModel(_recArchiveUrl, rec);
    await _writeDictionaryFromConfig(recConfig, dict);
  }

  return ModelSource.filePaths(det: det.path, rec: rec.path, dict: dict.path);
}

Future<String> _downloadModel(String url, File modelFile) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception('HTTP ${response.statusCode} downloading $url');
  }
  String? configText;
  final archive = TarDecoder().decodeBytes(response.bodyBytes);
  for (final entry in archive) {
    if (!entry.isFile) continue;
    final name = entry.name.split('/').last;
    if (name == 'inference.onnx') {
      modelFile
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entry.content as List<int>);
    } else if (name == 'inference.yml') {
      configText = utf8.decode(entry.content as List<int>);
    }
  }
  if (!modelFile.existsSync()) {
    throw Exception('inference.onnx not found in $url');
  }
  return configText ?? '';
}

Future<void> _writeDictionaryFromConfig(
  String configText,
  File dictFile,
) async {
  final chars = <String>[];
  var inCharacterDict = false;
  for (final rawLine in configText.split('\n')) {
    final line = rawLine.endsWith('\r')
        ? rawLine.substring(0, rawLine.length - 1)
        : rawLine;
    if (RegExp(r'^\s*character_dict\s*:\s*$').hasMatch(line)) {
      inCharacterDict = true;
      continue;
    }
    if (!inCharacterDict) continue;
    final itemMatch = RegExp(r'^\s*-\s?(.*)$').firstMatch(line);
    if (itemMatch == null) {
      if (line.trim().isEmpty) continue;
      break;
    }
    chars.add(itemMatch.group(1)!);
  }
  if (chars.isEmpty) {
    throw Exception('character_dict not found in recognition inference.yml');
  }
  await dictFile.writeAsString('${chars.join('\n')}\n', encoding: utf8);
}
