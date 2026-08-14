// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import '../config/deploy_config.dart';
import '../runtime/instance_runtime.dart';

/// Accesso a configurazione runtime (deploy + istanza).
class AppConfig {
  const AppConfig._();

  static String get supabaseUrl => DeployConfig.require.supabaseUrl;

  static String get supabaseAnonKey => DeployConfig.require.supabaseAnonKey;

  static String? get publicBaseUrl => DeployConfig.require.publicBaseUrl;

  static String get imServerId => InstanceRuntime.require.imServerId;

  static String get vapidPublicKey => InstanceRuntime.require.vapidPublicKey;
}
