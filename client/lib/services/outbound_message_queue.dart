import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/outbound_queue_item.dart';
import 'outbound_media_cache.dart';

/// Disk-backed retry queue for failed outbound messages (text, GIF, voice).
class OutboundMessageQueue {
  OutboundMessageQueue({SharedPreferences? preferences})
      : _preferencesFuture = preferences != null
            ? Future.value(preferences)
            : SharedPreferences.getInstance();

  static const _storageKey = 'alfred_outbound_queue_v1';

  final Future<SharedPreferences> _preferencesFuture;
  final _controller = StreamController<List<OutboundQueueItem>>.broadcast();

  Stream<List<OutboundQueueItem>> get changes => _controller.stream;

  Future<List<OutboundQueueItem>> loadAll() async {
    final prefs = await _preferencesFuture;
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    return OutboundQueueItem.decodeList(raw);
  }

  Future<List<OutboundQueueItem>> loadForConversation(String conversationId) async {
    final all = await loadAll();
    return all.where((item) => item.conversationId == conversationId).toList();
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
    if (kIsWeb) {
      OutboundMediaCache.instance.put(clientId, bytes);
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
      return OutboundMediaCache.instance.peek(clientId);
    }
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> deleteMediaFile(String? path, {String? clientId}) async {
    if (clientId != null) {
      OutboundMediaCache.instance.remove(clientId);
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
