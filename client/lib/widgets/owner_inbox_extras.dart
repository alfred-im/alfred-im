// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../services/account_session.dart';
import 'owner_capability_gate.dart';
import 'owner_inbox_stats_loader.dart';

/// Pannelli inbox riservati agli owner (statistiche), dopo verifica server-side.
class OwnerInboxExtras extends StatelessWidget {
  const OwnerInboxExtras({super.key, required this.session});

  final AccountSession session;

  @override
  Widget build(BuildContext context) {
    return OwnerCapabilityGate(
      session: session,
      child: OwnerInboxStatsLoader(session: session),
    );
  }
}
