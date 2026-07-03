import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/alfred_colors.dart';
import 'location_message_content.dart';
import 'voice_message_content.dart';

const double _gifMaxWidth = 240;
const double _gifMaxHeight = 240;

Widget _gifLoadingPlaceholder() {
  return const SizedBox(
    width: _gifMaxWidth,
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

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.onRetry,
  });

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final bubble = Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
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
            if (message.isGif) _GifContent(url: message.mediaUrl!),
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
      ),
    );

    return bubble;
  }
}

class _GifContent extends StatelessWidget {
  const _GifContent({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('pending://')) {
      return _gifLoadingPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: _gifMaxWidth,
        height: _gifMaxHeight,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _gifLoadingPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: _gifMaxWidth,
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
