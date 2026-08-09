// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'inbox_effects.dart';

/// Stato caricamento inbox.
enum InboxLoadState {
  loading,
  ready,
}

/// Eventi inbox.
sealed class InboxEvent {
  const InboxEvent();
}

final class LoadInbox extends InboxEvent {
  const LoadInbox({this.showLoadingIndicator = true});

  final bool showLoadingIndicator;
}

final class InboxLoaded extends InboxEvent {
  const InboxLoaded();
}

final class InboxLoadFailed extends InboxEvent {
  const InboxLoadFailed();
}

final class SetSearchQuery extends InboxEvent {
  const SetSearchQuery(this.query);

  final String query;
}

/// Interprete statechart inbox.
///
/// Produzione: [InboxCoordinator] + [InboxController].
class InboxMachine {
  InboxMachine(this._effects);

  final InboxEffects _effects;

  InboxLoadState loadState = InboxLoadState.loading;
  String searchQuery = '';
  int _loadGeneration = 0;

  int get currentLoadGeneration => _loadGeneration;

  Future<void> send(InboxEvent event) async {
    switch (event) {
      case LoadInbox(:final showLoadingIndicator):
        final generation = ++_loadGeneration;
        if (showLoadingIndicator) {
          loadState = InboxLoadState.loading;
        }
        await _effects.loadInbox(
          generation: generation,
          showLoadingIndicator: showLoadingIndicator,
        );
      case InboxLoaded():
        loadState = InboxLoadState.ready;
      case InboxLoadFailed():
        loadState = InboxLoadState.ready;
      case SetSearchQuery(:final query):
        searchQuery = query;
    }
  }
}
