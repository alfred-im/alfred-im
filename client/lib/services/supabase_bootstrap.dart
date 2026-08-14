// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../config/deploy_config.dart';
import '../runtime/instance_runtime.dart';
import '../services/instance_config_service.dart';
import '../utils/push_launch.dart';
import '../utils/shareable_link_platform.dart';
import 'account_session.dart';

/// Bootstrap app: deploy config, poi impostazioni istanza dal backend.
Future<InstanceRuntime> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  captureBootShareableFragment();
  captureBootPushLaunchFragment();

  await DeployConfig.load();

  final bootstrapClient = AccountSession.createBootstrapClient();
  final runtime = await InstanceConfigService(bootstrapClient).loadRuntime();
  return runtime;
}
