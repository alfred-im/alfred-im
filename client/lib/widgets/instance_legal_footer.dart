// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../runtime/instance_runtime.dart';

/// Link legali opzionali dell'istanza (se presenti in `instance.legal`).
class InstanceLegalFooter extends StatelessWidget {
  const InstanceLegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final legal = InstanceRuntime.require.legal;
    if (!legal.hasAny) return const SizedBox.shrink();

    final links = <({String label, String url})>[
      if (legal.privacyUrl?.isNotEmpty ?? false)
        (label: 'Privacy', url: legal.privacyUrl!),
      if (legal.termsUrl?.isNotEmpty ?? false)
        (label: 'Termini', url: legal.termsUrl!),
      if (legal.supportUrl?.isNotEmpty ?? false)
        (label: 'Supporto', url: legal.supportUrl!),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final link in links)
            TextButton(
              onPressed: () => launchUrl(Uri.parse(link.url)),
              child: Text(link.label),
            ),
        ],
      ),
    );
  }
}
