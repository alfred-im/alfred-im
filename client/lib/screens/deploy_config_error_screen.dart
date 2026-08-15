// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';

import '../config/deploy_config.dart';
import '../theme/alfred_theme.dart';

/// Schermata mostrata quando `config.json` manca o non è valido.
class DeployConfigErrorScreen extends StatelessWidget {
  const DeployConfigErrorScreen({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AlfredTheme.light,
      home: Scaffold(
        backgroundColor: const Color(0xFF2D2926),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configurazione mancante',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFE8E4E0),
                    fontSize: 15,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'L\'operatore dell\'istanza deve fornire config.json al deploy '
                  '(vedi config.json.example nel repository).',
                  style: TextStyle(
                    color: Color(0xFFB8B2AC),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> runAppWithDeployConfig(
  Future<void> Function() bootstrap,
  Widget Function() appBuilder,
) async {
  try {
    await bootstrap();
    runApp(appBuilder());
  } on DeployConfigException catch (error) {
    runApp(DeployConfigErrorScreen(message: error.message));
  }
}
