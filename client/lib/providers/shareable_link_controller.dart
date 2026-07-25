// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../machines/shareable-link/auth_shareable_link_effects.dart';
import '../machines/shareable-link/shareable_link_adapters.dart';
import '../machines/shareable-link/shareable_link_effects.dart';
import '../machines/shareable-link/shareable_link_machine.dart';
import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
import '../utils/shareable_link.dart';
import '../utils/shareable_link_platform.dart';

/// Gestisce destinazione da fragment `#` e stato risorsa non trovata.
class ShareableLinkController extends ChangeNotifier {
  ShareableLinkController() {
    applyFragment(readShareableFragment());
  }

  ShareableLinkMachine? _machine;
  ShareableLinkAdapters? _adapters;
  bool _liveEffectsBound = false;

  ShareableLinkTarget? get target => _machine?.target;
  bool get invalid => _machine?.state == ShareableLinkState.invalid;
  bool get isHandling => _machine?.handling ?? false;

  void _ensureMachine(BuildContext context) {
    if (_liveEffectsBound) return;
    final auth = context.read<AuthController>();
    final effects = AuthShareableLinkEffects(auth, () => context);
    final existingTarget = _machine?.target;
    _machine = ShareableLinkMachine(effects);
    _adapters = ShareableLinkAdapters(_machine!);
    _liveEffectsBound = true;
    if (existingTarget != null) {
      final fragment = existingTarget.kind == ShareableLinkKind.chat
          ? '${existingTarget.address}/chat'
          : existingTarget.address;
      _adapters!.onFragmentChanged(fragment);
    }
  }

  void applyFragment(String? fragment) {
    if (_machine == null) {
      final parsed = parseShareableFragment(fragment);
      if (parsed == null) return;
      _machine = ShareableLinkMachine(_NoopShareableLinkEffects());
      _adapters = ShareableLinkAdapters(_machine!);
      _adapters!.onFragmentChanged(fragment);
      notifyListeners();
      return;
    }
    final hadTarget = _machine!.target != null;
    final wasInvalid = _machine!.state == ShareableLinkState.invalid;
    _adapters!.onFragmentChanged(fragment);
    if (hadTarget || wasInvalid || _machine!.target != null) {
      notifyListeners();
    }
  }

  void clearInvalid() {
    if (!invalid) return;
    _adapters?.onDismissInvalid();
    notifyListeners();
  }

  Future<void> handleIfReady(BuildContext context) async {
    _ensureMachine(context);
    await _adapters!.onHandleRequested();
    notifyListeners();
  }

  void dismissInvalid() {
    clearShareableFragment();
    clearInvalid();
  }
}

class _NoopShareableLinkEffects implements ShareableLinkEffects {
  @override
  bool get sessionReady => false;

  @override
  bool get hasOpenAccounts => false;

  @override
  String? get focusedUserId => null;

  @override
  Future<ProfileSummary?> findProfileByUsername(String localUsername) {
    return Future.value();
  }

  @override
  Future<bool> openSharedChat({
    required String accountUserId,
    required String peerProfileId,
  }) {
    return Future.value(false);
  }

  @override
  Future<void> showProfileOverlay(ProfileSummary profile) async {}
}
