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
import '../utils/peer_relationship_actions.dart';
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
  bool _primed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_primed) return;
    _primed = true;
    unawaited(PeerRelationshipActions.prime(context));
  }

  ChatPeer _resolvedPeer(AuthController auth) {
    return auth.activePeer?.profileId == widget.peer.profileId
        ? auth.activePeer!
        : widget.peer;
  }

  PeerRelationship _relationshipFor(ChatPeer peer) {
    return PeerRelationshipActions.relationshipForPeer(
      context,
      profileId: peer.profileId,
      peerFlags: peer.relationship,
    );
  }

  void _patchPeerRelationship(
    AuthController auth,
    PeerRelationship relationship,
  ) {
    auth.patchActivePeer(_resolvedPeer(auth).withRelationship(relationship));
  }

  Future<void> _toggleRubrica({
    required AuthController auth,
    required bool inRubrica,
  }) async {
    if (_busy) return;

    final peer = _resolvedPeer(auth);
    setState(() => _busy = true);
    try {
      await PeerRelationshipActions.toggleRubrica(
        context: context,
        profileId: peer.profileId,
        profile: peer.profile,
        inRubrica: inRubrica,
        peerFlags: peer.relationship,
      );
      if (mounted) {
        _patchPeerRelationship(
          auth,
          _relationshipFor(peer).copyWith(inContacts: !inRubrica),
        );
      }
    } catch (e) {
      if (mounted) PeerRelationshipActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAllowed(AuthController auth, bool value) async {
    if (_busy) return;

    final peer = _resolvedPeer(auth);
    setState(() => _busy = true);
    try {
      await PeerRelationshipActions.setAllowed(
        context: context,
        profileId: peer.profileId,
        profile: peer.profile,
        value: value,
        peerFlags: peer.relationship,
      );
      if (mounted) {
        _patchPeerRelationship(
          auth,
          _relationshipFor(peer).copyWith(isAllowed: value),
        );
      }
    } catch (e) {
      if (mounted) PeerRelationshipActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    context.watch<ReceptionAllowlistController?>();
    context.watch<ContactsController?>();
    final peer = _resolvedPeer(auth);
    final relationship = _relationshipFor(peer);
    final actionsEnabled =
        PeerRelationshipActions.controllersReady(context) && !_busy;

    return PopupMenuButton<_ChatPeerMenuAction>(
      tooltip: 'Altre azioni',
      enabled: actionsEnabled,
      icon: const Icon(Icons.more_vert),
      onSelected: actionsEnabled
          ? (action) {
              switch (action) {
                case _ChatPeerMenuAction.rubrica:
                  unawaited(
                    _toggleRubrica(
                      auth: auth,
                      inRubrica: relationship.inContacts,
                    ),
                  );
                case _ChatPeerMenuAction.allow:
                  unawaited(_setAllowed(auth, !relationship.isAllowed));
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
