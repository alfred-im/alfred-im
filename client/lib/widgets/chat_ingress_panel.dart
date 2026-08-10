// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
import '../models/peer_relationship.dart';
import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
import '../providers/contacts_controller.dart';
import '../providers/reception_allowlist_controller.dart';
import '../theme/alfred_colors.dart';
import 'peer_profile_overlay.dart';
import 'profile_identity.dart';

/// Ingresso chat: header peer + spinner, senza [MessagesController].
///
/// File leggero — importabile senza trascinare il bundle media di [ChatPanel].
class ChatIngressPanel extends StatelessWidget {
  const ChatIngressPanel({
    super.key,
    required this.peer,
    this.showBackButton = false,
    this.onBack,
  });

  final ChatPeer peer;
  final bool showBackButton;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AlfredColors.surface,
      child: Column(
        children: [
          ChatPanelHeader(
            peer: peer,
            showBackButton: showBackButton,
            onBack: onBack,
          ),
          const Expanded(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}

/// Header condiviso tra ingresso, [ChatPanel] e [GroupConversationScreen].
class ChatPanelHeader extends StatelessWidget {
  const ChatPanelHeader({
    super.key,
    this.peer,
    this.profile,
    required this.showBackButton,
    this.onBack,
    this.showCallActions = false,
  }) : assert(peer != null || profile != null);

  final ChatPeer? peer;
  final ProfileSummary? profile;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool showCallActions;

  ProfileSummary get _profile => peer?.profile ?? profile!;

  @override
  Widget build(BuildContext context) {
    final resolvedProfile = _profile;

    return Material(
      color: AlfredColors.panel,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AlfredColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              if (showBackButton)
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                ),
              ProfileAvatar(
                profile: resolvedProfile,
                radius: 20,
                fontSize: 16,
                onTap: () => showPeerProfileOverlay(context, resolvedProfile),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ProfileIdentityLines(
                  profile: resolvedProfile,
                  showUsername: false,
                  nameStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: AlfredColors.textPrimary,
                  ),
                ),
              ),
              if (showCallActions) ...[
                IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.videocam_outlined),
                ),
                IconButton(
                  onPressed: null,
                  icon: const Icon(Icons.call_outlined),
                ),
              ],
              if (peer != null) _ChatPeerOverflowMenu(peer: peer!),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ChatPeerMenuAction { rubrica, allow }

class _ChatPeerOverflowMenu extends StatefulWidget {
  const _ChatPeerOverflowMenu({required this.peer});

  final ChatPeer peer;

  @override
  State<_ChatPeerOverflowMenu> createState() => _ChatPeerOverflowMenuState();
}

class _ChatPeerOverflowMenuState extends State<_ChatPeerOverflowMenu> {
  bool _busy = false;

  PeerRelationship get _relationship =>
      widget.peer.relationship ??
      const PeerRelationship(inContacts: false, isAllowed: false);

  bool get _hasRelationship => widget.peer.hasRelationship;

  void _patchPeerRelationship(PeerRelationship relationship) {
    final auth = context.read<AuthController>();
    auth.patchActivePeer(widget.peer.withRelationship(relationship));
  }

  Future<void> _toggleRubrica({required bool inRubrica}) async {
    final contacts = context.read<ContactsController?>();
    if (contacts == null || _busy) return;

    setState(() => _busy = true);
    try {
      if (inRubrica) {
        await contacts.removeInternalByProfileId(widget.peer.profileId);
      } else {
        await contacts.addInternal(widget.peer.profile);
      }
      if (mounted) {
        _patchPeerRelationship(
          _relationship.copyWith(inContacts: !inRubrica),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAllowed(bool value) async {
    final allowlist = context.read<ReceptionAllowlistController?>();
    if (allowlist == null || _busy) return;

    setState(() => _busy = true);
    try {
      if (value) {
        await allowlist.addProfile(widget.peer.profile);
      } else {
        await allowlist.removeByProfileId(widget.peer.profileId);
      }
      if (mounted) {
        _patchPeerRelationship(_relationship.copyWith(isAllowed: value));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final resolvedPeer = auth.activePeer?.profileId == widget.peer.profileId
        ? auth.activePeer!
        : widget.peer;
    final relationship = resolvedPeer.relationship ?? _relationship;
    final actionsEnabled = _hasRelationship && !_busy;

    return PopupMenuButton<_ChatPeerMenuAction>(
      tooltip: 'Altre azioni',
      enabled: actionsEnabled,
      icon: const Icon(Icons.more_vert),
      onSelected: actionsEnabled
          ? (action) {
              switch (action) {
                case _ChatPeerMenuAction.rubrica:
                  unawaited(
                    _toggleRubrica(inRubrica: relationship.inContacts),
                  );
                case _ChatPeerMenuAction.allow:
                  unawaited(_setAllowed(!relationship.isAllowed));
              }
            }
          : null,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _ChatPeerMenuAction.rubrica,
          child: Text(
            relationship.inContacts
                ? 'Rimuovi dalla rubrica'
                : 'Aggiungi alla rubrica',
          ),
        ),
        PopupMenuItem(
          value: _ChatPeerMenuAction.allow,
          child: Text(relationship.isAllowed ? 'Revoca' : 'Consenti'),
        ),
      ],
    );
  }
}
