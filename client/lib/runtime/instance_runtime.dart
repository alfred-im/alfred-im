// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/foundation.dart';

import '../models/instance_settings.dart';

/// Runtime dell'istanza (nome servizio, server IM, branding) — caricato dopo deploy config.
class InstanceRuntime {
  InstanceRuntime({
    required this.settings,
    this.vapidPublicKey = '',
  });

  final InstanceSettings settings;
  final String vapidPublicKey;

  String get displayName => settings.displayName;
  String get imServerId => settings.imServerId;
  InstanceBrandingAssets get branding => settings.branding;
  InstanceLegalLinks get legal => settings.legal;

  static InstanceRuntime? _loaded;

  static InstanceRuntime get require {
    final runtime = _loaded;
    if (runtime == null) {
      throw StateError('InstanceRuntime non caricato.');
    }
    return runtime;
  }

  static bool get isLoaded => _loaded != null;

  static void install(InstanceRuntime runtime) {
    _loaded = runtime;
  }

  @visibleForTesting
  static void overrideForTest(InstanceRuntime runtime) {
    _loaded = runtime;
  }

  @visibleForTesting
  static void resetForTest() {
    _loaded = null;
  }
}
