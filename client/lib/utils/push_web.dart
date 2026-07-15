// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

import '../models/push_conversation_key.dart';
import 'push_deep_link.dart';
import 'push_launch.dart';
import 'push_permission_flow.dart';
import 'push_stub.dart' show PushOpenChatIntent, PushSubscriptionKeys;

export '../models/push_conversation_key.dart';
export 'push_deep_link.dart';
export 'push_stub.dart' show PushOpenChatIntent, PushSubscriptionKeys;

const _deviceIdKey = 'alfred_device_id';
const _pendingOpenChatKey = 'alfred_pending_open_chat';

final _openChatController = StreamController<PushOpenChatIntent>.broadcast();

/// Web Push platform hooks (VAPID + service worker).
class PushPlatform {
  const PushPlatform._();

  static bool get isPushSupported {
    try {
      final _ = web.Notification.permission;
      return isWebPushEnvironmentSupported(
        hasPushManagerOnWindow: _jsHas('PushManager'),
        hasServiceWorkerOnNavigator:
            (web.window.navigator as JSObject).has('serviceWorker'),
      );
    } catch (_) {
      return false;
    }
  }

  static String? get notificationPermission {
    try {
      if (!isPushSupported) return null;
      return web.Notification.permission;
    } catch (_) {
      return null;
    }
  }

  static Future<String> getOrCreateDeviceId() async {
    final storage = web.window.localStorage;
    final existing = storage.getItem(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final id = const Uuid().v4();
    storage.setItem(_deviceIdKey, id);
    return id;
  }

  static Future<String?> requestPermissionIfNeeded() async {
    return notificationPermission;
  }

  static Future<PushSubscriptionKeys?> ensureSubscription({
    required String vapidPublicKey,
  }) async {
    if (!isPushSupported) return null;
    if (vapidPublicKey.isEmpty) return null;
    if (web.Notification.permission == 'denied') return null;

    final base = web.document.querySelector('base')?.getAttribute('href') ?? '/';
    final swUrl = '${base}push_sw.js';

    web.ServiceWorkerRegistration registration;
    try {
      registration = await web.window.navigator.serviceWorker
          .register(swUrl.toJS)
          .toDart;
    } catch (_) {
      return null;
    }

    try {
      final existing = await registration.pushManager.getSubscription().toDart;
      web.PushSubscription subscription;
      if (existing != null) {
        subscription = existing;
      } else {
        subscription = await registration.pushManager
            .subscribe(
              web.PushSubscriptionOptionsInit(
                userVisibleOnly: true,
                applicationServerKey: _urlBase64ToUint8Array(vapidPublicKey),
              ),
            )
            .toDart;
      }

      if (web.Notification.permission != 'granted') return null;

      final endpoint = subscription.endpoint;
      final key = subscription.getKey('p256dh');
      final auth = subscription.getKey('auth');
      if (key == null || auth == null) return null;

      return PushSubscriptionKeys(
        endpoint: endpoint,
        p256dhKey: _bufferToBase64Url(key),
        authKey: _bufferToBase64Url(auth),
      );
    } catch (_) {
      return null;
    }
  }

  static void updateSuppression({
    required String? focusUserId,
    required String? activePeerProfileId,
    required bool appVisible,
  }) {
    final payload = jsonEncode({
      'type': 'alfred_push_suppression',
      'focusUserId': focusUserId,
      'activePeerProfileId': activePeerProfileId,
      'appVisible': appVisible,
    });
    unawaited(_postToServiceWorker(payload));
  }

  static Future<void> _postToServiceWorker(String payload) async {
    try {
      final controller = web.window.navigator.serviceWorker.controller;
      controller?.postMessage(payload.toJS);
    } catch (_) {
      // SW non ancora attivo.
    }
  }

  static Stream<PushOpenChatIntent> get openChatIntents =>
      _openChatController.stream;

  static void persistPendingOpenChat(PushConversationKey conversation) {
    final payload = jsonEncode({
      'recipientUserId': conversation.ownerUserId,
      'peerProfileId': conversation.peerProfileId,
    });
    web.window.localStorage.setItem(_pendingOpenChatKey, payload);
  }

  static PushOpenChatIntent? readPendingOpenChat() {
    final raw = web.window.localStorage.getItem(_pendingOpenChatKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final conversation = PushConversationKey.tryFromPayload(map);
      if (conversation == null) return null;
      return PushOpenChatIntent(conversation);
    } catch (_) {
      return null;
    }
  }

  static void clearPendingOpenChat() {
    web.window.localStorage.removeItem(_pendingOpenChatKey);
    clearPushLaunchFragment();
  }

  static void tryDrainPendingOpenChat() {
    consumePushLaunchFragment();
    final intent = readPendingOpenChat();
    if (intent == null) return;
    _emitOpenChat(intent.conversation);
  }

  static void consumePushLaunchFragment() {
    final fragment = readPushLaunchFragment();
    final conversation = PushDeepLink.tryParseFragment(fragment);
    if (conversation == null) return;
    persistPendingOpenChat(conversation);
    clearPushLaunchFragment();
  }

  static void _emitOpenChat(PushConversationKey conversation) {
    _openChatController.add(PushOpenChatIntent(conversation));
  }

  static void _handleWindowMessage(web.Event event) {
    if (!event.isA<web.MessageEvent>()) return;
    final messageEvent = event as web.MessageEvent;
    final data = messageEvent.data;
    if (data == null) return;

    final String? raw;
    if (data.isA<JSString>()) {
      raw = (data as JSString).toDart;
    } else {
      return;
    }

    Map<String, dynamic> map;
    try {
      map = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (map['type'] != 'open_chat') return;
    final conversation = PushConversationKey.tryFromPayload(map);
    if (conversation == null) return;
    persistPendingOpenChat(conversation);
    _emitOpenChat(conversation);
  }

  static var _messageHookInstalled = false;

  static void ensureMessageHook() {
    if (_messageHookInstalled) return;
    _messageHookInstalled = true;
    web.window.addEventListener('message', _handleWindowMessage.toJS);
    tryDrainPendingOpenChat();
  }

  static Future<void> unregisterServiceWorkerSubscription() async {
    final registration = await web.window.navigator.serviceWorker.ready.toDart;
    final sub = await registration.pushManager.getSubscription().toDart;
    await sub?.unsubscribe().toDart;
  }
}

bool _jsHas(String name) {
  return globalContext.has(name);
}

JSUint8Array _urlBase64ToUint8Array(String base64String) {
  final padding = '=' * ((4 - base64String.length % 4) % 4);
  final base64 = (base64String + padding)
      .replaceAll('-', '+')
      .replaceAll('_', '/');
  final raw = base64Decode(base64);
  final bytes = Uint8List.fromList(raw);
  return bytes.toJS;
}

String _bufferToBase64Url(JSArrayBuffer buffer) {
  final bytes = Uint8List.view(buffer.toDart);
  return base64Url.encode(bytes).replaceAll('=', '');
}
