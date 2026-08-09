// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../coordinators/shareable_link_coordinator.dart';
import '../utils/shareable_link.dart';

/// Facade UI shareable-link — orchestrazione in [ShareableLinkCoordinator].
class ShareableLinkController extends ChangeNotifier {
  ShareableLinkController() {
    _coordinator = ShareableLinkCoordinator(onStateChanged: notifyListeners);
  }

  late final ShareableLinkCoordinator _coordinator;

  ShareableLinkTarget? get target => _coordinator.target;
  bool get invalid => _coordinator.invalid;
  bool get isHandling => _coordinator.isHandling;

  void applyFragment(String? fragment) => _coordinator.applyFragment(fragment);

  void clearInvalid() => _coordinator.clearInvalid();

  Future<void> handleIfReady(BuildContext context) =>
      _coordinator.handleIfReady(context);

  void dismissInvalid() => _coordinator.dismissInvalid();
}
