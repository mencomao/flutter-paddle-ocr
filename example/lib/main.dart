import 'dart:typed_data';
import 'dart:ui' as ui show Image;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_paddleocr/flutter_paddleocr.dart';
import 'package:image_picker/image_picker.dart';

import 'mobile_bootstrap.dart'
    if (dart.library.js_interop) 'web_bootstrap.dart';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'flutter_paddleocr example',
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF3B85F5),
      useMaterial3: true,
    ),
    home: const _HomePage(),
  );
}

class _HomePage extends StatefulWidget {
  const _HomePage();
  @override
  State<_HomePage> createState() => _HomePageState();
}

enum _Phase { loading, ready, running, error }

class _HomePageState extends State<_HomePage> {
  PaddleOcr? _ocr;
  _Phase _phase = _Phase.loading;
  String _status = 'Loading models...';
  _Output? _output;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _ocr?.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    try {
      final source = await prepareModelSource(
        onStatus: (s) => setState(() => _status = s),
      );
      setState(() => _status = 'Initializing OCR engine...');
      _ocr = await PaddleOcr.create(source: source);
      setState(() {
        _phase = _Phase.ready;
        _status = kIsWeb
            ? 'Ready — pick an image to run OCR (PP-OCRv5 via paddleocr-js)'
            : 'Ready — pick an image to run OCR';
      });
    } catch (e, st) {
      setState(() {
        _phase = _Phase.error;
        _status = 'Setup failed: $e\n$st';
      });
    }
  }

  Future<void> _pickAndRecognize() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _runOcr(await picked.readAsBytes());
  }

  Future<void> _runSample() async {
    final data = await rootBundle.load('assets/samples/sample.jpg');
    // Honour ByteData offset/length — Flutter Web sometimes returns a view
    // into a larger buffer, so a bare `data.buffer.asUint8List()` would hand
    // the decoder garbage bytes.
    await _runOcr(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  Future<void> _runOcr(Uint8List bytes) async {
    final ocr = _ocr;
    if (ocr == null || _phase == _Phase.running) return;
    setState(() {
      _phase = _Phase.running;
      _status = 'Running OCR...';
      _output = null;
    });
    try {
      final sw = Stopwatch()..start();
      // Kick off the UI decode alongside native inference (100-400 ms saved).
      final decodeFuture = decodeImageFromList(bytes);
      final results = await ocr.recognize(bytes, runClassification: !kIsWeb);
      sw.stop();
      final image = await decodeFuture;
      setState(() {
        _phase = _Phase.ready;
        _output = _Output(image: image, results: results);
        _status =
            'Found ${results.length} regions in ${sw.elapsedMilliseconds} ms';
      });
    } catch (e) {
      setState(() {
        _phase = _Phase.ready;
        _status = 'Recognition failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRun = _phase == _Phase.ready;
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_paddleocr')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _fab(
            'sample',
            Icons.auto_awesome,
            'Run sample',
            canRun ? _runSample : null,
          ),
          const SizedBox(height: 12),
          _fab(
            'pick',
            Icons.photo_library,
            'Pick image',
            canRun ? _pickAndRecognize : null,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_status, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (_output != null) ...[
            Expanded(
              flex: 2,
              child: InteractiveViewer(
                child: _ImageWithBoxes(output: _output!),
              ),
            ),
            if (_output!.results.isNotEmpty)
              Expanded(
                flex: 1,
                child: ListView.separated(
                  itemCount: _output!.results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _output!.results[i];
                    return ListTile(
                      dense: true,
                      title: Text(r.text),
                      subtitle: Text('conf=${r.confidence.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _fab(
    String tag,
    IconData icon,
    String label,
    VoidCallback? onPressed,
  ) => FloatingActionButton.extended(
    heroTag: tag,
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
  );
}

class _Output {
  const _Output({required this.image, required this.results});
  final ui.Image image;
  final List<OcrResult> results;
}

class _ImageWithBoxes extends StatelessWidget {
  const _ImageWithBoxes({required this.output});
  final _Output output;

  @override
  Widget build(BuildContext context) {
    final w = output.image.width.toDouble();
    final h = output.image.height.toDouble();
    // RawImage draws the already-decoded ui.Image directly, avoiding
    // ImageProvider + decode work on every rebuild that Image.memory would do.
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            RawImage(image: output.image, width: w, height: h),
            CustomPaint(size: Size(w, h), painter: _BoxPainter(output.results)),
          ],
        ),
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.results);
  final List<OcrResult> results;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF3B85F5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = const Color(0x333B85F5)
      ..style = PaintingStyle.fill;
    for (final r in results) {
      if (r.points.length < 2) continue;
      final path = Path()..moveTo(r.points.first.dx, r.points.first.dy);
      for (final p in r.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) => oldDelegate.results != results;
}
