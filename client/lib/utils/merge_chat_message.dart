// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../models/message.dart';

/// Merges a realtime or RPC row into an existing bubble without dropping media.
///
/// Tick-only updates (delivered/read) may omit `content_type`, `media_url`, etc.
/// Defaulting those to text/empty would hide GIF/photo/video bubbles.
ChatMessage mergeChatMessage({
  required ChatMessage existing,
  required ChatMessage incoming,
}) {
  final incomingHasMedia = incoming.mediaUrl != null && incoming.mediaUrl!.isNotEmpty;
  final incomingHasLocation =
      incoming.latitude != null && incoming.longitude != null;
  final incomingHasRenderableBody = incoming.body.trim().isNotEmpty;
  final incomingHasTypedMedia = incoming.contentType == MessageContentType.gif ||
      incoming.contentType == MessageContentType.image ||
      incoming.contentType == MessageContentType.video ||
      incoming.contentType == MessageContentType.voice ||
      incoming.contentType == MessageContentType.location;
  final incomingHasRenderableContent = incomingHasRenderableBody ||
      incomingHasMedia ||
      incomingHasLocation ||
      incoming.isGif ||
      incoming.isImage ||
      incoming.isVideo ||
      incoming.isVoice ||
      incomingHasTypedMedia;

  if (!incomingHasRenderableContent && existing.hasRenderableContent) {
    return existing.copyWith(
      id: incoming.id,
      status: incoming.status,
      timeLabel: incoming.timeLabel.isNotEmpty ? incoming.timeLabel : existing.timeLabel,
      createdAt: incoming.createdAt ?? existing.createdAt,
      clientMessageId: incoming.clientMessageId ?? existing.clientMessageId,
      deliveredAt: incoming.deliveredAt ?? existing.deliveredAt,
      readAt: incoming.readAt ?? existing.readAt,
      failedAt: incoming.failedAt ?? existing.failedAt,
      isMine: incoming.isMine,
    );
  }

  return incoming.copyWith(
    body: incomingHasRenderableBody ? incoming.body : existing.body,
    contentType: incomingHasRenderableContent
        ? incoming.contentType
        : existing.contentType,
    mediaUrl: incomingHasMedia ? incoming.mediaUrl : existing.mediaUrl,
    durationSeconds: incoming.durationSeconds ?? existing.durationSeconds,
    mediaMime: incoming.mediaMime ?? existing.mediaMime,
    mediaSizeBytes: incoming.mediaSizeBytes ?? existing.mediaSizeBytes,
    latitude: incoming.latitude ?? existing.latitude,
    longitude: incoming.longitude ?? existing.longitude,
    retryPayloadPath: existing.retryPayloadPath ?? incoming.retryPayloadPath,
  );
}
