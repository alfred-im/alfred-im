// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:alfred_client/services/message_media_service.dart';

import 'fake_messaging_services.dart';

class FakeMessageMediaService extends MessageMediaService {
  FakeMessageMediaService() : super(createTestSupabaseClient());

  Future<void>? uploadImageGate;
  Future<void>? uploadVideoGate;

  final imageUploads = <_ImageUploadCall>[];
  final videoUploads = <_VideoUploadCall>[];

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    required String userId,
    required String extension,
    required String contentType,
  }) async {
    final gate = uploadImageGate;
    if (gate != null) {
      await gate;
    }
    imageUploads.add(
      _ImageUploadCall(
        bytes: bytes,
        userId: userId,
        extension: extension,
        contentType: contentType,
      ),
    );
    return 'https://storage.example/$userId/upload.$extension';
  }

  @override
  Future<String> uploadVideo({
    required Uint8List bytes,
    required String userId,
    required String extension,
    required String contentType,
  }) async {
    final gate = uploadVideoGate;
    if (gate != null) {
      await gate;
    }
    videoUploads.add(
      _VideoUploadCall(
        bytes: bytes,
        userId: userId,
        extension: extension,
        contentType: contentType,
      ),
    );
    return 'https://storage.example/$userId/upload.$extension';
  }
}

class _ImageUploadCall {
  const _ImageUploadCall({
    required this.bytes,
    required this.userId,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String userId;
  final String extension;
  final String contentType;
}

class _VideoUploadCall {
  const _VideoUploadCall({
    required this.bytes,
    required this.userId,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String userId;
  final String extension;
  final String contentType;
}
