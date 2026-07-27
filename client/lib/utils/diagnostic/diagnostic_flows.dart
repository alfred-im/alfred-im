// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

/// Catalogo flussi osservabili — confini macchina/coordinator, non widget.
///
/// Ogni flusso ha fasi documentate in [DiagnosticFlows.phasesFor]. Aggiungere
/// qui prima di instrumentare codice nuovo.
abstract final class DiagnosticFlows {
  static const auth = 'auth';
  static const nav = 'nav';
  static const scope = 'scope';
  static const messaging = 'messaging';
  static const media = 'media';
  static const push = 'push';

  static const all = <String>[
    auth,
    nav,
    scope,
    messaging,
    media,
    push,
  ];

  /// Fasi attese per documentazione agente / assert test diagnostici.
  static List<String> phasesFor(String flow) {
    switch (flow) {
      case auth:
        return const [
          'focus.start',
          'focus.restore',
          'focus.ok',
          'focus.fail',
          'session.ready',
          'session.missing',
        ];
      case nav:
        return const [
          'open_peer',
          'open_conversation.start',
          'open_conversation.ok',
          'focus.start',
          'focus.ok',
          'scope.commit',
          'scope.invalidate',
          'scope.epoch_reconcile',
        ];
      case scope:
        return const [
          'check',
          'inactive',
        ];
      case messaging:
        return const [
          'load.start',
          'load.ready',
          'load.blocked',
          'fetch',
          'session.check',
          'send.guard',
          'send.start',
          'send.done',
          'outbound.start',
          'outbound.done',
          'outbound.fail',
        ];
      case media:
        return const [
          'upload.start',
          'upload.done',
          'upload.fail',
        ];
      case push:
        return const [
          'hook.install',
          'sw.message',
          'open_chat.emit',
          'handler.enqueue',
          'handler.chat_opened',
          'pending.drain',
          'fragment.consume',
        ];
      default:
        return const [];
    }
  }
}

/// Operazioni multi-step (campo `op=` nel log) — correlate via [DiagnosticTrace].
abstract final class DiagnosticOps {
  static const loadConversation = 'load.conversation';
  static const sendText = 'send.text';
  static const sendImage = 'send.image';
  static const sendVideo = 'send.video';
  static const sendGif = 'send.gif';
  static const sendVoice = 'send.voice';
  static const sendLocation = 'send.location';
  static const openPeer = 'open.peer';
  static const focusAccount = 'focus.account';
  static const pushOpenChat = 'push.open_chat';
}
