import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_peer.dart';
import '../models/message.dart';
import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
import '../providers/contacts_controller.dart';
import '../providers/reception_allowlist_controller.dart';
import '../theme/alfred_colors.dart';
import '../utils/shareable_link.dart';
import 'profile_identity.dart';

/// Apre la scheda profilo peer se [profile] non è l'account in focus.
Future<void> showPeerProfileOverlay(
  BuildContext context,
  ProfileSummary profile,
) async {
  final ownerId = context.read<AuthController>().userId;
  if (ownerId == null || ownerId == profile.id) return;

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
  late ProfileSummary _profile;
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
      final fromServer =
          await session.profileService.findById(widget.profile.id);
      if (!mounted || fromServer == null) return;
      setState(() => _profile = widget.profile.mergeDisplay(fromServer));
    } catch (_) {
      // Overlay resta utilizzabile con i dati parziali già noti.
    }
  }

  Future<ProfileSummary> _profileForActions() async {
    if (_profile.hasUsername) return _profile;
    await _hydrateProfileFromServer();
    return _profile;
  }

  Future<void> _setAllowed(bool value) async {
    final allowlist = context.read<ReceptionAllowlistController?>();
    if (allowlist == null || _allowBusy) return;

    setState(() => _allowBusy = true);
    try {
      if (value) {
        await allowlist.addProfile(_profile);
      } else {
        await allowlist.removeByProfileId(_profile.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _allowBusy = false);
    }
  }

  Future<void> _toggleRubrica({required bool inRubrica}) async {
    final contacts = context.read<ContactsController?>();
    if (contacts == null || _rubricaBusy) return;

    setState(() => _rubricaBusy = true);
    try {
      if (inRubrica) {
        await contacts.removeInternalByProfileId(widget.profile.id);
      } else {
        await contacts.addInternal(_profile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final allowlist = context.watch<ReceptionAllowlistController?>();
    final contacts = context.watch<ContactsController?>();

    final isAllowed =
        allowlist?.allowedProfileIds.contains(profile.id) ?? false;
    final inRubrica = contacts?.contactForProfileId(profile.id) != null;
    final actionsEnabled = allowlist != null && contacts != null;

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
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AlfredColors.charcoal,
            AlfredColors.charcoalActive,
          ],
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 3,
                    ),
                  ),
                  child: ProfileAvatar(
                    profile: profile,
                    radius: 56,
                    fontSize: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  profile.displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AlfredColors.textOnDark,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (profile.hasUsername) ...[
                  const SizedBox(height: 6),
                  Text(
                    profile.handle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 16,
                    ),
                  ),
                ],
                if (profile.hasPronouns) ...[
                  const SizedBox(height: 8),
                  Text(
                    profile.pronouns!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 14,
                    ),
                  ),
                ],
                if (profile.isGroup) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Account gruppo',
                      style: TextStyle(
                        color: AlfredColors.textOnDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              color: AlfredColors.textOnDark,
              tooltip: 'Chiudi',
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Builder(
              builder: (buttonContext) => IconButton(
                onPressed: () {
                  final box = buttonContext.findRenderObject() as RenderBox?;
                  final origin = box != null
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null;
                  onShare(sharePositionOrigin: origin);
                },
                icon: const Icon(Icons.share_outlined),
                color: AlfredColors.textOnDark,
                tooltip: 'Condividi',
              ),
            ),
          ),
        ],
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
