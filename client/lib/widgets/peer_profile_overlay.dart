// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
import '../models/message.dart';
import '../models/peer_relationship.dart';
import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
import '../providers/contacts_controller.dart';
import '../providers/reception_allowlist_controller.dart';
import '../theme/alfred_colors.dart';
import '../utils/peer_relationship_actions.dart';
import '../utils/shareable_link.dart';
import 'profile_cover_header.dart';

/// Apre la scheda profilo peer se [profile] non è l'account in focus.
Future<void> showPeerProfileOverlay(
  BuildContext context,
  ProfileSummary profile,
) async {
  final focusUserId = context.read<AuthController>().userId;
  if (focusUserId == null || focusUserId == profile.id) return;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Chiudi profilo',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (context, animation, secondaryAnimation) {
      return PeerProfileOverlay(profile: profile);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

extension ChatMessageAuthorProfile on ChatMessage {
  ProfileSummary? toAuthorProfileSummary() {
    final id = authorProfileId ?? contentAuthorId;
    final name = authorDisplayName?.trim();
    if (id == null || name == null || name.isEmpty) return null;
    return ProfileSummary(
      id: id,
      displayName: name,
      avatarUrl: authorAvatarUrl,
    );
  }
}

class PeerProfileOverlay extends StatefulWidget {
  const PeerProfileOverlay({super.key, required this.profile});

  final ProfileSummary profile;

  @override
  State<PeerProfileOverlay> createState() => _PeerProfileOverlayState();
}

class _PeerProfileOverlayState extends State<PeerProfileOverlay> {
  bool _allowBusy = false;
  bool _rubricaBusy = false;
  bool _moderationBusy = false;
  late ProfileSummary _profile;
  bool _peerIsDisabled = false;
  bool _hydrateStarted = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hydrateStarted) return;
    _hydrateStarted = true;
    unawaited(_hydrateProfileFromServer());
    unawaited(PeerRelationshipActions.prime(context));
    unawaited(_resolveOwnerCapability());
  }

  Future<void> _resolveOwnerCapability() async {
    AuthController? auth;
    try {
      auth = context.read<AuthController>();
    } on ProviderNotFoundException {
      return;
    }
    final session = auth.focusedSession;
    if (session == null) return;

    try {
      final isOwner = await session.ownerService.isInstanceOwner();
      if (!mounted) return;
      setState(() {
        _serverIsOwner = isOwner;
        _ownerCheckDone = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _serverIsOwner = false;
        _ownerCheckDone = true;
      });
    }
  }

  Future<void> _hydrateProfileFromServer() async {
    final AuthController auth;
    try {
      auth = context.read<AuthController>();
    } on ProviderNotFoundException {
      return;
    }

    final session = auth.focusedSession;
    if (session == null) return;

    try {
      final peer = await session.profileService.getPeerContext(widget.profile.id);
      if (!mounted || peer == null) return;
      setState(() {
        _profile = widget.profile.mergeDisplay(peer.profile);
        _peerIsDisabled = peer.peerIsDisabled;
      });
    } catch (_) {
      // Overlay resta utilizzabile con i dati parziali già noti.
    }
  }

  Future<ProfileSummary> _profileForActions() async {
    if (_profile.hasUsername) return _profile;
    await _hydrateProfileFromServer();
    return _profile;
  }

  PeerRelationship _relationshipFor(BuildContext context) {
    return PeerRelationshipActions.relationshipForPeer(
      context,
      profileId: _profile.id,
    );
  }

  void _watchAuthIfPresent(BuildContext context) {
    try {
      context.watch<AuthController>();
    } on ProviderNotFoundException {
      // Harness test senza AuthController.
    }
  }

  bool _serverIsOwner = false;
  bool _ownerCheckDone = false;

  String? _focusedUserId(BuildContext context) {
    try {
      return context.read<AuthController>().focusedSession?.userId;
    } on ProviderNotFoundException {
      return null;
    }
  }

  Future<void> _setAllowed(bool value) async {
    if (_allowBusy) return;

    setState(() => _allowBusy = true);
    try {
      await PeerRelationshipActions.setAllowed(
        context: context,
        profileId: _profile.id,
        profile: _profile,
        value: value,
      );
    } catch (e) {
      if (mounted) PeerRelationshipActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _allowBusy = false);
    }
  }

  Future<void> _toggleRubrica({required bool inRubrica}) async {
    if (_rubricaBusy) return;

    setState(() => _rubricaBusy = true);
    try {
      await PeerRelationshipActions.toggleRubrica(
        context: context,
        profileId: widget.profile.id,
        profile: _profile,
        inRubrica: inRubrica,
      );
    } catch (e) {
      if (mounted) PeerRelationshipActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _rubricaBusy = false);
    }
  }

  Future<void> _startChat() async {
    final auth = context.read<AuthController>();
    final profile = await _profileForActions();
    if (!mounted) return;
    final peer = ChatPeer.fromProfile(
      profile: profile,
      address: profile.username,
    );
    Navigator.of(context).pop();
    auth.openConversation(peer);
  }

  Future<void> _shareProfile({Rect? sharePositionOrigin}) async {
    final profile = await _profileForActions();
    if (!mounted) return;
    return shareShareableProfileLink(
      context,
      profile,
      shareTitle: profile.displayName,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<void> _toggleBan({required bool ban}) async {
    if (_moderationBusy) return;

    AuthController? auth;
    try {
      auth = context.read<AuthController>();
    } on ProviderNotFoundException {
      return;
    }
    final session = auth.focusedSession;
    if (session == null) return;

    final isOwner = await session.ownerService.isInstanceOwner();
    if (!isOwner) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Solo gli account owner possono moderare. '
              'Riaccedi se il ruolo è stato aggiornato.',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    if (ban) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disattiva account'),
          content: Text(
            'Disattivare ${_profile.displayName}? '
            'Non potrà più accedere né inviare messaggi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disattiva'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _moderationBusy = true);
    try {
      if (ban) {
        await session.ownerService.banProfile(_profile.id);
      } else {
        await session.ownerService.unbanProfile(_profile.id);
      }
      if (!mounted) return;
      setState(() => _peerIsDisabled = ban);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ban ? 'Account disattivato' : 'Account riattivato',
          ),
        ),
      );
    } catch (e) {
      if (mounted) PeerRelationshipActions.showError(context, e);
    } finally {
      if (mounted) setState(() => _moderationBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    _watchAuthIfPresent(context);
    context.watch<ReceptionAllowlistController?>();
    context.watch<ContactsController?>();

    final relationship = _relationshipFor(context);
    final isAllowed = relationship.isAllowed;
    final inRubrica = relationship.inContacts;
    final actionsEnabled = PeerRelationshipActions.controllersReady(context);
    final focusedUserId = _focusedUserId(context);
    final canModerate = _ownerCheckDone &&
        _serverIsOwner &&
        !_profile.isOwner &&
        !_profile.isGroup &&
        focusedUserId != null &&
        _profile.id != focusedUserId;

    return Material(
      color: AlfredColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            _ProfileHero(
              profile: profile,
              onClose: () => Navigator.of(context).pop(),
              onShare: _shareProfile,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ActionCard(
                      child: SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        secondary: Icon(
                          Icons.verified_user_outlined,
                          color: isAllowed
                              ? AlfredColors.unreadBadge
                              : AlfredColors.textSecondary,
                        ),
                        title: const Text(
                          'Consenti messaggi',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Chi è in lista può consegnarti messaggi',
                          style: TextStyle(fontSize: 13),
                        ),
                        value: isAllowed,
                        onChanged: actionsEnabled && !_allowBusy
                            ? (value) => _setAllowed(value)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: actionsEnabled && !_rubricaBusy
                          ? () => _toggleRubrica(inRubrica: inRubrica)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: inRubrica
                            ? AlfredColors.charcoalHover
                            : AlfredColors.charcoal,
                        foregroundColor: AlfredColors.textOnDark,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _rubricaBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              inRubrica
                                  ? Icons.person_remove_outlined
                                  : Icons.person_add_alt_1_outlined,
                            ),
                      label: Text(
                        inRubrica
                            ? 'Rimuovi dalla rubrica'
                            : 'Aggiungi alla rubrica',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scorciatoia personale — non abilita invio o ricezione',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AlfredColors.textSecondary,
                          ),
                    ),
                    if (canModerate) ...[
                      const SizedBox(height: 28),
                      Text(
                        'Moderazione',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      _ActionCard(
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          secondary: Icon(
                            Icons.block_outlined,
                            color: _peerIsDisabled
                                ? AlfredColors.unreadBadge
                                : AlfredColors.textSecondary,
                          ),
                          title: const Text(
                            'Account disattivato',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Blocca accesso e messaggistica',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: _peerIsDisabled,
                          onChanged: actionsEnabled && !_moderationBusy
                              ? (value) => unawaited(_toggleBan(ban: value))
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => unawaited(_startChat()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AlfredColors.charcoal,
                    foregroundColor: AlfredColors.textOnDark,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Inizia a chattare'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.onClose,
    required this.onShare,
  });

  final ProfileSummary profile;
  final VoidCallback onClose;
  final void Function({Rect? sharePositionOrigin}) onShare;

  @override
  Widget build(BuildContext context) {
    return ProfileCoverHeader(
      profile: profile,
      heroStyle: ProfileCoverHeroStyle.immersive,
      overlayTopStart: IconButton(
        onPressed: onClose,
        icon: const Icon(Icons.close),
        color: AlfredColors.textOnDark,
        tooltip: 'Chiudi',
      ),
      overlayTopEnd: Builder(
        builder: (buttonContext) => IconButton(
          onPressed: () {
            final box = buttonContext.findRenderObject() as RenderBox?;
            final origin =
                box != null ? box.localToGlobal(Offset.zero) & box.size : null;
            onShare(sharePositionOrigin: origin);
          },
          icon: const Icon(Icons.share_outlined),
          color: AlfredColors.textOnDark,
          tooltip: 'Condividi',
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AlfredColors.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AlfredColors.border),
      ),
      elevation: 0,
      shadowColor: AlfredColors.charcoal.withValues(alpha: 0.06),
      child: child,
    );
  }
}
