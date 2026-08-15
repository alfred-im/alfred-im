// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../models/profile_summary.dart';
import 'profile_identity.dart';

/// Ricerca profili Alfred in bottom sheet (contatti, allow list, ecc.).
class ProfileSearchSheet extends StatefulWidget {
  const ProfileSearchSheet({
    super.key,
    this.title,
    required this.onSearch,
    required this.onProfileSelected,
    this.isProfileSelectable,
    this.profileTrailing,
    this.showAvatar = false,
    this.resultsHeight = 280,
    this.embedded = false,
  });

  final String? title;
  final Future<List<ProfileSummary>> Function(String query) onSearch;
  final Future<void> Function(ProfileSummary profile) onProfileSelected;
  final bool Function(ProfileSummary profile)? isProfileSelectable;
  final Widget? Function(ProfileSummary profile)? profileTrailing;
  final bool showAvatar;
  final double resultsHeight;
  final bool embedded;

  @override
  State<ProfileSearchSheet> createState() => _ProfileSearchSheetState();
}

class _ProfileSearchSheetState extends State<ProfileSearchSheet> {
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
    final results = await widget.onSearch(_searchController.text);
    if (mounted) {
      setState(() {
        _results = results;
        _searching = false;
      });
    }
  }

  Widget _buildResultsList() {
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final profile = _results[index];
        final selectable =
            widget.isProfileSelectable?.call(profile) ?? true;
        final trailing = widget.profileTrailing?.call(profile);

        return ListTile(
          leading: widget.showAvatar ? ProfileAvatar(profile: profile) : null,
          title: Text(profile.displayName),
          subtitle: Text(profile.handle),
          trailing: trailing,
          enabled: selectable,
          onTap: selectable
              ? () async {
                  await widget.onProfileSelected(profile);
                }
              : null,
        );
      },
    );
  }

  Widget _buildBody() {
    final results = widget.embedded
        ? Expanded(child: _buildResultsList())
        : SizedBox(
            height: widget.resultsHeight,
            child: _buildResultsList(),
          );

    return Column(
      mainAxisSize: widget.embedded ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Cerca utente su questo server',
            suffixIcon: IconButton(
              onPressed: _search,
              icon: const Icon(Icons.search),
            ),
          ),
          onSubmitted: (_) => _search(),
        ),
        const SizedBox(height: 8),
        if (_searching) const LinearProgressIndicator(),
        results,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return _buildBody();
    }

    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: _buildBody(),
    );
  }
}
