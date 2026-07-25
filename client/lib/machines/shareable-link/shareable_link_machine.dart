// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../utils/shareable_link.dart';
import 'shareable_link_effects.dart';

/// Stato client — `docs/model/uml/shareable-link/seq-open-from-fragment.puml`.
enum ShareableLinkState {
  idle,
  pending,
  resolving,
  invalid,
}

sealed class ShareableLinkEvent {
  const ShareableLinkEvent();
}

/// Fragment `#` ricevuto o aggiornato.
final class ParseFragment extends ShareableLinkEvent {
  const ParseFragment(this.fragment);
  final String? fragment;
}

final class DismissInvalid extends ShareableLinkEvent {
  const DismissInvalid();
}

/// Macchina shareable-link — parse fragment, risoluzione, delega navigation.
class ShareableLinkMachine {
  ShareableLinkMachine(this._effects);

  final ShareableLinkEffects _effects;

  ShareableLinkState state = ShareableLinkState.idle;
  ShareableLinkTarget? target;
  bool handling = false;

  void send(ShareableLinkEvent event) {
    switch (event) {
      case ParseFragment(:final fragment):
        _applyFragment(fragment);
      case DismissInvalid():
        target = null;
        handling = false;
        state = ShareableLinkState.idle;
    }
  }

  Future<void> handleTargetIfReady() async {
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
