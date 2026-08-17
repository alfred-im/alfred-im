// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_peer.dart';
import '../models/profile_summary.dart';
import '../services/account_session.dart';
import 'inbox_panel.dart';
import 'owner_inbox_stats_loader.dart';

/// [InboxPanel] con affordance owner solo dopo conferma `is_instance_owner()`.
class OwnerGatedInboxPanel extends StatefulWidget {
  const OwnerGatedInboxPanel({
    super.key,
    required this.session,
    required this.selectedPeerId,
    required this.peers,
    required this.isLoading,
    required this.onSelected,
    required this.onSearchChanged,
    required this.onContactsTap,
    this.onAllowedPeopleTap,
    this.onNewMessage,
    this.onDrawerTap,
    this.drawerProfile,
    this.error,
    this.onRetry,
    this.showBackButton = false,
    this.onBack,
    this.showTopBar = true,
    required this.onInstanceConfigTap,
  });

  final AccountSession session;
  final String? selectedPeerId;
  final List<ChatPeer> peers;
  final bool isLoading;
  final ValueChanged<ChatPeer> onSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onContactsTap;
  final VoidCallback? onAllowedPeopleTap;
  final Future<void> Function(String address)? onNewMessage;
  final VoidCallback? onDrawerTap;
  final ProfileSummary? drawerProfile;
  final String? error;
  final VoidCallback? onRetry;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool showTopBar;
  final VoidCallback onInstanceConfigTap;

  @override
  State<OwnerGatedInboxPanel> createState() => _OwnerGatedInboxPanelState();
}

class _OwnerGatedInboxPanelState extends State<OwnerGatedInboxPanel> {
  bool _serverOwner = false;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    unawaited(_resolveOwner());
  }

  @override
  void didUpdateWidget(covariant OwnerGatedInboxPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.userId != widget.session.userId) {
      unawaited(_resolveOwner());
    }
  }

  Future<void> _resolveOwner() async {
    setState(() => _resolved = false);
    try {
      final isOwner = await widget.session.ownerService.isInstanceOwner();
      if (!mounted) return;
      if (isOwner != widget.session.profile.isOwner) {
        await widget.session.syncProfileSummary();
        await widget.session.updateStoredProfile(widget.session.profile);
      }
      setState(() {
        _serverOwner = isOwner;
        _resolved = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverOwner = false;
        _resolved = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InboxPanel(
      selectedPeerId: widget.selectedPeerId,
      peers: widget.peers,
      isLoading: widget.isLoading,
      error: widget.error,
      onRetry: widget.onRetry,
      onSelected: widget.onSelected,
      onSearchChanged: widget.onSearchChanged,
      onDrawerTap: widget.onDrawerTap,
      drawerProfile: widget.drawerProfile,
      onContactsTap: widget.onContactsTap,
      onAllowedPeopleTap: widget.onAllowedPeopleTap,
      onNewMessage: widget.onNewMessage,
      showBackButton: widget.showBackButton,
      onBack: widget.onBack,
      showTopBar: widget.showTopBar,
      onInstanceConfigTap:
          _resolved && _serverOwner ? widget.onInstanceConfigTap : null,
      headerBelowBar: _resolved && _serverOwner
          ? OwnerInboxStatsLoader(session: widget.session)
          : null,
    );
  }
}
