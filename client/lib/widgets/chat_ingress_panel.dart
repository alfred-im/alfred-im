// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  bool _refreshing = false;

  ChatPeer _resolvedPeer(AuthController auth) {
    return auth.activePeer?.profileId == widget.peer.profileId
        ? auth.activePeer!
        : widget.peer;
  }

  PeerRelationship _relationshipFor(ChatPeer peer) {
    return peer.relationship ??
        const PeerRelationship(inContacts: false, isAllowed: false);
  }

  void _patchPeerRelationship(
    AuthController auth,
    PeerRelationship relationship,
  ) {
    auth.patchActivePeer(_resolvedPeer(auth).withRelationship(relationship));
  }

  Future<void> _refreshRelationship() async {
    if (_refreshing) return;
    final auth = context.read<AuthController>();
    final session = auth.focusedSession;
    if (session == null) return;

    setState(() => _refreshing = true);
    try {
      final enriched =
          await session.profileService.getPeerContext(widget.peer.profileId);
      if (!mounted || enriched?.relationship == null) return;

      final current = _resolvedPeer(auth);
      final next = enriched!.relationship!;
      if (current.relationship?.inContacts == next.inContacts &&
          current.relationship?.isAllowed == next.isAllowed) {
        return;
      }
      _patchPeerRelationship(auth, next);
    } catch (_) {
      // Menu resta utilizzabile con i flag già noti.
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  bool _isDuplicateContactError(Object error) {
    if (error is PostgrestException) {
      return error.code == '23505';
    }
    final message = error.toString().toLowerCase();
    return message.contains('23505') || message.contains('duplicate');
  }

  Future<void> _toggleRubrica({
    required AuthController auth,
    required bool inRubrica,
  }) async {
    final contacts = context.read<ContactsController?>();
    if (contacts == null || _busy) return;

    setState(() => _busy = true);
    try {
      if (inRubrica) {
        await contacts.removeInternalByProfileId(widget.peer.profileId);
      } else {
        await contacts.addInternal(_resolvedPeer(auth).profile);
      }
      if (mounted) {
        _patchPeerRelationship(
          auth,
          _relationshipFor(_resolvedPeer(auth)).copyWith(inContacts: !inRubrica),
        );
      }
    } catch (e) {
      if (!inRubrica && _isDuplicateContactError(e)) {
        if (mounted) {
          _patchPeerRelationship(
            auth,
            _relationshipFor(_resolvedPeer(auth)).copyWith(inContacts: true),
          );
        }
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAllowed(AuthController auth, bool value) async {
    final allowlist = context.read<ReceptionAllowlistController?>();
    if (allowlist == null || _busy) return;

    setState(() => _busy = true);
    try {
      if (value) {
        await allowlist.addProfile(_resolvedPeer(auth).profile);
      } else {
        await allowlist.removeByProfileId(widget.peer.profileId);
      }
      if (mounted) {
        _patchPeerRelationship(
          auth,
          _relationshipFor(_resolvedPeer(auth)).copyWith(isAllowed: value),
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

  Future<void> _openMenu(BuildContext context, AuthController auth) async {
    if (_busy || _refreshing) return;

    await _refreshRelationship();
    if (!context.mounted) return;

    final relationship = _relationshipFor(_resolvedPeer(auth));
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;

    final action = await showMenu<_ChatPeerMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        box.localToGlobal(Offset.zero) & box.size,
        Offset.zero & MediaQuery.sizeOf(context),
      ),
      items: [
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

    if (!context.mounted || action == null) return;

    switch (action) {
      case _ChatPeerMenuAction.rubrica:
        await _toggleRubrica(
          auth: auth,
          inRubrica: relationship.inContacts,
        );
      case _ChatPeerMenuAction.allow:
        await _setAllowed(auth, !relationship.isAllowed);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refreshRelationship());
    });
  }

  @override
  void didUpdateWidget(covariant _ChatPeerOverflowMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.peer.profileId != widget.peer.profileId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_refreshRelationship());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final actionsEnabled = !_busy && !_refreshing;

    return IconButton(
      tooltip: 'Altre azioni',
      onPressed: actionsEnabled ? () => unawaited(_openMenu(context, auth)) : null,
      icon: _refreshing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.more_vert),
    );
  }
}
