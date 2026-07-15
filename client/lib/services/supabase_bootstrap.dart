// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/widgets.dart';

import '../utils/shareable_link_platform.dart';
import '../utils/push_launch.dart';

/// Bootstrap minimo app: nessuna sessione utente globale.
Future<void> bootstrapApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  captureBootShareableFragment();
  captureBootPushLaunchFragment();
}
