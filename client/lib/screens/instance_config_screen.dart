// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/instance_config_schema.dart';
import '../models/instance_settings.dart';
import '../providers/auth_controller.dart';
import '../runtime/instance_runtime.dart';
import '../services/instance_config_service.dart';
import '../theme/alfred_colors.dart';

/// Configurazione istanza — form fisso su [InstanceConfigSchema] / [InstanceSettings].
class InstanceConfigScreen extends StatefulWidget {
  const InstanceConfigScreen({super.key});

  @override
  State<InstanceConfigScreen> createState() => _InstanceConfigScreenState();
}

class _InstanceConfigScreenState extends State<InstanceConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _imServerId = TextEditingController();
  final _logoUrl = TextEditingController();
  final _themeColor = TextEditingController();
  final _privacyUrl = TextEditingController();
  final _termsUrl = TextEditingController();
  final _supportUrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _loadedUserId;
  AuthController? _authListenerTarget;

  @override
  void dispose() {
    _authListenerTarget?.removeListener(_onFocusedAccountChanged);
    _displayName.dispose();
    _imServerId.dispose();
    _logoUrl.dispose();
    _themeColor.dispose();
    _privacyUrl.dispose();
    _termsUrl.dispose();
    _supportUrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    if (!identical(_authListenerTarget, auth)) {
      _authListenerTarget?.removeListener(_onFocusedAccountChanged);
      _authListenerTarget = auth;
      auth.addListener(_onFocusedAccountChanged);
    }
  }

  void _onFocusedAccountChanged() {
    final userId = _authListenerTarget?.focusedSession?.userId;
    if (_loadedUserId != null && userId != _loadedUserId && mounted && !_loading) {
      unawaited(_load());
    }
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
        _loadedUserId = null;
        _error = 'Nessun account attivo.';
      });
      return;
    }

    try {
      final isOwner = await session.ownerService.isInstanceOwner();
      if (!isOwner) {
        if (!mounted) return;
        final handle = session.profile.username ?? session.userId;
        setState(() {
          _loading = false;
          _loadedUserId = session.userId;
          _error =
              'L\'account @$handle non ha permessi owner sul server. '
              'Seleziona l\'account owner nel menu laterale e riprova.';
        });
        return;
      }

      final settings = await session.ownerService.loadInstanceSettings();
      if (!mounted) return;
      _applySettings(settings);
      setState(() {
        _loading = false;
        _loadedUserId = session.userId;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadedUserId = session.userId;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _applySettings(InstanceSettings settings) {
    _displayName.text = settings.displayName;
    _imServerId.text = settings.imServerId;
    _logoUrl.text = settings.branding.logoUrl ?? '';
    _themeColor.text = settings.branding.themeColor ?? '';
    _privacyUrl.text = settings.legal.privacyUrl ?? '';
    _termsUrl.text = settings.legal.termsUrl ?? '';
    _supportUrl.text = settings.legal.supportUrl ?? '';
  }

  InstanceSettings _settingsFromForm() {
    String? optional(String value) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return InstanceSettings(
      displayName: _displayName.text.trim(),
      imServerId: _imServerId.text.trim(),
      branding: InstanceBrandingAssets(
        logoUrl: optional(_logoUrl.text),
        themeColor: optional(_themeColor.text),
      ),
      legal: InstanceLegalLinks(
        privacyUrl: optional(_privacyUrl.text),
        termsUrl: optional(_termsUrl.text),
        supportUrl: optional(_supportUrl.text),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final session = context.read<AuthController>().focusedSession;
    if (session == null) return;

    setState(() => _saving = true);
    try {
      final isOwner = await session.ownerService.isInstanceOwner();
      if (!isOwner) {
        if (!mounted) return;
        final handle = session.profile.username ?? session.userId;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Salvataggio non consentito: @$handle non è owner del server.',
            ),
          ),
        );
        return;
      }

      final settings = _settingsFromForm();
      await session.ownerService.saveInstanceSettings(settings);
      await InstanceConfigService(session.client).loadRuntime();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configurazione salvata')),
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

  TextEditingController _controllerFor(String fieldId) {
    return switch (fieldId) {
      'display_name' => _displayName,
      'im_server_id' => _imServerId,
      'logo_url' => _logoUrl,
      'theme_color' => _themeColor,
      'privacy_url' => _privacyUrl,
      'terms_url' => _termsUrl,
      'support_url' => _supportUrl,
      _ => throw StateError('Unknown field $fieldId'),
    };
  }

  bool _isRequired(String fieldId) =>
      fieldId == 'display_name' || fieldId == 'im_server_id';

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
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      for (final section in InstanceConfigSchema.sections) ...[
                        Text(
                          section.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AlfredColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          section.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AlfredColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Material(
                          color: AlfredColors.panel,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AlfredColors.border),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: Column(
                              children: [
                                for (final field in section.fields)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: TextFormField(
                                      controller: _controllerFor(field.id),
                                      decoration: InputDecoration(
                                        labelText: field.label,
                                        hintText: field.hint,
                                        border: const OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      keyboardType:
                                          field.kind == InstanceConfigFieldKind.text
                                              ? TextInputType.text
                                              : TextInputType.url,
                                      validator: _isRequired(field.id)
                                          ? (value) {
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Obbligatorio';
                                              }
                                              return null;
                                            }
                                          : null,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _saving ? null : () => unawaited(_save()),
                          child: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Salva configurazione'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
