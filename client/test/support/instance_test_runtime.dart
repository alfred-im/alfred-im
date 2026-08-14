// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:alfred_client/config/deploy_config.dart';
import 'package:alfred_client/models/instance_settings.dart';
import 'package:alfred_client/runtime/instance_runtime.dart';

void installTestDeployAndInstance({
  String imServerId = 'alfred.app',
  String displayName = 'Test',
  String publicBaseUrl = 'https://example.com/',
}) {
  DeployConfig.overrideForTest(
    DeployConfig(
      supabaseUrl: 'http://127.0.0.1:54321',
      supabaseAnonKey: 'test-anon-key',
      publicBaseUrl: publicBaseUrl,
    ),
  );
  InstanceRuntime.overrideForTest(
    InstanceRuntime(
      settings: InstanceSettings(
        displayName: displayName,
        imServerId: imServerId,
      ),
    ),
  );
}

void resetTestDeployAndInstance() {
  DeployConfig.resetForTest();
  InstanceRuntime.resetForTest();
}
