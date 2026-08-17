// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';

import '../models/instance_stats.dart';
import '../services/account_session.dart';
import '../widgets/instance_stats_panel.dart';

/// Carica e mostra statistiche istanza per account owner.
class OwnerInboxStatsLoader extends StatefulWidget {
  const OwnerInboxStatsLoader({super.key, required this.session});

  final AccountSession session;

  @override
  State<OwnerInboxStatsLoader> createState() => _OwnerInboxStatsLoaderState();
}

class _OwnerInboxStatsLoaderState extends State<OwnerInboxStatsLoader> {
  InstanceStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await widget.session.ownerService.fetchStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return InstanceStatsPanel(
      stats: _stats,
      isLoading: _loading,
      error: _error,
      onRetry: _load,
    );
  }
}
