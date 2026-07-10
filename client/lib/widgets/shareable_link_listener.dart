import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../providers/shareable_link_controller.dart';
import '../utils/shareable_link_platform.dart';

/// Ascolta il fragment `#` e apre profilo/chat quando c'è almeno un account.
class ShareableLinkListener extends StatefulWidget {
  const ShareableLinkListener({super.key, required this.child});

  final Widget child;

  @override
  State<ShareableLinkListener> createState() => _ShareableLinkListenerState();
}

class _ShareableLinkListenerState extends State<ShareableLinkListener> {
  StreamSubscription<String?>? _hashSub;

  @override
  void initState() {
    super.initState();
    _hashSub = watchShareableFragment().listen(_onFragment);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onFragmentIfPresent(readShareableFragment());
    });
  }

  @override
  void dispose() {
    unawaited(_hashSub?.cancel());
    super.dispose();
  }

  void _onFragment(String? fragment) {
    if (!mounted) return;
    context.read<ShareableLinkController>().applyFragment(fragment);
    _scheduleHandle();
  }

  void _onFragmentIfPresent(String? fragment) {
    if (fragment == null) {
      _scheduleHandle();
      return;
    }
    _onFragment(fragment);
  }

  void _scheduleHandle() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<ShareableLinkController>().handleIfReady(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthController>();
    context.watch<ShareableLinkController>();
    _scheduleHandle();
    return widget.child;
  }
}
