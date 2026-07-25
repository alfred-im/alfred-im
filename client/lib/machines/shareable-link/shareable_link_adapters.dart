// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'shareable_link_machine.dart';

/// Mappa ingressi UI → eventi [ShareableLinkMachine].
///
/// UML: `docs/model/uml/shareable-link/seq-open-from-fragment.puml`
class ShareableLinkAdapters {
  ShareableLinkAdapters(this._machine);

  final ShareableLinkMachine _machine;

  void onFragmentChanged(String? fragment) {
    _machine.send(ParseFragment(fragment));
  }

  Future<void> onHandleRequested() {
    return _machine.handleTargetIfReady();
  }

  void onDismissInvalid() {
    _machine.send(const DismissInvalid());
  }
}
