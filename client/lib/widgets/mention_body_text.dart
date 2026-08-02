// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/alfred_colors.dart';
import '../utils/mention_text.dart';

/// Body testo bolla con link `@username` (PROM-MESSAGE-MENTION).
class MentionBodyText extends StatefulWidget {
  const MentionBodyText({
    super.key,
    required this.text,
    required this.isMine,
    this.viewerUsername,
    required this.onMentionTap,
  });

  final String text;
  final bool isMine;
  final String? viewerUsername;
  final void Function(String username) onMentionTap;

  @override
  State<MentionBodyText> createState() => _MentionBodyTextState();
}

class _MentionBodyTextState extends State<MentionBodyText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final baseStyle = const TextStyle(
      color: AlfredColors.textPrimary,
      fontSize: 14.5,
      height: 1.35,
    );
    final linkStyle = baseStyle.copyWith(
      color: AlfredColors.accentBlue,
      decoration: TextDecoration.underline,
      decorationColor: AlfredColors.accentBlue,
    );

    final spans = <InlineSpan>[];
    final matches = findMentionMatches(widget.text);
    var cursor = 0;

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(
            text: widget.text.substring(cursor, match.start),
            style: baseStyle,
          ),
        );
      }

      final link = shouldLinkMention(
        username: match.username,
        isMine: widget.isMine,
        viewerUsername: widget.viewerUsername,
      );

      if (link) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onMentionTap(match.username);
        _recognizers.add(recognizer);
        spans.add(
          TextSpan(
            text: match.fullText,
            style: linkStyle,
            recognizer: recognizer,
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: match.fullText,
            style: baseStyle,
          ),
        );
      }

      cursor = match.end;
    }

    if (cursor < widget.text.length) {
      spans.add(
        TextSpan(
          text: widget.text.substring(cursor),
          style: baseStyle,
        ),
      );
    }

    if (spans.isEmpty) {
      return Text(widget.text, style: baseStyle);
    }

    return Text.rich(TextSpan(children: spans));
  }
}
