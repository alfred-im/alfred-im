import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile_summary.dart';
import '../models/saved_account.dart';
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
    final otherAccounts = auth.savedAccounts
        .where((a) => a.userId != activeUserId)
        .toList();

    return ColoredBox(
      color: AlfredColors.panel,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(12, compact ? 8 : 16, 12, 16),
          children: [
            if (profile != null && activeUserId != null)
              _ActiveProfileCard(profile: profile)
            else
              const ListTile(
                leading: CircularProgressIndicator(strokeWidth: 2),
                title: Text('Caricamento profilo…'),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEditProfile,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Modifica profilo'),
              ),
            ),
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
                  onTap: () => _switchAccount(context, account),
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

  Future<void> _switchAccount(BuildContext context, SavedAccount account) async {
    final messenger = ScaffoldMessenger.of(context);
    final auth = context.read<AuthController>();
    final ok = await auth.switchAccount(account);
    if (!ok && auth.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(auth.error!)));
      return;
    }
    onAccountSwitched?.call();
  }
}

class _ActiveProfileCard extends StatelessWidget {
  const _ActiveProfileCard({required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileAvatar(profile: profile, radius: 28, fontSize: 22),
        const SizedBox(width: 12),
        Expanded(
          child: ProfileIdentityLines(
            profile: profile,
            nameStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: AlfredColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.logout_outlined, size: 22),
          color: AlfredColors.textSecondary,
          tooltip: 'Esci',
          onPressed: () => context.read<AuthController>().signOut(),
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

  final SavedAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ProfileAvatar(profile: account.profile, radius: 20, fontSize: 16),
      title: Text(account.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
