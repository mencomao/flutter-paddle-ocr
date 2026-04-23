/// How a [PaddleOcr] instance locates its models.
///
/// The native (Android/iOS) backends need on-device paths to `.nb` files plus
/// a character dictionary — use [ModelSource.filePaths]. The web backend uses
/// `@paddleocr/paddleocr-js`, which fetches `.onnx` models from a CDN by
/// language + version — use [ModelSource.bundled].
sealed class ModelSource {
  const ModelSource();

  /// Supply your own `.nb` files + character dictionary.
  ///
  /// Works on Android and iOS. Paths must be absolute on-device paths —
  /// typically obtained by extracting bundled assets into the app's documents
  /// directory, or downloading at first launch.
  const factory ModelSource.filePaths({
    required String det,
    required String rec,
    required String dict,
    String? cls,
  }) = FilePathsModelSource;

  /// Let the backend fetch models itself by language + version.
  ///
  /// **Web only in v0.2** — throws [UnsupportedError] on Android/iOS. Defaults
  /// to the same PP-OCRv5 Chinese models that the paddleocr-js demo uses.
  const factory ModelSource.bundled({
    String lang,
    String version,
  }) = BundledModelSource;
}

class FilePathsModelSource extends ModelSource {
  const FilePathsModelSource({
    required this.det,
    required this.rec,
    required this.dict,
    this.cls,
  });

  final String det;
  final String rec;
  final String dict;
  final String? cls;
}

class BundledModelSource extends ModelSource {
  const BundledModelSource({this.lang = 'ch', this.version = 'PP-OCRv5'});

  final String lang;
  final String version;
}
