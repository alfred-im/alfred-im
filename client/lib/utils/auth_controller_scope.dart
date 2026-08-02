// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';

/// [AuthController] opzionale — widget test senza Provider.
AuthController? watchAuthControllerOrNull(BuildContext context) {
  try {
    return context.watch<AuthController>();
  } on ProviderNotFoundException {
    return null;
  }
}
