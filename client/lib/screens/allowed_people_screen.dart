import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allowed_person.dart';
import '../models/profile_summary.dart';
import '../providers/reception_allowlist_controller.dart';
import '../theme/alfred_colors.dart';
import '../widgets/collapsible_list_search.dart';
import '../widgets/peer_profile_overlay.dart';
import '../widgets/profile_identity.dart';

class AllowedPeopleScreen extends StatefulWidget {
  const AllowedPeopleScreen({super.key});

  @override
  State<AllowedPeopleScreen> createState() => _AllowedPeopleScreenState();
}

class _AllowedPeopleScreenState extends State<AllowedPeopleScreen> {
  Future<void> _showAddPerson() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _AddAllowedPersonSheet(),
    );
  }

  Future<void> _confirmRemove(AllowedPerson person) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rimuovere dalla lista?'),
        content: Text(
          '${person.displayName} non potrà più inviarti nuovi messaggi finché non la aggiungi di nuovo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rimuovi'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final controller = context.read<ReceptionAllowlistController>();
    try {
      await controller.remove(person);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowlist = context.watch<ReceptionAllowlistController>();

    return CollapsibleListSearch(
      hintText: 'Cerca nella lista',
      onSearchChanged: allowlist.setSearchQuery,
      lensIconColor: AlfredColors.textOnDark,
      builder: (context, search) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Persone consentite'),
            backgroundColor: AlfredColors.charcoal,
            foregroundColor: AlfredColors.textOnDark,
            actions: [
              search.lensButton,
              IconButton(
                onPressed: _showAddPerson,
                icon: const Icon(Icons.person_add_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              search.field,
              if (!allowlist.isLoading && allowlist.allowedPeople.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Text(
                    'Nessuno può consegnarti messaggi finché non aggiungi qualcuno a questa lista.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AlfredColors.textSecondary,
                        ),
                  ),
                ),
              Expanded(
                child: allowlist.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : allowlist.error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                allowlist.error!,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: allowlist.filteredAllowedPeople.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final person =
                                  allowlist.filteredAllowedPeople[index];
                              return ListTile(
                                leading: ProfileAvatar(
                                  profile: person.profile,
                                  onTap: () => showPeerProfileOverlay(
                                    context,
                                    person.profile,
                                  ),
                                ),
                                title: Text(person.displayName),
                                subtitle: person.profile.hasUsername
                                    ? Text(
                                        person.profile.handle,
                                        style: const TextStyle(fontSize: 12),
                                      )
                                    : null,
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  tooltip: 'Rimuovi',
                                  onPressed: () => _confirmRemove(person),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AddAllowedPersonSheet extends StatefulWidget {
  const _AddAllowedPersonSheet();

  @override
  State<_AddAllowedPersonSheet> createState() => _AddAllowedPersonSheetState();
}

class _AddAllowedPersonSheetState extends State<_AddAllowedPersonSheet> {
  final _searchController = TextEditingController();
  List<ProfileSummary> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    final allowlist = context.read<ReceptionAllowlistController>();
    final results = await allowlist.searchProfiles(_searchController.text);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowlist = context.watch<ReceptionAllowlistController>();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final alreadyAllowed = allowlist.allowedProfileIds;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Aggiungi persona consentita',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cerca utente Alfred',
              suffixIcon: IconButton(
                onPressed: _search,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _search(),
          ),
          const SizedBox(height: 8),
          if (_searching) const LinearProgressIndicator(),
          SizedBox(
            height: 280,
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final profile = _results[index];
                final isAllowed = alreadyAllowed.contains(profile.id);
                return ListTile(
                  leading: ProfileAvatar(profile: profile),
                  title: Text(profile.displayName),
                  subtitle: Text(profile.handle),
                  trailing: isAllowed
                      ? const Icon(Icons.check, color: AlfredColors.textSecondary)
                      : null,
                  enabled: !isAllowed,
                  onTap: isAllowed
                      ? null
                      : () async {
                          try {
                            await allowlist.addProfile(profile);
                            if (context.mounted) Navigator.pop(context);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
