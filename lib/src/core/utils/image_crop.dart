import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The largest rectangle of [aspectRatio] (width / height) centred in an
/// image of [size].
Rect centerCropRect(Size size, double aspectRatio) {
  assert(aspectRatio > 0);
  var width = size.width;
  var height = width / aspectRatio;
  if (height > size.height) {
    height = size.height;
    width = height * aspectRatio;
  }
  return Rect.fromLTWH((size.width - width) / 2, (size.height - height) / 2, width, height);
}

/// Centre-crops the image in [file] to [aspectRatio], scaling it so its
/// longest side is at most [maxDimension], and writes a PNG into
/// [outputDirectory]. The caller's upload step re-encodes and compresses it.
///
/// Decoding goes through the engine, which applies EXIF orientation, so the
/// crop matches what the user saw in the preview.
Future<File> cropToAspectRatio(
  File file,
  double aspectRatio, {
  required Directory outputDirectory,
  required String fileName,
  int maxDimension = 2048,
}) async {
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  final source = (await codec.getNextFrame()).image;
  codec.dispose();
  try {
    final crop = centerCropRect(Size(source.width.toDouble(), source.height.toDouble()), aspectRatio);
    final scale = math.min(1.0, maxDimension / math.max(crop.width, crop.height));
    final width = math.max(1, (crop.width * scale).round());
    final height = math.max(1, (crop.height * scale).round());

    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawImageRect(
      source,
      crop,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(width, height);
    picture.dispose();
    try {
      final png = await cropped.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw StateError('Could not encode the cropped image');
      final output = File('${outputDirectory.path}/$fileName.png');
      await output.writeAsBytes(png.buffer.asUint8List(), flush: true);
      return output;
    } finally {
      cropped.dispose();
    }
  } finally {
    source.dispose();
  }
}
