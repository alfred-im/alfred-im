// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/open_account.dart';
import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
import '../theme/alfred_colors.dart';
import '../utils/shareable_link.dart';
import 'profile_cover_header.dart';
import 'profile_identity.dart';

/// Sezione profilo e account nella sidebar / drawer.
class AccountSidebar extends StatelessWidget {
  const AccountSidebar({
    super.key,
    required this.onEditProfile,
    required this.onAddAccount,
    this.onAccountSwitched,
    this.compact = false,
  });

  final VoidCallback onEditProfile;
  final VoidCallback onAddAccount;
  final VoidCallback? onAccountSwitched;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profile = auth.focusedProfileSummary;
    final activeUserId = auth.userId;
    final activeDisconnected = auth.isFocusedAccountDisconnected;
    final otherAccounts = auth.openAccounts
        .where((a) => a.userId != activeUserId)
        .toList();

    return Material(
      color: AlfredColors.panel,
      child: SafeArea(
        child: ListView(
          shrinkWrap: compact,
          physics: compact ? const NeverScrollableScrollPhysics() : null,
          padding: EdgeInsets.fromLTRB(12, compact ? 8 : 16, 12, 16),
          children: [
            if (profile != null && activeUserId != null)
              _ActiveProfileCard(
                profile: profile,
                userId: activeUserId,
                isDisconnected: activeDisconnected,
                manifestUsername: auth.openAccounts
                    .where((a) => a.userId == activeUserId)
                    .map((a) => a.username)
                    .firstWhere(
                      (username) => username.isNotEmpty,
                      orElse: () => '',
                    ),
              )
            else
              const ListTile(
                leading: Icon(Icons.person_outline),
                title: Text('Nessun account in primo piano'),
                subtitle: Text('Apri un account per iniziare'),
              ),
            if (activeUserId != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onEditProfile,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Modifica profilo'),
                ),
              ),
            ],
            if (otherAccounts.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Altri account',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AlfredColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              ...otherAccounts.map(
                (account) => _AccountTile(
                  account: account,
                  onTap: () => _switchFocus(context, account),
                  onReconnect: account.isDisconnected
                      ? () => context
                          .read<AuthController>()
                          .promptReconnectFocusedAccount()
                      : null,
                ),
              ),
            ],
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: const Text('Aggiungi account'),
              contentPadding: EdgeInsets.zero,
              onTap: onAddAccount,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchFocus(BuildContext context, OpenAccount account) async {
    await context.read<AuthController>().setFocus(account.userId);
    if (!context.mounted) return;
    if (account.isDisconnected) {
      context.read<AuthController>().promptReconnectFocusedAccount();
    }
    onAccountSwitched?.call();
  }
}

class _ActiveProfileCard extends StatelessWidget {
  const _ActiveProfileCard({
    required this.profile,
    required this.userId,
    required this.manifestUsername,
    this.isDisconnected = false,
  });

  final ProfileSummary profile;
  final String userId;
  final String manifestUsername;
  final bool isDisconnected;

  @override
  Widget build(BuildContext context) {
    return ProfileCoverHeader(
      profile: profile,
      presentation: ProfileCoverPresentation.compact,
      showPronouns: false,
      extraBelowIdentity: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDisconnected)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Disconnesso',
                style: TextStyle(
                  fontSize: 12,
                  color: AlfredColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (profile.isGroup)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                'Gruppo',
                style: TextStyle(
                  fontSize: 12,
                  color: AlfredColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Builder(
            builder: (buttonContext) => IconButton(
              icon: const Icon(Icons.share_outlined, size: 22),
              color: AlfredColors.textSecondary,
              tooltip: 'Condividi',
              onPressed: () {
                final box = buttonContext.findRenderObject() as RenderBox?;
                final origin = box != null
                    ? box.localToGlobal(Offset.zero) & box.size
                    : null;
                shareShareableProfileLink(
                  context,
                  profileForSharing(
                    profile,
                    fallbackUsername: manifestUsername,
                  ),
                  shareTitle: profile.displayName,
                  sharePositionOrigin: origin,
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, size: 22),
            color: AlfredColors.textSecondary,
            tooltip: 'Chiudi account',
            onPressed: () =>
                context.read<AuthController>().removeAccount(userId),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onTap,
    this.onReconnect,
  });

  final OpenAccount account;
  final VoidCallback onTap;
  final VoidCallback? onReconnect;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ProfileAvatar(
        profile: account.profile,
        radius: 20,
        fontSize: 16,
      ),
      title: Text(account.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (account.isDisconnected)
            const Text(
              'Disconnesso',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AlfredColors.textSecondary,
              ),
            ),
          if (account.profile.isGroup)
            const Text(
              'Gruppo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AlfredColors.textSecondary,
              ),
            ),
          if (account.profile.hasUsername) Text(account.profile.handle),
          if (account.profile.hasPronouns)
            Text(
              account.profile.pronouns!,
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
      isThreeLine: account.isDisconnected ||
          account.profile.isGroup ||
          account.profile.hasPronouns,
      contentPadding: EdgeInsets.zero,
      onTap: account.isDisconnected ? onReconnect ?? onTap : onTap,
    );
  }
}
