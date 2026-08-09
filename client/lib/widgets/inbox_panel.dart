// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/chat_peer.dart';
import '../models/profile_summary.dart';
import '../theme/alfred_colors.dart';
import '../utils/compose_address.dart';
import 'account_shell_header.dart';
import 'collapsible_list_search.dart';
import 'inbox_peer_tile.dart';

class InboxPanel extends StatefulWidget {
  const InboxPanel({
    super.key,
    required this.selectedPeerId,
    required this.peers,
    required this.isLoading,
    required this.onSelected,
    required this.onSearchChanged,
    required this.onContactsTap,
    this.onAllowedPeopleTap,
    this.onNewMessage,
    this.onDrawerTap,
    this.drawerProfile,
    this.error,
    this.onRetry,
    this.showBackButton = false,
    this.onBack,
    this.showTopBar = true,
  });

  final String? selectedPeerId;
  final List<ChatPeer> peers;
  final bool isLoading;
  final ValueChanged<ChatPeer> onSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onDrawerTap;
  final ProfileSummary? drawerProfile;
  final VoidCallback onContactsTap;
  final VoidCallback? onAllowedPeopleTap;
  final Future<void> Function(String address)? onNewMessage;
  final String? error;
  final VoidCallback? onRetry;
  final bool showBackButton;
  final VoidCallback? onBack;
  final bool showTopBar;

  @override
  State<InboxPanel> createState() => _InboxPanelState();
}

class _InboxPanelState extends State<InboxPanel> {
  @override
  Widget build(BuildContext context) {
    return CollapsibleListSearch(
      hintText: 'Cerca messaggi',
      onSearchChanged: widget.onSearchChanged,
      lensIconColor:
          widget.showTopBar ? AlfredColors.textOnDark : null,
      builder: (context, search) {
        return Stack(
          children: [
            ColoredBox(
              color: AlfredColors.panel,
              child: Column(
                children: [
                  if (widget.showTopBar)
                    AccountShellHeader(
                      title: 'Alfred',
                      titleStyle: const TextStyle(
                        color: AlfredColors.textOnDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      backgroundColor: AlfredColors.charcoal,
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                      showBackButton: widget.showBackButton,
                      onBack: widget.onBack,
                      drawerProfile: widget.drawerProfile,
                      onDrawerTap: widget.onDrawerTap,
                      actions: [
                        search.lensButton,
                        if (widget.onAllowedPeopleTap != null)
                          IconButton(
                            onPressed: widget.onAllowedPeopleTap,
                            icon: const Icon(
                              Icons.verified_user_outlined,
                              color: AlfredColors.textOnDark,
                            ),
                            tooltip: 'Persone consentite',
                          ),
                        IconButton(
                          onPressed: widget.onContactsTap,
                          icon: const Icon(
                            Icons.people_outline,
                            color: AlfredColors.textOnDark,
                          ),
                          tooltip: 'Contatti',
                        ),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 4, 0),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Conversazioni',
                              style: TextStyle(
                                color: AlfredColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          search.lensButton,
                          if (widget.onAllowedPeopleTap != null)
                            IconButton(
                              onPressed: widget.onAllowedPeopleTap,
                              icon: const Icon(Icons.verified_user_outlined),
                              tooltip: 'Persone consentite',
                            ),
                          IconButton(
                            onPressed: widget.onContactsTap,
                            icon: const Icon(Icons.people_outline),
                            tooltip: 'Contatti',
                          ),
                        ],
                      ),
                    ),
                  search.field,
                  const Divider(height: 1),
                  Expanded(
                    child: widget.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : widget.error != null
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        widget.error!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: AlfredColors.textSecondary,
                                        ),
                                      ),
                                      if (widget.onRetry != null) ...[
                                        const SizedBox(height: 16),
                                        FilledButton(
                                          onPressed: widget.onRetry,
                                          child: const Text('Riprova'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              )
                            : widget.peers.isEmpty
                                ? const Center(
                                    child: Text(
                                      'Nessun messaggio.\nUsa + per scrivere a un indirizzo.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: AlfredColors.textSecondary,
                                      ),
                                    ),
                                  )
                                : ListView.separated(
                                    itemCount: widget.peers.length,
                                    separatorBuilder: (_, _) =>
                                        const Divider(height: 1, indent: 76),
                                    itemBuilder: (context, index) {
                                      final peer = widget.peers[index];
                                      return InboxPeerTile(
                                        peer: peer,
                                        selected:
                                            peer.profileId == widget.selectedPeerId,
                                        onTap: () => widget.onSelected(peer),
                                      );
                                    },
                                  ),
                  ),
                ],
              ),
            ),
            if (widget.onNewMessage != null)
              Positioned(
                right: 16,
                bottom: 16,
                child: FloatingActionButton(
                  onPressed: () => _showNewMessageDialog(context),
                  backgroundColor: AlfredColors.unreadBadge,
                  foregroundColor: AlfredColors.textOnDark,
                  tooltip: 'Nuovo messaggio',
                  child: const Icon(Icons.chat_outlined),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showNewMessageDialog(BuildContext context) async {
    final onNewMessage = widget.onNewMessage;
    if (onNewMessage == null) return;

    final address = await showDialog<String>(
      context: context,
      builder: (ctx) => const _NewMessageDialog(),
    );

    if (address == null || address.trim().isEmpty || !context.mounted) return;
    await onNewMessage(address.trim());
  }
}

class _NewMessageDialog extends StatefulWidget {
  const _NewMessageDialog();

  @override
  State<_NewMessageDialog> createState() => _NewMessageDialogState();
}

class _NewMessageDialogState extends State<_NewMessageDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pop(context, _controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuovo messaggio'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Indirizzo',
            hintText: 'mario_rossi o mario@dominio.it',
          ),
          onFieldSubmitted: (_) => _submit(),
          validator: validateComposeAddressInput,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Continua'),
        ),
      ],
    );
  }
}
