// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/message.dart';
import '../services/outbound_media_cache.dart';
import '../theme/alfred_colors.dart';
import '../utils/image_bytes.dart';
import 'location_message_content.dart';
import 'message_author_header.dart';
import 'video_message_content.dart';
import 'voice_message_content.dart';

const double _mediaMaxWidth = 240;
const double _mediaMaxHeight = 240;

Widget _mediaLoadingPlaceholder() {
  return const SizedBox(
    width: _mediaMaxWidth,
    height: 120,
    child: Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

Widget _pendingImageConvertingPlaceholder() {
  return SizedBox(
    width: _mediaMaxWidth,
    height: _mediaMaxHeight,
    child: Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(
            color: AlfredColors.panel.withValues(alpha: 0.45),
            child: const SizedBox(
              width: _mediaMaxWidth,
              height: _mediaMaxHeight,
              child: Icon(
                Icons.image_outlined,
                size: 48,
                color: AlfredColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ],
    ),
  );
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.showAuthorLabel = false,
    this.onRetry,
  });

  final ChatMessage message;
  final bool showAuthorLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final showHeader = showAuthorLabel &&
        !isMine &&
        message.authorDisplayName != null &&
        message.authorDisplayName!.isNotEmpty;

    final bubble = Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: message.isMedia
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? AlfredColors.bubbleOutgoing : AlfredColors.panel,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMine ? 12 : 2),
            bottomRight: Radius.circular(isMine ? 2 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (message.isGif) _NetworkImageContent(url: message.mediaUrl!),
            if (message.isImage)
              message.mediaUrl != null && message.mediaUrl!.startsWith('pending://')
                  ? _PendingImageContent(message: message)
                  : _NetworkImageContent(url: message.mediaUrl!),
            if (message.isVideo)
              VideoMessageContent(
                key: ValueKey(message.mediaUrl ?? message.id),
                message: message,
              ),
            if (message.isVoice)
              VoiceMessageContent(message: message, isMine: isMine),
            if (message.isLocation)
              LocationMessageContent(
                latitude: message.latitude!,
                longitude: message.longitude!,
              ),
            if (message.body.isNotEmpty)
              Text(
                message.body,
                style: const TextStyle(
                  color: AlfredColors.textPrimary,
                  fontSize: 14.5,
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.timeLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AlfredColors.textSecondary,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  _Checkmarks(status: message.status),
                ],
              ],
            ),
            if (message.canRetry && onRetry != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Riprova invio'),
                style: TextButton.styleFrom(
                  foregroundColor: AlfredColors.charcoal,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
      );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showHeader) MessageAuthorHeader(message: message),
          bubble,
        ],
      ),
    );
  }
}

class _PendingImageContent extends StatelessWidget {
  const _PendingImageContent({required this.message});

  final ChatMessage message;

  String get _clientId {
    final url = message.mediaUrl;
    if (url != null && url.startsWith('pending://')) {
      return url.substring('pending://'.length);
    }
    return message.clientMessageId ?? message.id;
  }

  @override
  Widget build(BuildContext context) {
    final bytes = OutboundMediaCache.instance.peek(_clientId);
    if (bytes != null) {
      final format = detectImageFormat(bytes);
      if (format == DetectedImageFormat.jpeg ||
          format == DetectedImageFormat.png ||
          format == DetectedImageFormat.webp) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: _mediaMaxWidth,
            height: _mediaMaxHeight,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        );
      }
      if (format == DetectedImageFormat.heic) {
        return _pendingImageConvertingPlaceholder();
      }
    }

    return _pendingImageConvertingPlaceholder();
  }
}

class _NetworkImageContent extends StatelessWidget {
  const _NetworkImageContent({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('pending://')) {
      return _mediaLoadingPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: _mediaMaxWidth,
        height: _mediaMaxHeight,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        webHtmlElementStrategy:
            kIsWeb ? WebHtmlElementStrategy.prefer : WebHtmlElementStrategy.never,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _mediaLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: _mediaMaxWidth,
            height: 120,
            color: AlfredColors.border,
            alignment: Alignment.center,
            child: const Icon(
              Icons.broken_image_outlined,
              color: AlfredColors.textSecondary,
            ),
          );
        },
      ),
    );
  }
}

class _Checkmarks extends StatelessWidget {
  const _Checkmarks({required this.status});

  final MessageStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == MessageStatus.read
        ? AlfredColors.accentBlue
        : AlfredColors.textSecondary;

    if (status == MessageStatus.failed) {
      return Icon(Icons.error_outline, size: 14, color: Colors.red.shade400);
    }

    if (status == MessageStatus.pending) {
      return Icon(Icons.schedule, size: 14, color: color);
    }

    final isDouble =
        status == MessageStatus.delivered || status == MessageStatus.read;

    return Icon(
      isDouble ? Icons.done_all : Icons.done,
      size: 14,
      color: color,
    );
  }
}
