// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:alfred_client/machines/messaging/conversation_message_store.dart';
import 'package:alfred_client/models/chat_peer.dart';
import 'package:alfred_client/models/conversation_scope.dart';
import 'package:alfred_client/models/message.dart';
import 'package:alfred_client/models/profile_summary.dart';
import 'package:alfred_client/providers/messages_controller.dart';
import 'package:alfred_client/services/group_archive_service.dart';
import 'package:alfred_client/services/inbox_service.dart';
import 'package:alfred_client/services/peer_message_service.dart';
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

/// JWT in-memory per test composition / wiring con [hasValidJwt].
Future<void> installTestAuthSession(
  SupabaseClient client, {
  required String userId,
  String accessToken = 'test-access-token',
  String refreshToken = 'test-refresh-token',
}) async {
  final sessionJson = jsonEncode({
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': {
      'id': userId,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{},
      'user_metadata': <String, dynamic>{},
      'created_at': DateTime.now().toUtc().toIso8601String(),
    },
  });
  await client.auth.recoverSession(sessionJson);
}

/// Chiave conversazione come in MessagesController.outboundQueueKey.
String conversationKey({
  required String userId,
  required String peerProfileId,
}) =>
    '$userId|$peerProfileId';

/// Facade test che compone [FakePeerMessageService] e [FakeGroupArchiveService].
class FakeMessageService {
  FakeMessageService(
    SupabaseClient client, {
    FakePeerMessageService Function(FakeMessageService host)? buildPeer,
  }) : _client = client {
    peerMessages = buildPeer?.call(this) ?? FakePeerMessageService(this);
    groupArchive = FakeGroupArchiveService(this, client);
  }

  final SupabaseClient _client;

  SupabaseClient get client => _client;

  late final FakePeerMessageService peerMessages;
  late final FakeGroupArchiveService groupArchive;

  final Map<String, List<ChatMessage>> messagesByConversation = {};
  final Map<String, List<ChatMessage>> archiveMessagesByUserId = {};

  List<String> get sentBodies => peerMessages.sentBodies;

  List<String> get broadcastBodies => groupArchive.broadcastBodies;

  List<Map<String, Object?>> get gifProfileSends => peerMessages.gifProfileSends;

  bool get sendShouldFail => peerMessages.sendShouldFail;

  set sendShouldFail(bool value) => peerMessages.sendShouldFail = value;

  List<Map<String, Object?>> get imageProfileSends => peerMessages.imageProfileSends;

  List<Map<String, Object?>> get videoProfileSends => peerMessages.videoProfileSends;

  List<Map<String, Object?>> get imageBroadcasts => groupArchive.imageBroadcasts;

  List<Map<String, Object?>> get videoBroadcasts => groupArchive.videoBroadcasts;

  void emitRealtimeMessage({
    required String userId,
    required String peerProfileId,
    required ChatMessage message,
  }) =>
      peerMessages.emitRealtimeMessage(
        userId: userId,
        peerProfileId: peerProfileId,
        message: message,
      );
}

class FakePeerMessageService extends PeerMessageService {
  FakePeerMessageService(this._host) : super(_host.client);

  final FakeMessageService _host;

  final List<String> sentBodies = [];
  final List<Map<String, Object?>> gifProfileSends = [];
  final imageProfileSends = <Map<String, Object?>>[];
  final videoProfileSends = <Map<String, Object?>>[];
  final Map<String, void Function(ChatMessage message)> _realtimeHandlers = {};

  bool sendShouldFail = false;

  /// Come `send_message_to_profile` su Postgres (`P0001`).
  void enforceSendToProfileBoundary(String recipientProfileId) {
    final me = _host.client.auth.currentUser?.id;
    if (me != null && recipientProfileId == me) {
      throw const PostgrestException(
        message: 'cannot message yourself',
        code: 'P0001',
      );
    }
  }

  @override
  Future<ChatMessage> sendToProfile({
    required String recipientProfileId,
    required String body,
    required String currentUserId,
    required String clientMessageId,
  }) async {
    if (sendShouldFail) {
      throw StateError('fake send failed');
    }
    enforceSendToProfileBoundary(recipientProfileId);
    sentBodies.add(body);
    final message = ChatMessage(
      id: 'server-$clientMessageId',
      body: body,
      timeLabel: '12:00',
      isMine: true,
      status: MessageStatus.sent,
      createdAt: DateTime.utc(2026, 7, 14, 12),
      clientMessageId: clientMessageId,
      senderId: currentUserId,
    );
    final key = conversationKey(
      userId: currentUserId,
      peerProfileId: recipientProfileId,
    );
    _host.messagesByConversation.putIfAbsent(key, () => []).add(message);
    return message;
  }

  @override
  Future<ChatMessage> sendGifToProfile({
    required String recipientProfileId,
    required String mediaUrl,
    required String currentUserId,
    required String clientMessageId,
  }) async {
    enforceSendToProfileBoundary(recipientProfileId);
    gifProfileSends.add({
      'recipientProfileId': recipientProfileId,
      'mediaUrl': mediaUrl,
      'clientMessageId': clientMessageId,
    });
    return _mediaMessage(
      clientMessageId: clientMessageId,
      currentUserId: currentUserId,
      contentType: MessageContentType.gif,
      mediaUrl: mediaUrl,
    );
  }

  @override
  Future<List<ChatMessage>> fetchPeerMessages({
    required String peerProfileId,
    required String currentUserId,
    int limit = 100,
    DateTime? beforeCreatedAt,
  }) async {
    final all = List<ChatMessage>.from(
      _host.messagesByConversation[conversationKey(
            userId: currentUserId,
            peerProfileId: peerProfileId,
          )] ??
          const [],
    )..sort((a, b) {
        final aAt = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bAt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aAt.compareTo(bAt);
      });

    final filtered = beforeCreatedAt == null
        ? all
        : all
            .where(
              (m) =>
                  m.createdAt != null && m.createdAt!.isBefore(beforeCreatedAt),
            )
            .toList();

    if (filtered.isEmpty) return const [];

    final start = filtered.length > limit ? filtered.length - limit : 0;
    return filtered.sublist(start);
  }

  @override
  RealtimeChannel subscribeToPeerMessages({
    required String currentUserId,
    required String peerProfileId,
    required void Function(ChatMessage message) onMessage,
    void Function(String logicalMessageId)? onReactionFact,
  }) {
    _realtimeHandlers[conversationKey(
      userId: currentUserId,
      peerProfileId: peerProfileId,
    )] = onMessage;
    return _host.client
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
    enforceSendToProfileBoundary(recipientProfileId);
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
    enforceSendToProfileBoundary(recipientProfileId);
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
}

class FakeGroupArchiveService extends GroupArchiveService {
  FakeGroupArchiveService(this._host, super.client);

  final FakeMessageService _host;

  final List<String> broadcastBodies = [];
  final imageBroadcasts = <Map<String, Object?>>[];
  final videoBroadcasts = <Map<String, Object?>>[];
  final Map<String, void Function(ChatMessage message)> _archiveRealtimeHandlers =
      {};

  @override
  Future<ChatMessage> broadcastToAllowlist({
    required String body,
    required String currentUserId,
    required String clientMessageId,
  }) async {
    broadcastBodies.add(body);
    final message = ChatMessage(
      id: 'broadcast-$clientMessageId',
      body: body,
      timeLabel: '12:00',
      isMine: true,
      status: MessageStatus.sent,
      createdAt: DateTime.utc(2026, 7, 14, 12),
      clientMessageId: clientMessageId,
      senderId: currentUserId,
    );
    _host.archiveMessagesByUserId
        .putIfAbsent(currentUserId, () => [])
        .add(message);
    return message;
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
  Future<List<ChatMessage>> fetchArchiveMessages({
    required String currentUserId,
    int limit = 200,
  }) async {
    return List<ChatMessage>.from(
      _host.archiveMessagesByUserId[currentUserId] ?? const [],
    );
  }

  @override
  RealtimeChannel subscribeToArchiveMessages({
    required String currentUserId,
    required void Function(ChatMessage message) onMessage,
  }) {
    _archiveRealtimeHandlers[currentUserId] = onMessage;
    return _host.client.channel('test-archive-$currentUserId').subscribe();
  }
}

/// [FakeMessageService] con ritardo artificiale sul fetch (race scope in test).
class DelayedFakeMessageService extends FakeMessageService {
  DelayedFakeMessageService(
    super.client, {
    this.fetchDelay = const Duration(milliseconds: 50),
  }) : super(
          buildPeer: (host) =>
              _DelayedFakePeerMessageService(host, fetchDelay: fetchDelay),
        );

  final Duration fetchDelay;
}

class _DelayedFakePeerMessageService extends FakePeerMessageService {
  _DelayedFakePeerMessageService(
    super.host, {
    required this.fetchDelay,
  });

  final Duration fetchDelay;

  @override
  Future<List<ChatMessage>> fetchPeerMessages({
    required String peerProfileId,
    required String currentUserId,
    int limit = 100,
    DateTime? beforeCreatedAt,
  }) async {
    await Future<void>.delayed(fetchDelay);
    return super.fetchPeerMessages(
      peerProfileId: peerProfileId,
      currentUserId: currentUserId,
      limit: limit,
      beforeCreatedAt: beforeCreatedAt,
    );
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

  @override
  Future<ChatPeer?> getPeerContext(String profileId) async {
    final summary = profilesById[profileId];
    if (summary == null) return null;
    return ChatPeer.fromProfile(
      profile: summary,
      address: summary.username,
    );
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

/// Scope di test — collegare [ConversationMessageStore.bindCommittedScope] prima del load.
ConversationScope testConversationScope({
  required String userId,
  required String peerProfileId,
  int sessionEpoch = 1,
  int loadSeq = 0,
}) {
  return ConversationScope(
    focusUserId: userId,
    peerProfileId: peerProfileId,
    sessionEpoch: sessionEpoch,
    loadSeq: loadSeq,
  );
}

ConversationMessageStore testMessageStoreFor(ConversationScope scope) {
  final store = ConversationMessageStore();
  store.bindCommittedScope(scope);
  return store;
}

Future<void> waitForMessagesController(MessagesController controller) async {
  for (var i = 0; i < 200 && controller.isLoading; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  // _init continua dopo load (markRead, realtime, notifyListeners).
  await Future<void>.delayed(const Duration(milliseconds: 30));
}
