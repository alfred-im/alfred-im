// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/chat_media_config.dart';
import '../models/outbound_queue_item.dart';
import 'outbound_media_cache.dart';

/// Disk-backed retry queue for failed outbound messages (text, GIF, voice).
class OutboundMessageQueue {
  OutboundMessageQueue({SharedPreferences? preferences})
      : _preferencesFuture = preferences != null
            ? Future.value(preferences)
            : SharedPreferences.getInstance();

  static const _storageKey = 'alfred_outbound_queue_v1';
  static const _webMediaStorageKey = 'alfred_outbound_media_v1';

  final Future<SharedPreferences> _preferencesFuture;
  final _controller = StreamController<List<OutboundQueueItem>>.broadcast();

  Stream<List<OutboundQueueItem>> get changes => _controller.stream;

  Future<List<OutboundQueueItem>> loadAll() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    return OutboundQueueItem.decodeList(raw);
  }

  Future<List<OutboundQueueItem>> loadForQueueKey(String queueKey) async {
    final all = await loadAll();
    return all.where((item) => item.queueKey == queueKey).toList();
  }

  Future<void> enqueue(OutboundQueueItem item) async {
    final all = await loadAll();
    final withoutDuplicate =
        all.where((existing) => existing.clientId != item.clientId).toList();
    final next = [...withoutDuplicate, item];
    await _persist(next);
  }

  Future<void> remove(String clientId) async {
    final all = await loadAll();
    final next = all.where((item) => item.clientId != clientId).toList();
    await _persist(next);
  }

  Future<void> update(OutboundQueueItem item) async {
    final all = await loadAll();
    final next = all
        .map((existing) => existing.clientId == item.clientId ? item : existing)
        .toList();
    await _persist(next);
  }

  Future<String> persistMediaBytes({
    required String clientId,
    required Uint8List bytes,
    required String extension,
  }) async {
    OutboundMediaCache.instance.put(clientId, bytes);

    if (kIsWeb) {
      if (ChatMediaConfig.shouldPersistOutboundMediaOnWeb(bytes.length)) {
        await _persistWebMedia(clientId, bytes);
      }
      return 'memory://$clientId';
    }

    final directory = await _mediaDirectory();
    final path = '${directory.path}/$clientId.$extension';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    return path;
  }

  Future<Uint8List?> readMediaBytes(String? path, String clientId) async {
    if (path == null) return null;
    if (path.startsWith('memory://') || kIsWeb) {
      final cached = OutboundMediaCache.instance.peek(clientId);
      if (cached != null) return cached;
      if (kIsWeb) {
        return _readWebMedia(clientId);
      }
      return null;
    }
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> deleteMediaFile(String? path, {String? clientId}) async {
    if (clientId != null) {
      OutboundMediaCache.instance.remove(clientId);
      if (kIsWeb) {
        await _deleteWebMedia(clientId);
      }
    }
    if (path == null || path.isEmpty || kIsWeb || path.startsWith('memory://')) {
      return;
    }
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Best-effort cleanup.
    }
  }

  Duration retryDelayForAttempts(int attempts) {
    final capped = attempts.clamp(0, 6);
    return Duration(seconds: 1 << capped);
  }

  Future<void> _persist(List<OutboundQueueItem> items) async {
    final prefs = await _preferencesFuture;
    await prefs.setString(_storageKey, OutboundQueueItem.encodeList(items));
    _controller.add(items);
  }

  Future<void> _persistWebMedia(String clientId, Uint8List bytes) async {
    final prefs = await _preferencesFuture;
    final map = _decodeWebMediaMap(prefs.getString(_webMediaStorageKey));
    map[clientId] = base64Encode(bytes);
    await prefs.setString(_webMediaStorageKey, jsonEncode(map));
  }

  Future<Uint8List?> _readWebMedia(String clientId) async {
    final prefs = await _preferencesFuture;
    final encoded = _decodeWebMediaMap(prefs.getString(_webMediaStorageKey))[clientId];
    if (encoded == null) return null;
    final bytes = base64Decode(encoded);
    OutboundMediaCache.instance.put(clientId, bytes);
    return bytes;
  }

  Future<void> _deleteWebMedia(String clientId) async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_webMediaStorageKey);
    if (raw == null || raw.isEmpty) return;
    final map = _decodeWebMediaMap(raw);
    if (!map.containsKey(clientId)) return;
    map.remove(clientId);
    await prefs.setString(_webMediaStorageKey, jsonEncode(map));
  }

  Map<String, String> _decodeWebMediaMap(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  Future<Directory> _mediaDirectory() async {
    final base = await getApplicationSupportDirectory();
    final directory = Directory('${base.path}/outbound_media');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  void dispose() {
    _controller.close();
  }
}
