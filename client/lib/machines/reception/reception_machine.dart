// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../../models/allowed_person.dart';
import '../../models/profile_summary.dart';
import 'reception_effects.dart';

/// Stato caricamento — `docs/model/uml/reception/reception-allowlist-state.puml`.
enum ReceptionLoadState {
  loading,
  ready,
}

/// Eventi — `docs/domain/reception/commands-and-events.md`.
sealed class ReceptionEvent {
  const ReceptionEvent();
}

final class LoadAllowlist extends ReceptionEvent {
  const LoadAllowlist();
}

final class AllowlistLoaded extends ReceptionEvent {
  const AllowlistLoaded();
}

final class AllowlistLoadFailed extends ReceptionEvent {
  const AllowlistLoadFailed();
}

final class SetAllowlistSearchQuery extends ReceptionEvent {
  const SetAllowlistSearchQuery(this.query);
  final String query;
}

final class AddAllowedProfile extends ReceptionEvent {
  const AddAllowedProfile(this.profile);
  final ProfileSummary profile;
}

final class RemoveAllowedPerson extends ReceptionEvent {
  const RemoveAllowedPerson(this.person);
  final AllowedPerson person;
}

final class RemoveAllowedByProfileId extends ReceptionEvent {
  const RemoveAllowedByProfileId(this.profileId);
  final String profileId;
}

/// Interprete statechart reception — allineato a UML.
///
/// Produzione: [ReceptionCoordinator] + [ReceptionAllowlistController].
class ReceptionMachine {
  ReceptionMachine(this._effects, {required this.ownerId});

  final ReceptionEffects _effects;
  final String ownerId;

  ReceptionLoadState loadState = ReceptionLoadState.loading;
  String searchQuery = '';

  Future<void> send(ReceptionEvent event) async {
    switch (event) {
      case LoadAllowlist():
        loadState = ReceptionLoadState.loading;
        await _effects.loadAllowlist();
      case AllowlistLoaded():
        loadState = ReceptionLoadState.ready;
      case AllowlistLoadFailed():
        loadState = ReceptionLoadState.ready;
      case SetAllowlistSearchQuery(:final query):
        searchQuery = query;
        _effects.onSearchQueryChanged(query);
      case AddAllowedProfile(:final profile):
        if (profile.id == ownerId) return;
        if (_effects.isProfileAllowed(profile.id)) return;
        await _effects.addAllowedProfile(profile);
        await send(const LoadAllowlist());
      case RemoveAllowedPerson(:final person):
        await _effects.removeAllowedPerson(person);
        await send(const LoadAllowlist());
      case RemoveAllowedByProfileId(:final profileId):
        await _effects.removeByProfileId(profileId);
        await send(const LoadAllowlist());
    }
  }
}
