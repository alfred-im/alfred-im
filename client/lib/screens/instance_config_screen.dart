// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/instance_config_schema.dart';
import '../models/instance_settings.dart';
import '../providers/auth_controller.dart';
import '../runtime/instance_runtime.dart';
import '../services/instance_branding_service.dart';
import '../services/instance_config_service.dart';
import '../theme/alfred_colors.dart';
import '../utils/image_bytes.dart';
import '../utils/prepare_image_for_upload.dart';

/// Configurazione istanza — form fisso su [InstanceConfigSchema] / [InstanceSettings].
class InstanceConfigScreen extends StatefulWidget {
  const InstanceConfigScreen({super.key});

  @override
  State<InstanceConfigScreen> createState() => _InstanceConfigScreenState();
}

class _PendingAsset {
  const _PendingAsset({
    required this.bytes,
    required this.extension,
    required this.contentType,
  });

  final Uint8List bytes;
  final String extension;
  final String contentType;
}

enum _BrandingAssetKind { logo, favicon, wordmark }

class _InstanceConfigScreenState extends State<InstanceConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _imServerId = TextEditingController();
  final _shortName = TextEditingController();
  final _description = TextEditingController();
  final _themeColor = TextEditingController();
  final _backgroundColor = TextEditingController();
  final _privacyUrl = TextEditingController();
  final _termsUrl = TextEditingController();
  final _supportUrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _loadedUserId;
  AuthController? _authListenerTarget;

  String? _savedLogoUrl;
  String? _savedFaviconUrl;
  String? _savedWordmarkUrl;
  _PendingAsset? _pendingLogo;
  _PendingAsset? _pendingFavicon;
  _PendingAsset? _pendingWordmark;
  bool _removeLogo = false;
  bool _removeFavicon = false;
  bool _removeWordmark = false;

  @override
  void dispose() {
    _authListenerTarget?.removeListener(_onFocusedAccountChanged);
    _displayName.dispose();
    _imServerId.dispose();
    _shortName.dispose();
    _description.dispose();
    _themeColor.dispose();
    _backgroundColor.dispose();
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
      _pendingLogo = null;
      _pendingFavicon = null;
      _pendingWordmark = null;
      _removeLogo = false;
      _removeFavicon = false;
      _removeWordmark = false;
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
    _shortName.text = settings.branding.shortName ?? '';
    _description.text = settings.branding.description ?? '';
    _themeColor.text = settings.branding.themeColor ?? '';
    _backgroundColor.text = settings.branding.backgroundColor ?? '';
    _privacyUrl.text = settings.legal.privacyUrl ?? '';
    _termsUrl.text = settings.legal.termsUrl ?? '';
    _supportUrl.text = settings.legal.supportUrl ?? '';
    _savedLogoUrl = settings.branding.logoUrl;
    _savedFaviconUrl = settings.branding.faviconUrl;
    _savedWordmarkUrl = settings.branding.wordmarkUrl;
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  InstanceSettings _settingsFromForm({
    required String? logoUrl,
    required String? faviconUrl,
    required String? wordmarkUrl,
  }) {
    return InstanceSettings(
      displayName: _displayName.text.trim(),
      imServerId: _imServerId.text.trim(),
      branding: InstanceBrandingAssets(
        logoUrl: logoUrl,
        faviconUrl: faviconUrl,
        wordmarkUrl: wordmarkUrl,
        shortName: _optionalText(_shortName.text),
        description: _optionalText(_description.text),
        themeColor: _optionalText(_themeColor.text),
        backgroundColor: _optionalText(_backgroundColor.text),
      ),
      legal: InstanceLegalLinks(
        privacyUrl: _optionalText(_privacyUrl.text),
        termsUrl: _optionalText(_termsUrl.text),
        supportUrl: _optionalText(_supportUrl.text),
      ),
    );
  }

  Future<void> _pickAsset({required _BrandingAssetKind kind}) async {
    final forFavicon = kind == _BrandingAssetKind.favicon;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: forFavicon
          ? const ['jpg', 'jpeg', 'png', 'webp', 'ico']
          : const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
      allowMultiple: false,
    );

    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;

    try {
      final extension = (file!.extension ?? '').toLowerCase();
      final _PendingAsset pending;
      if (forFavicon && extension == 'ico') {
        if (bytes.length > InstanceBrandingService.maxBytes) {
          throw StateError('Immagine troppo grande (max 2 MB)');
        }
        pending = _PendingAsset(
          bytes: Uint8List.fromList(bytes),
          extension: 'ico',
          contentType: 'image/x-icon',
        );
      } else {
        final normalized = await prepareImageForUpload(Uint8List.fromList(bytes));
        pending = _PendingAsset(
          bytes: normalized.bytes,
          extension: normalized.extension,
          contentType: normalized.mime,
        );
      }
      if (!mounted) return;
      setState(() {
        switch (kind) {
          case _BrandingAssetKind.logo:
            _pendingLogo = pending;
            _removeLogo = false;
          case _BrandingAssetKind.favicon:
            _pendingFavicon = pending;
            _removeFavicon = false;
          case _BrandingAssetKind.wordmark:
            _pendingWordmark = pending;
            _removeWordmark = false;
        }
      });
    } on UnsupportedImageFormatException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.userMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  void _removeAsset({required _BrandingAssetKind kind}) {
    setState(() {
      switch (kind) {
        case _BrandingAssetKind.logo:
          _pendingLogo = null;
          _removeLogo = true;
        case _BrandingAssetKind.favicon:
          _pendingFavicon = null;
          _removeFavicon = true;
        case _BrandingAssetKind.wordmark:
          _pendingWordmark = null;
          _removeWordmark = true;
      }
    });
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

      final brandingService = InstanceBrandingService(session.client);
      var logoUrl = _savedLogoUrl;
      var faviconUrl = _savedFaviconUrl;
      var wordmarkUrl = _savedWordmarkUrl;

      if (_removeLogo) {
        await brandingService.deleteByPublicUrl(logoUrl);
        logoUrl = null;
      }
      if (_removeFavicon) {
        await brandingService.deleteByPublicUrl(faviconUrl);
        faviconUrl = null;
      }
      if (_removeWordmark) {
        await brandingService.deleteByPublicUrl(wordmarkUrl);
        wordmarkUrl = null;
      }

      if (_pendingLogo != null) {
        if (logoUrl != null && logoUrl.isNotEmpty) {
          await brandingService.deleteByPublicUrl(logoUrl);
        }
        logoUrl = await brandingService.uploadLogo(
          bytes: _pendingLogo!.bytes,
          extension: _pendingLogo!.extension,
          contentType: _pendingLogo!.contentType,
        );
      }

      if (_pendingFavicon != null) {
        if (faviconUrl != null && faviconUrl.isNotEmpty) {
          await brandingService.deleteByPublicUrl(faviconUrl);
        }
        faviconUrl = await brandingService.uploadFavicon(
          bytes: _pendingFavicon!.bytes,
          extension: _pendingFavicon!.extension,
          contentType: _pendingFavicon!.contentType,
        );
      }

      if (_pendingWordmark != null) {
        if (wordmarkUrl != null && wordmarkUrl.isNotEmpty) {
          await brandingService.deleteByPublicUrl(wordmarkUrl);
        }
        wordmarkUrl = await brandingService.uploadWordmark(
          bytes: _pendingWordmark!.bytes,
          extension: _pendingWordmark!.extension,
          contentType: _pendingWordmark!.contentType,
        );
      }

      final settings = _settingsFromForm(
        logoUrl: logoUrl,
        faviconUrl: faviconUrl,
        wordmarkUrl: wordmarkUrl,
      );
      await session.ownerService.saveInstanceSettings(settings);
      await InstanceConfigService(session.client).loadRuntime();
      if (!mounted) return;
      setState(() {
        _savedLogoUrl = logoUrl;
        _savedFaviconUrl = faviconUrl;
        _savedWordmarkUrl = wordmarkUrl;
        _pendingLogo = null;
        _pendingFavicon = null;
        _pendingWordmark = null;
        _removeLogo = false;
        _removeFavicon = false;
        _removeWordmark = false;
      });
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
      'short_name' => _shortName,
      'description' => _description,
      'theme_color' => _themeColor,
      'background_color' => _backgroundColor,
      'privacy_url' => _privacyUrl,
      'terms_url' => _termsUrl,
      'support_url' => _supportUrl,
      _ => throw StateError('Unknown field $fieldId'),
    };
  }

  bool _isRequired(String fieldId) =>
      fieldId == 'display_name' || fieldId == 'im_server_id';

  _BrandingAssetKind _assetKindForField(String fieldId) {
    return switch (fieldId) {
      'logo' => _BrandingAssetKind.logo,
      'favicon' => _BrandingAssetKind.favicon,
      'wordmark' => _BrandingAssetKind.wordmark,
      _ => throw StateError('Unknown asset field $fieldId'),
    };
  }

  Widget _buildAssetField(InstanceConfigFieldDef field) {
    final kind = _assetKindForField(field.id);
    final isWordmark = kind == _BrandingAssetKind.wordmark;
    final pending = switch (kind) {
      _BrandingAssetKind.logo => _pendingLogo,
      _BrandingAssetKind.favicon => _pendingFavicon,
      _BrandingAssetKind.wordmark => _pendingWordmark,
    };
    final savedUrl = switch (kind) {
      _BrandingAssetKind.logo => _savedLogoUrl,
      _BrandingAssetKind.favicon => _savedFaviconUrl,
      _BrandingAssetKind.wordmark => _savedWordmarkUrl,
    };
    final removed = switch (kind) {
      _BrandingAssetKind.logo => _removeLogo,
      _BrandingAssetKind.favicon => _removeFavicon,
      _BrandingAssetKind.wordmark => _removeWordmark,
    };
    final hasAsset = pending != null || (!removed && (savedUrl?.isNotEmpty ?? false));
    final previewWidth = isWordmark ? 160.0 : 48.0;
    final previewHeight = 48.0;
    final previewFit = isWordmark ? BoxFit.contain : BoxFit.cover;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            field.label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AlfredColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            field.hint,
            style: const TextStyle(
              fontSize: 12,
              color: AlfredColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (pending != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    pending.bytes,
                    width: previewWidth,
                    height: previewHeight,
                    fit: previewFit,
                  ),
                )
              else if (!removed && savedUrl != null && savedUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    savedUrl,
                    width: previewWidth,
                    height: previewHeight,
                    fit: previewFit,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      isWordmark
                          ? Icons.title
                          : kind == _BrandingAssetKind.favicon
                              ? Icons.web
                              : Icons.image_outlined,
                      size: 48,
                      color: AlfredColors.textSecondary,
                    ),
                  ),
                )
              else
                Icon(
                  isWordmark
                      ? Icons.title
                      : kind == _BrandingAssetKind.favicon
                          ? Icons.web
                          : Icons.image_outlined,
                  size: 48,
                  color: AlfredColors.textSecondary,
                ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () => unawaited(_pickAsset(kind: kind)),
                child: Text(hasAsset ? 'Sostituisci' : 'Scegli file'),
              ),
              if (hasAsset) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => _removeAsset(kind: kind),
                  child: const Text('Rimuovi'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
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
                                  if (field.kind == InstanceConfigFieldKind.asset)
                                    _buildAssetField(field)
                                  else
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
                                            field.kind == InstanceConfigFieldKind.text ||
                                                    field.kind ==
                                                        InstanceConfigFieldKind.color
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
                    ],
                  ),
                ),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
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
              ),
            ),
    );
  }
}
