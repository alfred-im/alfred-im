// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/inbox_service.dart';
import 'package:alfred_client/services/message_service.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/services/profile_service.dart';

SupabaseClient createTestSupabaseClient() {
  return SupabaseClient(
    'http://127.0.0.1',
    'test-anon-key',
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
      autoRefreshToken: false,
    ),
  );
}

/// Chiave conversazione come in MessagesController.outboundQueueKey.
String conversationKey({
  required String userId,
  required String peerProfileId,
}) =>
    '$userId|$peerProfileId';

class FakeMessageService extends MessageService {
  FakeMessageService(this._clientForTest) : super(_clientForTest);

  final SupabaseClient _clientForTest;

  final Map<String, List<ChatMessage>> messagesByConversation = {};
  final Map<String, List<ChatMessage>> ownerMessagesByUserId = {};
  final Map<String, void Function(ChatMessage message)> _realtimeHandlers = {};
  final Map<String, void Function(ChatMessage message)> _ownerRealtimeHandlers = {};

  @override
  Future<List<ChatMessage>> fetchPeerMessages({
    required String peerProfileId,
    required String currentUserId,
    int limit = 100,
  }) async {
    return List<ChatMessage>.from(
      messagesByConversation[conversationKey(
            userId: currentUserId,
            peerProfileId: peerProfileId,
          )] ??
          const [],
    );
  }

  @override
  RealtimeChannel subscribeToPeerMessages({
    required String currentUserId,
    required String peerProfileId,
    required void Function(ChatMessage message) onMessage,
  }) {
    _realtimeHandlers[conversationKey(
      userId: currentUserId,
      peerProfileId: peerProfileId,
    )] = onMessage;
    return _clientForTest
        .channel('test-$currentUserId-$peerProfileId')
        .subscribe();
  }

  void emitRealtimeMessage({
    required String userId,
    required String peerProfileId,
    required ChatMessage message,
  }) {
    _realtimeHandlers[conversationKey(
      userId: userId,
      peerProfileId: peerProfileId,
    )]?.call(message);
  }

  final imageProfileSends = <Map<String, Object?>>[];
  final videoProfileSends = <Map<String, Object?>>[];
  final imageBroadcasts = <Map<String, Object?>>[];
  final videoBroadcasts = <Map<String, Object?>>[];

  @override
  Future<ChatMessage> sendImageToProfile({
    required String recipientProfileId,
    required String mediaUrl,
    required String mediaMime,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) async {
    imageProfileSends.add({
      'recipientProfileId': recipientProfileId,
      'mediaUrl': mediaUrl,
      'mediaMime': mediaMime,
      'mediaSizeBytes': mediaSizeBytes,
      'clientMessageId': clientMessageId,
      'body': body,
    });
    return _mediaMessage(
      clientMessageId: clientMessageId,
      currentUserId: currentUserId,
      contentType: MessageContentType.image,
      mediaUrl: mediaUrl,
      mediaMime: mediaMime,
      body: body,
    );
  }

  @override
  Future<ChatMessage> sendVideoToProfile({
    required String recipientProfileId,
    required String mediaUrl,
    required String mediaMime,
    required int durationSeconds,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) async {
    videoProfileSends.add({
      'recipientProfileId': recipientProfileId,
      'mediaUrl': mediaUrl,
      'mediaMime': mediaMime,
      'durationSeconds': durationSeconds,
      'mediaSizeBytes': mediaSizeBytes,
      'clientMessageId': clientMessageId,
      'body': body,
    });
    return _mediaMessage(
      clientMessageId: clientMessageId,
      currentUserId: currentUserId,
      contentType: MessageContentType.video,
      mediaUrl: mediaUrl,
      mediaMime: mediaMime,
      durationSeconds: durationSeconds,
      body: body,
    );
  }

  @override
  Future<ChatMessage> broadcastImageToAllowlist({
    required String mediaUrl,
    required String mediaMime,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) async {
    imageBroadcasts.add({
      'mediaUrl': mediaUrl,
      'mediaMime': mediaMime,
      'mediaSizeBytes': mediaSizeBytes,
      'clientMessageId': clientMessageId,
      'body': body,
    });
    return _mediaMessage(
      clientMessageId: clientMessageId,
      currentUserId: currentUserId,
      contentType: MessageContentType.image,
      mediaUrl: mediaUrl,
      mediaMime: mediaMime,
      body: body,
    );
  }

  @override
  Future<ChatMessage> broadcastVideoToAllowlist({
    required String mediaUrl,
    required String mediaMime,
    required int durationSeconds,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) async {
    videoBroadcasts.add({
      'mediaUrl': mediaUrl,
      'mediaMime': mediaMime,
      'durationSeconds': durationSeconds,
      'mediaSizeBytes': mediaSizeBytes,
      'clientMessageId': clientMessageId,
      'body': body,
    });
    return _mediaMessage(
      clientMessageId: clientMessageId,
      currentUserId: currentUserId,
      contentType: MessageContentType.video,
      mediaUrl: mediaUrl,
      mediaMime: mediaMime,
      durationSeconds: durationSeconds,
      body: body,
    );
  }

  ChatMessage _mediaMessage({
    required String clientMessageId,
    required String currentUserId,
    required MessageContentType contentType,
    required String mediaUrl,
    String? mediaMime,
    int? durationSeconds,
    String body = '',
  }) {
    return ChatMessage(
      id: 'server-$clientMessageId',
      body: body,
      timeLabel: '12:00',
      isMine: true,
      status: MessageStatus.sent,
      createdAt: DateTime.utc(2026, 7, 14, 12),
      clientMessageId: clientMessageId,
      senderId: currentUserId,
      contentType: contentType,
      mediaUrl: mediaUrl,
      mediaMime: mediaMime,
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<List<ChatMessage>> fetchOwnerMessages({
    required String currentUserId,
    int limit = 200,
  }) async {
    return List<ChatMessage>.from(
      ownerMessagesByUserId[currentUserId] ?? const [],
    );
  }

  @override
  RealtimeChannel subscribeToOwnerMessages({
    required String currentUserId,
    required void Function(ChatMessage message) onMessage,
  }) {
    _ownerRealtimeHandlers[currentUserId] = onMessage;
    return _clientForTest.channel('test-owner-$currentUserId').subscribe();
  }
}

class FakeProfileService extends ProfileService {
  FakeProfileService(super.client);

  final Map<String, ProfileSummary> profilesById = {};

  @override
  Future<List<ProfileSummary>> fetchSummariesByIds(List<String> ids) async {
    return ids
        .map((id) => profilesById[id])
        .whereType<ProfileSummary>()
        .toList();
  }
}

class FakeInboxService extends InboxService {
  FakeInboxService({this.peers = const []}) : super(createTestSupabaseClient());

  final List<ChatPeer> peers;
  final List<String> markReadCalls = [];
  int fetchInboxCalls = 0;

  @override
  Future<List<ChatPeer>> fetchInbox() async {
    fetchInboxCalls++;
    return List<ChatPeer>.from(peers);
  }

  @override
  Future<void> markRead(String peerProfileId) async {
    markReadCalls.add(peerProfileId);
  }
}

Future<void> waitForMessagesController(MessagesController controller) async {
  for (var i = 0; i < 200 && controller.isLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  // _init continua dopo load (markRead, realtime, notifyListeners).
  await Future<void>.delayed(const Duration(milliseconds: 30));
}
