// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact.dart';
import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
import '../providers/contacts_controller.dart';
import '../services/compose_service.dart';
import '../theme/alfred_colors.dart';
import '../utils/avatar_color.dart';
import '../widgets/collapsible_list_search.dart';
import '../widgets/peer_profile_overlay.dart';
import '../widgets/profile_identity.dart';
import '../widgets/profile_search_sheet.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  ComposeService? get _composeService =>
      context.read<AuthController>().focusedSession?.composeService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<ContactsController>().load());
    });
  }

  void _startChat(Contact contact) {
    final composeService = _composeService;
    if (composeService == null) return;
    try {
      final peer = composeService.peerFromContact(contact);
      Navigator.pop(context, peer);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('StateError: ', ''))),
      );
    }
  }

  Future<void> _showAddContact() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddContactSheet(
        onSearch: (query) =>
            ctx.read<ContactsController>().searchProfiles(query),
        onAddInternal: (profile) async {
          await ctx.read<ContactsController>().addInternal(profile);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<ContactsController>();

    return CollapsibleListSearch(
      hintText: 'Cerca contatto',
      onSearchChanged: contacts.setSearchQuery,
      lensIconColor: AlfredColors.textOnDark,
      builder: (context, search) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Contatti'),
            backgroundColor: AlfredColors.charcoal,
            foregroundColor: AlfredColors.textOnDark,
            actions: [
              search.lensButton,
              IconButton(
                onPressed: _showAddContact,
                icon: const Icon(Icons.person_add_outlined),
              ),
            ],
          ),
          body: Column(
            children: [
              search.field,
              Expanded(
                child: contacts.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: contacts.filteredContacts.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final contact = contacts.filteredContacts[index];
                          final internalProfile = contact.internalProfileSummary;
                          return ListTile(
                            leading: internalProfile != null
                                ? ProfileAvatar(
                                    profile: internalProfile,
                                    onTap: () => showPeerProfileOverlay(
                                      context,
                                      internalProfile,
                                    ),
                                  )
                                : CircleAvatar(
                                    child: Text(avatarInitial(contact.displayName)),
                                  ),
                            title: Text(contact.displayName),
                            subtitle: Text(
                              contact.protocol == ContactProtocol.internal
                                  ? 'Utente interno'
                                  : contact.externalAddress ?? '',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.chat_bubble_outline),
                              onPressed: () => _startChat(contact),
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

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({
    required this.onSearch,
    required this.onAddInternal,
  });

  final Future<List<ProfileSummary>> Function(String query) onSearch;
  final Future<void> Function(ProfileSummary profile) onAddInternal;

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _addressController = TextEditingController();
  final _nameController = TextEditingController();
  ContactProtocol _externalProtocol = ContactProtocol.xmpp;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _addressController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = context.read<ContactsController>();
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Interni'),
              Tab(text: 'Esterno'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabs,
              children: [
                ProfileSearchSheet(
                  embedded: true,
                  onSearch: widget.onSearch,
                  onProfileSelected: widget.onAddInternal,
                ),
                Column(
                  children: [
                    DropdownButtonFormField<ContactProtocol>(
                      initialValue: _externalProtocol,
                      decoration: const InputDecoration(labelText: 'Tipo'),
                      items: const [
                        DropdownMenuItem(
                          value: ContactProtocol.xmpp,
                          child: Text('XMPP (JID)'),
                        ),
                        DropdownMenuItem(
                          value: ContactProtocol.matrix,
                          child: Text('Matrix'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _externalProtocol = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome visualizzato',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: _externalProtocol == ContactProtocol.xmpp
                            ? 'JID (es. mario@dominio.it)'
                            : 'ID Matrix',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        await contacts.addExternal(
                          protocol: _externalProtocol,
                          address: _addressController.text.trim(),
                          displayName: _nameController.text.trim(),
                        );
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: const Text('Aggiungi contatto'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
