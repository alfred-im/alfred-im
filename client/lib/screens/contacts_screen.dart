import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/contact.dart';
import '../providers/contacts_controller.dart';
import '../services/compose_service.dart';
import '../theme/alfred_colors.dart';
import '../utils/avatar_color.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  final _composeService = ComposeService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _startChat(Contact contact) {
    try {
      final peer = _composeService.peerFromContact(contact);
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
      builder: (ctx) => const _AddContactSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contacts = context.watch<ContactsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contatti'),
        backgroundColor: AlfredColors.charcoal,
        foregroundColor: AlfredColors.textOnDark,
        actions: [
          IconButton(
            onPressed: _showAddContact,
            icon: const Icon(Icons.person_add_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: contacts.setSearchQuery,
              decoration: const InputDecoration(
                hintText: 'Cerca contatto',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: contacts.isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: contacts.filteredContacts.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final contact = contacts.filteredContacts[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(avatarInitial(contact.displayName)),
                        ),
                        title: Text(contact.displayName),
                        subtitle: Text(
                          contact.protocol == ContactProtocol.internal
                              ? 'Utente Alfred'
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
  }
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet();

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchController = TextEditingController();
  final _addressController = TextEditingController();
  final _nameController = TextEditingController();
  ContactProtocol _externalProtocol = ContactProtocol.xmpp;
  List<ProfileSearchResult> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    _addressController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    final contacts = context.read<ContactsController>();
    final results = await contacts.searchProfiles(_searchController.text);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
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
              Tab(text: 'Alfred'),
              Tab(text: 'Esterno'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabs,
              children: [
                Column(
                  children: [
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
                    Expanded(
                      child: ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final profile = _results[index];
                          return ListTile(
                            title: Text(profile.displayName),
                            subtitle: Text('@${profile.username}'),
                            onTap: () async {
                              await contacts.addInternal(profile);
                              if (context.mounted) Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
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
