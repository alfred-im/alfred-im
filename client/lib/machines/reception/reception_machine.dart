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

final class SetSearchQuery extends ReceptionEvent {
  const SetSearchQuery(this.query);
  final String query;
}

final class AddAllowedAddress extends ReceptionEvent {
  const AddAllowedAddress(this.address);
  final String address;
}

final class AddAllowedProfile extends ReceptionEvent {
  const AddAllowedProfile(this.profile);
  final ProfileSummary profile;
}

final class RemoveAllowedPerson extends ReceptionEvent {
  const RemoveAllowedPerson(this.person);
  final AllowedPerson person;
}

final class RemoveAllowedByAddress extends ReceptionEvent {
  const RemoveAllowedByAddress(this.address);
  final String address;
}

/// Interprete statechart reception — allineato a UML.
///
/// Produzione: [ReceptionCoordinator] + [ReceptionAllowlistController].
class ReceptionMachine {
  ReceptionMachine(
    this._effects, {
    required this.focusUserId,
    this.focusAccountAddress,
  });

  final ReceptionEffects _effects;
  final String focusUserId;
  final String? focusAccountAddress;

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
      case SetSearchQuery(:final query):
        searchQuery = query;
      case AddAllowedAddress(:final address):
        final normalized = address.trim().toLowerCase();
        if (normalized.isEmpty) return;
        if (_isSelfAddress(normalized)) return;
        if (_effects.isAddressAllowed(normalized)) return;
        await _effects.addAllowedAddress(normalized);
        await send(const LoadAllowlist());
      case AddAllowedProfile(:final profile):
        final address = profile.address ?? profile.username;
        if (address == null || address.isEmpty) return;
        if (profile.id == focusUserId) return;
        if (_isSelfAddress(address.trim().toLowerCase())) return;
        await send(AddAllowedAddress(address));
      case RemoveAllowedPerson(:final person):
        await _effects.removeAllowedPerson(person);
        await send(const LoadAllowlist());
      case RemoveAllowedByAddress(:final address):
        await _effects.removeByAddress(address);
        await send(const LoadAllowlist());
    }
  }

  bool _isSelfAddress(String normalizedAddress) {
    final self = focusAccountAddress?.trim().toLowerCase();
    return self != null && self == normalizedAddress;
  }
}
