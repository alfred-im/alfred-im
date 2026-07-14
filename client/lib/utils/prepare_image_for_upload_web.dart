// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'image_bytes.dart';

@JS('heic2any')
external JSPromise<JSAny?> _heic2any(JSObject options);

Future<Uint8List> convertHeicToJpeg(Uint8List heic) async {
  final parts = <web.BlobPart>[heic.toJS].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: 'image/heic'));
  final options = <String, Object?>{
    'blob': blob,
    'toType': 'image/jpeg',
    'quality': 0.9,
  }.jsify()! as JSObject;

  final result = await _heic2any(options).toDart;
  if (result == null) {
    throw UnsupportedImageFormatException.heicConversionFailed();
  }

  final web.Blob outBlob;
  if (result.isA<JSArray>()) {
    final list = (result as JSArray).toDart;
    if (list.isEmpty) {
      throw UnsupportedImageFormatException.heicConversionFailed();
    }
    outBlob = list.first as web.Blob;
  } else {
    outBlob = result as web.Blob;
  }

  final buffer = await outBlob.arrayBuffer().toDart;
  return Uint8List.view(buffer.toDart);
}

Future<NormalizedImageBytes> prepareImageForUpload(Uint8List bytes) async {
  final format = detectImageFormat(bytes);
  if (format == DetectedImageFormat.heic) {
    final jpeg = await convertHeicToJpeg(bytes);
    if (detectImageFormat(jpeg) != DetectedImageFormat.jpeg) {
      throw UnsupportedImageFormatException.heicConversionFailed();
    }
    return NormalizedImageBytes(
      bytes: jpeg,
      mime: 'image/jpeg',
      extension: 'jpg',
    );
  }
  return normalizeImageBytes(bytes);
}
