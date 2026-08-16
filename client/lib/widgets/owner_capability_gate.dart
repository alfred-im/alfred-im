// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/account_session.dart';

/// Mostra [child] solo se il backend conferma `is_instance_owner()` per la sessione.
class OwnerCapabilityGate extends StatefulWidget {
  const OwnerCapabilityGate({
    super.key,
    required this.session,
    required this.child,
  });

  final AccountSession session;
  final Widget child;

  @override
  State<OwnerCapabilityGate> createState() => _OwnerCapabilityGateState();
}

class _OwnerCapabilityGateState extends State<OwnerCapabilityGate> {
  bool? _isOwner;

  @override
  void initState() {
    super.initState();
    unawaited(_resolve());
  }

  @override
  void didUpdateWidget(covariant OwnerCapabilityGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session.userId != widget.session.userId) {
      unawaited(_resolve());
    }
  }

  Future<void> _resolve() async {
    setState(() => _isOwner = null);
    try {
      final isOwner = await widget.session.ownerService.isInstanceOwner();
      if (!mounted) return;
      if (isOwner != widget.session.profile.isOwner) {
        await widget.session.syncProfileSummary();
        await widget.session.updateStoredProfile(widget.session.profile);
      }
      setState(() => _isOwner = isOwner);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isOwner = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOwner != true) return const SizedBox.shrink();
    return widget.child;
  }
}
