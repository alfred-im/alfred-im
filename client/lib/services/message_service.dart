// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';
import 'group_archive_service.dart';
import 'peer_message_service.dart';

/// Facade backward-compatible: compone [PeerMessageService] e [GroupArchiveService].
class MessageService {
  MessageService(SupabaseClient client)
      : _peer = PeerMessageService(client),
        _groupArchive = GroupArchiveService(client);

  final PeerMessageService _peer;
  final GroupArchiveService _groupArchive;

  GroupArchiveService get groupArchive => _groupArchive;

  PeerMessageService get peer => _peer;

  Future<List<ChatMessage>> fetchOwnerMessages({
    required String currentUserId,
    int limit = 200,
  }) =>
      _groupArchive.fetchOwnerMessages(
        currentUserId: currentUserId,
        limit: limit,
      );

  Future<ChatMessage> broadcastToAllowlist({
    required String body,
    required String currentUserId,
    required String clientMessageId,
  }) =>
      _groupArchive.broadcastToAllowlist(
        body: body,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
      );

  Future<ChatMessage> broadcastGifToAllowlist({
    required String mediaUrl,
    required String currentUserId,
    required String clientMessageId,
  }) =>
      _groupArchive.broadcastGifToAllowlist(
        mediaUrl: mediaUrl,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
      );

  Future<ChatMessage> broadcastVoiceToAllowlist({
    required String mediaUrl,
    required int durationSeconds,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
  }) =>
      _groupArchive.broadcastVoiceToAllowlist(
        mediaUrl: mediaUrl,
        durationSeconds: durationSeconds,
        mediaSizeBytes: mediaSizeBytes,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
      );

  Future<ChatMessage> broadcastLocationToAllowlist({
    required double latitude,
    required double longitude,
    required String currentUserId,
    required String clientMessageId,
  }) =>
      _groupArchive.broadcastLocationToAllowlist(
        latitude: latitude,
        longitude: longitude,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
      );

  Future<ChatMessage> broadcastImageToAllowlist({
    required String mediaUrl,
    required String mediaMime,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) =>
      _groupArchive.broadcastImageToAllowlist(
        mediaUrl: mediaUrl,
        mediaMime: mediaMime,
        mediaSizeBytes: mediaSizeBytes,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
        body: body,
      );

  Future<ChatMessage> broadcastVideoToAllowlist({
    required String mediaUrl,
    required String mediaMime,
    required int durationSeconds,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) =>
      _groupArchive.broadcastVideoToAllowlist(
        mediaUrl: mediaUrl,
        mediaMime: mediaMime,
        durationSeconds: durationSeconds,
        mediaSizeBytes: mediaSizeBytes,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
        body: body,
      );

  Future<List<ChatMessage>> fetchPeerMessages({
    required String peerProfileId,
    required String currentUserId,
    int limit = 100,
    DateTime? beforeCreatedAt,
  }) =>
      _peer.fetchPeerMessages(
        peerProfileId: peerProfileId,
        currentUserId: currentUserId,
        limit: limit,
        beforeCreatedAt: beforeCreatedAt,
      );

  Future<ChatMessage> sendToProfile({
    required String recipientProfileId,
    required String body,
    required String currentUserId,
    required String clientMessageId,
  }) =>
      _peer.sendToProfile(
        recipientProfileId: recipientProfileId,
        body: body,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
      );

  Future<ChatMessage> sendGifToProfile({
    required String recipientProfileId,
    required String mediaUrl,
    required String currentUserId,
    required String clientMessageId,
  }) =>
      _peer.sendGifToProfile(
        recipientProfileId: recipientProfileId,
        mediaUrl: mediaUrl,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
      );

  Future<ChatMessage> sendVoiceToProfile({
    required String recipientProfileId,
    required String mediaUrl,
    required int durationSeconds,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
  }) =>
      _peer.sendVoiceToProfile(
        recipientProfileId: recipientProfileId,
        mediaUrl: mediaUrl,
        durationSeconds: durationSeconds,
        mediaSizeBytes: mediaSizeBytes,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
      );

  Future<ChatMessage> sendLocationToProfile({
    required String recipientProfileId,
    required double latitude,
    required double longitude,
    required String currentUserId,
    required String clientMessageId,
  }) =>
      _peer.sendLocationToProfile(
        recipientProfileId: recipientProfileId,
        latitude: latitude,
        longitude: longitude,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
      );

  Future<ChatMessage> sendImageToProfile({
    required String recipientProfileId,
    required String mediaUrl,
    required String mediaMime,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) =>
      _peer.sendImageToProfile(
        recipientProfileId: recipientProfileId,
        mediaUrl: mediaUrl,
        mediaMime: mediaMime,
        mediaSizeBytes: mediaSizeBytes,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
        body: body,
      );

  Future<ChatMessage> sendVideoToProfile({
    required String recipientProfileId,
    required String mediaUrl,
    required String mediaMime,
    required int durationSeconds,
    required int mediaSizeBytes,
    required String currentUserId,
    required String clientMessageId,
    String body = '',
  }) =>
      _peer.sendVideoToProfile(
        recipientProfileId: recipientProfileId,
        mediaUrl: mediaUrl,
        mediaMime: mediaMime,
        durationSeconds: durationSeconds,
        mediaSizeBytes: mediaSizeBytes,
        currentUserId: currentUserId,
        clientMessageId: clientMessageId,
        body: body,
      );

  RealtimeChannel subscribeToOwnerMessages({
    required String currentUserId,
    required void Function(ChatMessage message) onMessage,
  }) =>
      _groupArchive.subscribeToOwnerMessages(
        currentUserId: currentUserId,
        onMessage: onMessage,
      );

  RealtimeChannel subscribeToPeerMessages({
    required String currentUserId,
    required String peerProfileId,
    required void Function(ChatMessage message) onMessage,
  }) =>
      _peer.subscribeToPeerMessages(
        currentUserId: currentUserId,
        peerProfileId: peerProfileId,
        onMessage: onMessage,
      );

  void disposeChannel(RealtimeChannel? channel) =>
      _peer.disposeChannel(channel);
}
