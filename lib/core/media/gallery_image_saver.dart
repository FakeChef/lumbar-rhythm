import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final galleryImageSaverProvider = Provider<GalleryImageSaver>((ref) {
  return const GalleryImageSaver();
});

class GalleryImageSaveResult {
  const GalleryImageSaveResult({
    required this.saved,
    this.uri,
  });

  final bool saved;
  final String? uri;
}

class GalleryImageSaver {
  const GalleryImageSaver();

  static const _channel = MethodChannel('lumbar_rhythm/gallery');

  Future<GalleryImageSaveResult> savePng({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final result = await _channel.invokeMethod<Map<Object?, Object?>>(
      'savePngToGallery',
      {
        'bytes': bytes,
        'fileName': fileName,
      },
    );

    return GalleryImageSaveResult(
      saved: result?['saved'] == true,
      uri: result?['uri'] as String?,
    );
  }
}
