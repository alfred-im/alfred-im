// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allowed_person.dart';
import '../providers/reception_allowlist_controller.dart';
import '../theme/alfred_colors.dart';
import '../widgets/collapsible_list_search.dart';
import '../widgets/peer_profile_overlay.dart';
import '../widgets/profile_identity.dart';
import '../widgets/profile_search_sheet.dart';

class AllowedPeopleScreen extends StatefulWidget {
  const AllowedPeopleScreen({super.key});

  @override
  State<AllowedPeopleScreen> createState() => _AllowedPeopleScreenState();
}

class _AllowedPeopleScreenState extends State<AllowedPeopleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<ReceptionAllowlistController>().ensureLoaded());
    });
  }

  Future<void> _showAddPerson() async {
    final allowlist = context.read<ReceptionAllowlistController>();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => ProfileSearchSheet(
        title: 'Aggiungi persona consentita',
        showAvatar: true,
        onSearch: allowlist.searchProfiles,
        isProfileSelectable: (profile) =>
            !allowlist.allowedProfileIds.contains(profile.id),
        profileTrailing: (profile) {
          if (allowlist.allowedProfileIds.contains(profile.id)) {
            return const Icon(Icons.check, color: AlfredColors.textSecondary);
          }
          return null;
        },
        onProfileSelected: (profile) async {
          try {
            await allowlist.addProfile(profile);
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (e) {
            if (!ctx.mounted) return;
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
        },
      ),
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
