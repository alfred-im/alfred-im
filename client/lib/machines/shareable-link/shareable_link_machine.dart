// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../utils/shareable_link.dart';
import 'shareable_link_effects.dart';

/// Stato client — `docs/model/uml/shareable-link/shareable-link-state.puml`.
enum ShareableLinkState {
  idle,
  pending,
  resolving,
  invalid,
}

/// Eventi — `docs/domain/shareable-link/commands-and-events.md`.
sealed class ShareableLinkEvent {
  const ShareableLinkEvent();
}

/// Fragment `#` ricevuto o aggiornato.
final class ResolveSharedLink extends ShareableLinkEvent {
  const ResolveSharedLink(this.fragment);
  final String? fragment;
}

/// Sessione pronta: risolve target in coda.
final class HandleSharedLinkTarget extends ShareableLinkEvent {
  const HandleSharedLinkTarget();
}

/// Utente chiude schermata risorsa non trovata.
final class DismissSharedLinkNotFound extends ShareableLinkEvent {
  const DismissSharedLinkNotFound();
}

/// Macchina shareable-link — parse fragment, risoluzione, delega navigation.
class ShareableLinkMachine {
  ShareableLinkMachine(this._effects);

  final ShareableLinkEffects _effects;

  ShareableLinkState state = ShareableLinkState.idle;
  ShareableLinkTarget? target;
  bool handling = false;

  Future<void> send(ShareableLinkEvent event) async {
    switch (event) {
      case ResolveSharedLink(:final fragment):
        _applyFragment(fragment);
      case HandleSharedLinkTarget():
        await _handleTargetIfReady();
      case DismissSharedLinkNotFound():
        target = null;
        handling = false;
        state = ShareableLinkState.idle;
    }
  }

  Future<void> _handleTargetIfReady() async {
    if (target == null || handling || state == ShareableLinkState.invalid) {
      return;
    }
    if (!_effects.sessionReady || !_effects.hasOpenAccounts) {
      state = ShareableLinkState.pending;
      return;
    }

    final focusedUserId = _effects.focusedUserId;
    if (focusedUserId == null) {
      state = ShareableLinkState.pending;
      return;
    }

    handling = true;
    state = ShareableLinkState.resolving;
    final currentTarget = target!;
    try {
      await _resolveAndOpen(currentTarget, focusedUserId);
    } finally {
      handling = false;
    }
  }

  void _applyFragment(String? fragment) {
    final parsed = parseShareableFragment(fragment);
    if (parsed == null) {
      if (target != null || state == ShareableLinkState.invalid) {
        target = null;
        state = ShareableLinkState.idle;
      }
      return;
    }

    if (target?.address == parsed.address && target?.kind == parsed.kind) {
      return;
    }

    target = parsed;
    state = ShareableLinkState.pending;
  }

  Future<void> _resolveAndOpen(
    ShareableLinkTarget currentTarget,
    String focusedUserId,
  ) async {
    final resolution = resolveShareableAddress(currentTarget.address);
    if (resolution == null) {
      state = ShareableLinkState.invalid;
      return;
    }

    final profile =
        await _effects.findProfileByUsername(resolution.localUsername);
    if (profile == null) {
      state = ShareableLinkState.invalid;
      return;
    }

    if (profile.id == focusedUserId) {
      target = null;
      state = ShareableLinkState.idle;
      return;
    }

    if (currentTarget.kind == ShareableLinkKind.chat) {
      await _effects.openSharedChat(
        accountUserId: focusedUserId,
        peerProfileId: profile.id,
      );
    } else {
      await _effects.showProfileOverlay(profile);
    }

    target = null;
    state = ShareableLinkState.idle;
  }
}
