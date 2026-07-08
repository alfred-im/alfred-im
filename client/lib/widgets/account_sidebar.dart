import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/open_account.dart';
import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
import '../theme/alfred_colors.dart';
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
    final profile = auth.profile?.summary;
    final activeUserId = auth.userId;
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
              _ActiveProfileCard(profile: profile, userId: activeUserId)
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
    onAccountSwitched?.call();
  }
}

class _ActiveProfileCard extends StatelessWidget {
  const _ActiveProfileCard({
    required this.profile,
    required this.userId,
  });

  final ProfileSummary profile;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileAvatar(profile: profile, radius: 28, fontSize: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileIdentityLines(
                profile: profile,
                nameStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: AlfredColors.textPrimary,
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
        ),
        IconButton(
          icon: const Icon(Icons.logout_outlined, size: 22),
          color: AlfredColors.textSecondary,
          tooltip: 'Chiudi account',
          onPressed: () => context.read<AuthController>().removeAccount(userId),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.onTap,
  });

  final OpenAccount account;
  final VoidCallback onTap;

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
      isThreeLine: account.profile.hasPronouns,
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
    );
  }
}
