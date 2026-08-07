// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../machines/messaging/conversation_message_store.dart';
import '../machines/messaging/messaging_conversation_state.dart';
import '../machines/messaging/message_actions_machine.dart';
import '../machines/messaging/messaging_coordinator.dart';
import '../machines/messaging/messaging_effects.dart';
import '../models/conversation_scope.dart';
import '../models/message.dart';
import '../models/push_conversation_key.dart';
import '../services/inbox_service.dart';
import '../services/message_media_service.dart';
import '../services/message_service.dart';
import '../services/outbound_message_queue.dart';
import '../groups/group_peer_author_enrichment.dart';
import '../services/profile_service.dart';

class MessagesController extends ChangeNotifier {
  MessagesController({
    required this.scope,
    required this.messageStore,
    required this.userId,
    required this.peerProfileId,
    required this.messageService,
    required this.messageMediaService,
    required this.inboxService,
    this.profileService,
    this.groupPeerAuthorEnrichment,
    this.onMessagesChanged,
    this.hasValidSession,
    this.resolveMessageMediaService,
    this.isScopeCommitted,
    OutboundMessageQueue? outboundQueue,
  }) {
    _state = MessagingConversationState();
    _effects = MessagesControllerEffects(
      state: _state,
      scope: scope,
      messageStore: messageStore,
      userId: userId,
      peerProfileId: peerProfileId,
      messageService: messageService,
      messageMediaService: messageMediaService,
      inboxService: inboxService,
      profileService: profileService,
      groupPeerAuthorEnrichment: groupPeerAuthorEnrichment,
      onMessagesChanged: onMessagesChanged,
      hasValidSession: hasValidSession,
      resolveMessageMediaService: resolveMessageMediaService,
      isScopeCommitted: isScopeCommitted,
      outboundQueue: outboundQueue,
      onChanged: notifyListeners,
    );
    _coordinator = MessagingCoordinator(
      state: _state,
      effects: _effects,
      onChanged: notifyListeners,
    );
    _effects.onSendLifecycleStart = _coordinator.notifySendStarted;
    _effects.onSendLifecycleEnd = _coordinator.notifySendEnded;
    messageStore.addListener(_onMessageStoreChanged);
    unawaited(_coordinator.init());
  }

  void _onMessageStoreChanged() => notifyListeners();

  static const sessionExpiredMessage =
      MessagesControllerEffects.sessionExpiredMessage;

  final ConversationScope scope;
  final ConversationMessageStore messageStore;
  final String userId;
  final String peerProfileId;
  final Future<void> Function()? onMessagesChanged;
  final bool Function()? hasValidSession;
  final MessageMediaService Function()? resolveMessageMediaService;
  final bool Function()? isScopeCommitted;
  final MessageService messageService;
  final MessageMediaService messageMediaService;
  final InboxService inboxService;
  final ProfileService? profileService;
  final GroupPeerAuthorEnrichment? groupPeerAuthorEnrichment;

  late final MessagingConversationState _state;
  late final MessagesControllerEffects _effects;
  late final MessagingCoordinator _coordinator;
  final MessageActionsMachine messageActionsMachine = MessageActionsMachine();
  bool _notifierDisposed = false;

  List<ChatMessage> get messages => _coordinator.messages;
  @visibleForTesting
  set messages(List<ChatMessage> value) {
    messageStore.applyLoadedMessages(
      scope,
      value,
      hasMoreOlder: _coordinator.hasMoreOlder,
    );
  }
  bool get isLoading => _coordinator.isLoading;
  bool get isSending => _coordinator.isSending;
  bool get hasMoreOlder => _coordinator.hasMoreOlder;
  bool get isLoadingOlder => _coordinator.isLoadingOlder;
  @visibleForTesting
  set isSending(bool value) {
    if (value) {
      _coordinator.notifySendStarted();
    } else {
      _coordinator.notifySendEnded(false);
    }
  }
  String? get error => _coordinator.error;

  static String outboundQueueKey({
    required String userId,
    required String peerProfileId,
  }) =>
      PushConversationKey.outboundQueueKey(
        ownerUserId: userId,
        peerProfileId: peerProfileId,
      );

  Future<void> reload() => _coordinator.reload();

  Future<void> loadOlderMessages() => _coordinator.loadOlderMessages();

  Future<void> load() => _coordinator.load();

  Future<void> send(String body) => _coordinator.sendText(body);

  Future<void> sendGif(Uint8List bytes) => _coordinator.sendGif(bytes);

  Future<void> sendImage({
    required Uint8List bytes,
    String? caption,
  }) =>
      _coordinator.sendImage(bytes: bytes, caption: caption);

  Future<void> sendVideoFromPicker({
    required PlatformFile file,
    String? caption,
  }) =>
      _coordinator.sendVideoFromPicker(file: file, caption: caption);

  Future<void> sendVideo({
    required Uint8List bytes,
    required String extension,
    required String mime,
    required int durationSeconds,
    String? caption,
  }) =>
      _coordinator.sendVideo(
        bytes: bytes,
        extension: extension,
        mime: mime,
        durationSeconds: durationSeconds,
        caption: caption,
      );

  Future<void> sendVoice({
    required Uint8List bytes,
    required int durationMs,
  }) =>
      _coordinator.sendVoice(bytes: bytes, durationMs: durationMs);

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
  }) =>
      _coordinator.sendLocation(latitude: latitude, longitude: longitude);

  Future<void> retryMessage(String clientId) =>
      _coordinator.retryMessage(clientId);

  void openMessageActions(ChatMessage message) {
    if (!message.canReact) return;
    messageActionsMachine.send(OpenMessageActions(message.id));
    notifyListeners();
  }

  void closeMessageActions() {
    messageActionsMachine.send(const CloseMessageActions());
    notifyListeners();
  }

  Future<void> applyReaction({
    required ChatMessage message,
    required String emoji,
  }) async {
    final lambda = message.logicalMessageId;
    if (lambda == null) return;
    final mine = message.reactions.where((r) => r.includesMe).toList();
    if (mine.length == 1 &&
        mine.first.emoji == emoji &&
        mine.first.count == 1) {
      await _coordinator.withdrawReaction(logicalMessageId: lambda);
    } else {
      await _coordinator.applyReaction(
        logicalMessageId: lambda,
        emoji: emoji,
      );
    }
    messageActionsMachine.send(const CloseMessageActions());
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_notifierDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    messageStore.removeListener(_onMessageStoreChanged);
    _effects.markDisposed();
    _coordinator.dispose();
    super.dispose();
  }
}
