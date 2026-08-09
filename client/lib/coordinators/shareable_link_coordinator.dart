// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../machines/shareable-link/shareable_link_adapters.dart';
import '../machines/shareable-link/shareable_link_effects.dart';
import '../machines/shareable-link/shareable_link_machine.dart';
import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
import '../utils/shareable_link.dart';
import '../utils/shareable_link_platform.dart';
import '../widgets/peer_profile_overlay.dart';

/// Orchestrazione fragment `#` e stato risorsa shareable-link.
class ShareableLinkCoordinator {
  ShareableLinkCoordinator({required void Function() onStateChanged})
      : _onStateChanged = onStateChanged {
    applyFragment(readShareableFragment());
  }

  final void Function() _onStateChanged;

  ShareableLinkMachine? _machine;
  ShareableLinkAdapters? _adapters;
  bool _liveEffectsBound = false;

  ShareableLinkTarget? get target => _machine?.target;
  bool get invalid => _machine?.state == ShareableLinkState.invalid;
  bool get isHandling => _machine?.handling ?? false;

  void _ensureMachine(BuildContext context) {
    if (_liveEffectsBound) return;
    final auth = context.read<AuthController>();
    final effects = _LiveShareableLinkEffects(auth, () => context);
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
      _onStateChanged();
      return;
    }
    final hadTarget = _machine!.target != null;
    final wasInvalid = _machine!.state == ShareableLinkState.invalid;
    _adapters!.onFragmentChanged(fragment);
    if (hadTarget || wasInvalid || _machine!.target != null) {
      _onStateChanged();
    }
  }

  void clearInvalid() {
    if (!invalid) return;
    _adapters?.onDismissNotFound();
    _onStateChanged();
  }

  Future<void> handleIfReady(BuildContext context) async {
    _ensureMachine(context);
    await _adapters!.onHandleRequested();
    _onStateChanged();
  }

  void dismissInvalid() {
    clearShareableFragment();
    clearInvalid();
  }
}

class _LiveShareableLinkEffects implements ShareableLinkEffects {
  _LiveShareableLinkEffects(this._auth, this._contextAccessor);

  final AuthController _auth;
  final BuildContext Function() _contextAccessor;

  @override
  bool get sessionReady => _auth.sessionReady;

  @override
  bool get hasOpenAccounts => _auth.hasOpenAccounts;

  @override
  String? get focusedUserId => _auth.focusedSession?.userId;

  @override
  Future<ProfileSummary?> findProfileByUsername(String localUsername) {
    final session = _auth.focusedSession;
    if (session == null) return Future.value();
    return session.profileService.findByUsername(localUsername);
  }

  @override
  Future<bool> openSharedChat({
    required String accountUserId,
    required String peerProfileId,
  }) {
    return _auth.openConversationFromShareableLink(
      accountUserId: accountUserId,
      peerProfileId: peerProfileId,
    );
  }

  @override
  Future<void> showProfileOverlay(ProfileSummary profile) async {
    final context = _contextAccessor();
    if (!context.mounted) return;
    await showPeerProfileOverlay(context, profile);
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
