// Copyright (C) 2026 im.alfred
//
// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/profile.dart';
import '../models/profile_summary.dart';
import '../providers/auth_controller.dart';
import '../providers/profile_controller.dart';
import '../theme/alfred_colors.dart';
import '../widgets/profile_cover_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _pronounsController;
  String? _pendingAvatarUrl;
  String? _pendingCoverUrl;
  bool _coverRemoved = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthController>().profile;
    _displayNameController =
        TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _pronounsController = TextEditingController(text: profile?.pronouns ?? '');
    _pendingAvatarUrl = profile?.avatarUrl;
    _pendingCoverUrl = profile?.summary.coverUrl;
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _pronounsController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final auth = context.read<AuthController>();
    final profileController = context.read<ProfileController>();
    if (auth.userId == null) return;
    await _uploadImage(
      forCover: false,
      successMessage: 'Foto profilo aggiornata',
      errorFallback: 'Impossibile caricare la foto profilo',
      profileController: profileController,
    );
  }

  Future<void> _pickCover() async {
    final profileController = context.read<ProfileController>();
    await _uploadImage(
      forCover: true,
      successMessage: 'Copertina aggiornata',
      errorFallback: 'Impossibile caricare la copertina',
      profileController: profileController,
    );
  }

  Future<void> _uploadImage({
    required bool forCover,
    required String successMessage,
    required String errorFallback,
    required ProfileController profileController,
  }) async {
    final auth = context.read<AuthController>();
    if (auth.userId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
      allowMultiple: false,
    );

    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final extension = _imageExtension(file?.extension);
    final contentType = _imageContentType(extension);

    try {
      if (forCover) {
        final saved = await profileController.uploadAndSaveCover(
          bytes: Uint8List.fromList(bytes),
          extension: extension,
          contentType: contentType,
          displayName: _displayNameController.text,
          bio: _bioController.text,
          pronouns: _pronounsController.text,
          avatarUrl: _pendingAvatarUrl,
        );
        if (mounted) {
          setState(() {
            _pendingCoverUrl = saved.summary.coverUrl;
            _coverRemoved = false;
          });
        }
      } else {
        final saved = await profileController.uploadAndSaveAvatar(
          bytes: Uint8List.fromList(bytes),
          extension: extension,
          contentType: contentType,
          displayName: _displayNameController.text,
          bio: _bioController.text,
          pronouns: _pronounsController.text,
          coverUrl: _coverRemoved ? null : _pendingCoverUrl,
        );
        if (mounted) {
          setState(() => _pendingAvatarUrl = saved.avatarUrl);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(profileController.error ?? errorFallback),
          ),
        );
      }
    }
  }

  Future<void> _removeCover() async {
    final auth = context.read<AuthController>();
    final profileController = context.read<ProfileController>();
    if (auth.userId == null) return;

    try {
      await profileController.save(
        displayName: _displayNameController.text,
        bio: _bioController.text,
        pronouns: _pronounsController.text,
        avatarUrl: _pendingAvatarUrl,
        clearCoverUrl: true,
      );
      if (mounted) {
        setState(() {
          _pendingCoverUrl = null;
          _coverRemoved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copertina rimossa')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              profileController.error ?? 'Impossibile rimuovere la copertina',
            ),
          ),
        );
      }
    }
  }

  String _imageExtension(String? raw) {
    final ext = (raw ?? 'jpg').toLowerCase();
    if (ext == 'jpeg') return 'jpg';
    return ext;
  }

  String _imageContentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _save() async {
    final auth = context.read<AuthController>();
    final userId = auth.userId;
    if (userId == null) return;

    final profileController = context.read<ProfileController>();
    await profileController.save(
      displayName: _displayNameController.text,
      bio: _bioController.text,
      pronouns: _pronounsController.text,
      avatarUrl: _pendingAvatarUrl,
      coverUrl: _coverRemoved ? null : _pendingCoverUrl,
      clearCoverUrl: _coverRemoved,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo aggiornato')),
      );
      Navigator.pop(context);
    }
  }

  ProfileSummary _displaySummary({
    required String userId,
    required UserProfile? profile,
    required String? avatarUrl,
    required String? coverUrl,
  }) {
    return ProfileSummary(
      id: userId,
      username: profile?.username,
      displayName: _displayNameController.text.trim().isNotEmpty
          ? _displayNameController.text.trim()
          : profile?.displayName ?? '',
      avatarUrl: avatarUrl,
      coverUrl: coverUrl,
      pronouns: profile?.pronouns,
      profileKind: profile?.summary.profileKind ?? ProfileKind.user,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profileController = context.watch<ProfileController>();
    final profile = auth.profile;
    final userId = auth.userId;
    final avatarUrl = _pendingAvatarUrl ?? profile?.avatarUrl;
    final coverUrl = _coverRemoved ? null : (_pendingCoverUrl ?? profile?.summary.coverUrl);
    final displaySummary = userId != null
        ? _displaySummary(
            userId: userId,
            profile: profile,
            avatarUrl: avatarUrl,
            coverUrl: coverUrl,
          )
        : null;
    final isUploadingMedia =
        profileController.isUploadingAvatar || profileController.isUploadingCover;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilo Alfred'),
        backgroundColor: AlfredColors.charcoal,
        foregroundColor: AlfredColors.textOnDark,
        actions: [
          TextButton(
            onPressed: profileController.isSaving ? null : _save,
            child: const Text('Salva', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          if (displaySummary != null)
            ProfileCoverHeader(
              profile: displaySummary,
              onCoverTap: isUploadingMedia ? null : _pickCover,
              onAvatarTap: isUploadingMedia ? null : _pickAvatar,
              coverOverlay: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _MediaPickerChip(
                    icon: profileController.isUploadingCover
                        ? null
                        : Icons.photo_outlined,
                    label: 'Copertina',
                    loading: profileController.isUploadingCover,
                  ),
                ),
              ),
              avatarOverlay: Material(
                color: AlfredColors.charcoal,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: profileController.isUploadingAvatar
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.camera_alt_outlined, size: 14),
                  color: Colors.white,
                  tooltip: 'Cambia foto profilo',
                  onPressed: isUploadingMedia ? null : _pickAvatar,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                ),
              ),
              extraBelowIdentity: coverUrl != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton(
                        onPressed:
                            profileController.isSaving ? null : _removeCover,
                        child: const Text('Rimuovi copertina'),
                      ),
                    )
                  : null,
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(
                  initialValue: auth.email ?? '',
                  readOnly: true,
                  enabled: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    helperText:
                        'Solo lettura — usata per accesso e recupero password',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _displayNameController,
                  decoration:
                      const InputDecoration(labelText: 'Nome visualizzato'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pronounsController,
                  decoration: const InputDecoration(
                    labelText: 'Pronomi',
                    hintText: 'Es. lei/ella, lui/egli, they/them',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bioController,
                  decoration: const InputDecoration(labelText: 'Bio'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPickerChip extends StatelessWidget {
  const _MediaPickerChip({
    this.icon,
    required this.label,
    this.loading = false,
  });

  final IconData? icon;
  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else if (icon != null)
              Icon(icon, size: 14, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
