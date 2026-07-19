// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/message.dart';
import '../theme/alfred_colors.dart';
import '../utils/conversation_scroll_anchor.dart';
import 'message_bubble.dart';

/// Lista messaggi con aggancio al fondo (stile WhatsApp/Telegram).
class AnchoredMessageList extends StatefulWidget {
  const AnchoredMessageList({
    super.key,
    required this.messages,
    required this.isLoading,
    this.onRetryMessage,
    this.showAuthorLabels = false,
    this.hasMoreOlder = false,
    this.isLoadingOlder = false,
    this.onLoadOlder,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final void Function(String messageId)? onRetryMessage;
  final bool showAuthorLabels;
  final bool hasMoreOlder;
  final bool isLoadingOlder;
  final VoidCallback? onLoadOlder;

  @override
  State<AnchoredMessageList> createState() => _AnchoredMessageListState();
}

class _AnchoredMessageListState extends State<AnchoredMessageList> {
  static const _loadOlderThreshold = 120.0;

  final _scrollController = ScrollController();
  bool _isAttached = true;
  int _pendingBelow = 0;
  int _renderedCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _renderedCount = widget.messages.length;
  }

  @override
  void didUpdateWidget(AnchoredMessageList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isLoading && !widget.isLoading) {
      _renderedCount = widget.messages.length;
      _pendingBelow = 0;
      _isAttached = true;
      _scheduleScrollToBottom(animate: false);
      return;
    }

    final previousCount = _renderedCount;
    final currentCount = widget.messages.length;
    if (currentCount == previousCount) return;

    final prepended = _didPrependMessages(oldWidget.messages, widget.messages);
    if (prepended) {
      _preserveScrollAfterPrepend();
      _renderedCount = currentCount;
      return;
    }

    if (currentCount < previousCount) {
      setState(() {
        _renderedCount = currentCount;
        _pendingBelow = 0;
      });
      return;
    }

    final appended = widget.messages.sublist(previousCount);
    final hasOutgoing = appended.any((message) => message.isMine);
    final shouldScroll = ConversationScrollAnchor.shouldAutoScrollOnAppend(
      wasAttached: _isAttached,
      hasOutgoingInBatch: hasOutgoing,
    );

    _renderedCount = currentCount;

    if (shouldScroll) {
      setState(() {
        _isAttached = true;
        _pendingBelow = 0;
      });
      _scheduleScrollToBottom(animate: hasOutgoing);
      return;
    }

    setState(() {
      _pendingBelow += appended.length;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  bool _didPrependMessages(
    List<ChatMessage> previous,
    List<ChatMessage> current,
  ) {
    if (current.length <= previous.length) return false;
    if (previous.isEmpty || current.isEmpty) return false;
    return previous.last.id == current.last.id &&
        previous.first.id != current.first.id;
  }

  void _preserveScrollAfterPrepend() {
    if (!_scrollController.hasClients) return;
    final oldMaxExtent = _scrollController.position.maxScrollExtent;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final newMaxExtent = _scrollController.position.maxScrollExtent;
      final delta = newMaxExtent - oldMaxExtent;
      if (delta > 0) {
        _scrollController.jumpTo(_scrollController.position.pixels + delta);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final attached = ConversationScrollAnchor.isAttached(position.pixels);

    if (attached != _isAttached) {
      setState(() {
        _isAttached = attached;
        if (attached) _pendingBelow = 0;
      });
    }

    if (!widget.hasMoreOlder ||
        widget.isLoadingOlder ||
        widget.onLoadOlder == null) {
      return;
    }

    final remaining = position.maxScrollExtent - position.pixels;
    if (remaining <= _loadOlderThreshold) {
      widget.onLoadOlder!();
    }
  }

  void _scheduleScrollToBottom({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(animate: animate);
    });
  }

  void _scrollToBottom({required bool animate}) {
    if (!_scrollController.hasClients) return;

    if (animate) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(0);
    }
  }

  void _onJumpTap() {
    _scrollToBottom(animate: true);
    setState(() {
      _isAttached = true;
      _pendingBelow = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: widget.messages.length + (widget.isLoadingOlder ? 1 : 0),
          itemBuilder: (context, index) {
            if (widget.isLoadingOlder &&
                index == widget.messages.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final message =
                widget.messages[widget.messages.length - 1 - index];
            return MessageBubble(
              message: message,
              showAuthorLabel: widget.showAuthorLabels,
              onRetry: message.canRetry && widget.onRetryMessage != null
                  ? () => widget.onRetryMessage!(message.id)
                  : null,
            );
          },
        ),
        if (!_isAttached)
          Padding(
            padding: const EdgeInsets.only(right: 16, bottom: 12),
            child: _JumpToBottomButton(
              pendingCount: _pendingBelow,
              onTap: _onJumpTap,
            ),
          ),
      ],
    );
  }
}

class _JumpToBottomButton extends StatelessWidget {
  const _JumpToBottomButton({
    required this.pendingCount,
    required this.onTap,
  });

  final int pendingCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      shadowColor: Colors.black26,
      color: AlfredColors.panel,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.keyboard_arrow_down,
                color: AlfredColors.textSecondary,
              ),
              if (pendingCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: const BoxDecoration(
                      color: AlfredColors.unreadBadge,
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      pendingCount > 99 ? '99+' : '$pendingCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
