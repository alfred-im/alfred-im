import 'package:flutter/material.dart';

import '../theme/alfred_colors.dart';

/// Ricerca on-demand su lista — [PROM-LIST-FILTER].
class CollapsibleListSearch extends StatefulWidget {
  const CollapsibleListSearch({
    super.key,
    required this.hintText,
    required this.onSearchChanged,
    required this.builder,
    this.lensIconColor,
    this.fieldPadding = const EdgeInsets.fromLTRB(12, 0, 12, 8),
  });

  final String hintText;
  final ValueChanged<String> onSearchChanged;
  final Color? lensIconColor;
  final EdgeInsets fieldPadding;
  final Widget Function(BuildContext context, CollapsibleListSearchParts parts)
      builder;

  @override
  State<CollapsibleListSearch> createState() => _CollapsibleListSearchState();
}

class CollapsibleListSearchParts {
  const CollapsibleListSearchParts({
    required this.lensButton,
    required this.field,
  });

  final Widget lensButton;
  final Widget field;
}

class _CollapsibleListSearchState extends State<CollapsibleListSearch> {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _searchTapRegionGroup = Object();
  bool _searchVisible = false;

  @override
  void dispose() {
    if (_searchVisible || _searchController.text.isNotEmpty) {
      widget.onSearchChanged('');
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void dismissSearch() {
    final hadQuery = _searchController.text.isNotEmpty;
    _searchController.clear();
    _searchFocusNode.unfocus();
    if (hadQuery) {
      widget.onSearchChanged('');
    }
    if (_searchVisible) {
      setState(() => _searchVisible = false);
    }
  }

  void _toggleSearch() {
    if (_searchVisible) {
      dismissSearch();
      return;
    }
    setState(() => _searchVisible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  Widget _buildLensButton() {
    return TapRegion(
      groupId: _searchTapRegionGroup,
      child: IconButton(
        onPressed: _toggleSearch,
        icon: Icon(Icons.search, color: widget.lensIconColor),
        tooltip: widget.hintText,
      ),
    );
  }

  Widget _buildField() {
    if (!_searchVisible) return const SizedBox.shrink();

    return Padding(
      padding: widget.fieldPadding,
      child: TapRegion(
        groupId: _searchTapRegionGroup,
        onTapOutside: (_) => dismissSearch(),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: widget.onSearchChanged,
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(
              Icons.search,
              color: widget.lensIconColor ?? AlfredColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      CollapsibleListSearchParts(
        lensButton: _buildLensButton(),
        field: _buildField(),
      ),
    );
  }
}
