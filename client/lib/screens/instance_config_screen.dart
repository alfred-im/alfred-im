// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/instance_config_entry.dart';
import '../providers/auth_controller.dart';
import '../runtime/instance_runtime.dart';
import '../services/instance_config_service.dart';
import '../theme/alfred_colors.dart';

/// Configurazione istanza (`instance_config`) — solo account owner.
class InstanceConfigScreen extends StatefulWidget {
  const InstanceConfigScreen({super.key});

  @override
  State<InstanceConfigScreen> createState() => _InstanceConfigScreenState();
}

class _InstanceConfigScreenState extends State<InstanceConfigScreen> {
  final _controllers = <String, TextEditingController>{};
  List<InstanceConfigEntry> _entries = [];
  bool _loading = true;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

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

    final session = context.read<AuthController>().focusedSession;
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Nessun account attivo.';
      });
      return;
    }

    try {
      final entries = await session.ownerService.listConfig();
      if (!mounted) return;
      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      for (final entry in entries) {
        _controllers[entry.key] = TextEditingController(text: entry.value);
      }
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _save(InstanceConfigEntry entry) async {
    final session = context.read<AuthController>().focusedSession;
    if (session == null) return;

    final controller = _controllers[entry.key];
    if (controller == null) return;

    setState(() => _saving = true);
    try {
      final parsed = InstanceConfigEntry(
        key: entry.key,
        value: controller.text,
      ).parseValueForSave();
      await session.ownerService.upsertConfig(key: entry.key, value: parsed);
      await InstanceConfigService(session.client).loadRuntime();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Salvato ${entry.key}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addKey() async {
    final keyController = TextEditingController(text: 'instance.');
    final valueController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuova chiave'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: keyController,
              decoration: const InputDecoration(
                labelText: 'Chiave',
                hintText: 'instance.display_name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valueController,
              decoration: const InputDecoration(
                labelText: 'Valore (JSON)',
                hintText: '"Il mio server"',
              ),
              minLines: 2,
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aggiungi'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      keyController.dispose();
      valueController.dispose();
      return;
    }

    final session = context.read<AuthController>().focusedSession;
    if (session == null) return;

    try {
      final parsed = InstanceConfigEntry(
        key: keyController.text.trim(),
        value: valueController.text,
      ).parseValueForSave();
      await session.ownerService.upsertConfig(
        key: keyController.text.trim(),
        value: parsed,
      );
      await InstanceConfigService(session.client).loadRuntime();
      if (!mounted) return;
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      keyController.dispose();
      valueController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        InstanceRuntime.isLoaded ? InstanceRuntime.require.displayName : 'Server';

    return Scaffold(
      backgroundColor: AlfredColors.surface,
      appBar: AppBar(
        title: Text('Configurazione $displayName'),
        backgroundColor: AlfredColors.panel,
        foregroundColor: AlfredColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _addKey,
            icon: const Icon(Icons.add),
            tooltip: 'Nuova chiave',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Riprova'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _entries.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final controller = _controllers[entry.key]!;
                    return Material(
                      color: AlfredColors.panel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AlfredColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: controller,
                              minLines: 1,
                              maxLines: 6,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton(
                                onPressed: _saving
                                    ? null
                                    : () => unawaited(_save(entry)),
                                child: const Text('Salva'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
