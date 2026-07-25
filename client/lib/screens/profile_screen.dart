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
import '../widgets/profile_identity.dart';

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

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthController>().profile;
    _displayNameController =
        TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _pronounsController = TextEditingController(text: profile?.pronouns ?? '');
    _pendingAvatarUrl = profile?.avatarUrl;
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
    final userId = auth.userId;
    if (userId == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
      allowMultiple: false,
    );

    final file = result?.files.single;
    final bytes = file?.bytes;
    if (bytes == null || bytes.isEmpty) return;

    final extension = _avatarExtension(file?.extension);
    final contentType = _avatarContentType(extension);

    try {
      final saved = await profileController.uploadAndSaveAvatar(
        bytes: Uint8List.fromList(bytes),
        extension: extension,
        contentType: contentType,
        displayName: _displayNameController.text,
        bio: _bioController.text,
        pronouns: _pronounsController.text,
      );
      if (mounted) {
        setState(() => _pendingAvatarUrl = saved.avatarUrl);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profilo aggiornata')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              profileController.error ?? 'Impossibile caricare la foto profilo',
            ),
          ),
        );
      }
    }
  }

  String _avatarExtension(String? raw) {
    final ext = (raw ?? 'jpg').toLowerCase();
    if (ext == 'jpeg') return 'jpg';
    return ext;
  }

  String _avatarContentType(String extension) {
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
  }) {
    return ProfileSummary(
      id: userId,
      username: profile?.username,
      displayName: _displayNameController.text.trim().isNotEmpty
          ? _displayNameController.text.trim()
          : profile?.displayName ?? '',
      avatarUrl: avatarUrl,
      pronouns: profile?.pronouns,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profileController = context.watch<ProfileController>();
    final profile = auth.profile;
    final userId = auth.userId;
    final avatarUrl = _pendingAvatarUrl ?? profile?.avatarUrl;
    final displaySummary = userId != null
        ? _displaySummary(
            userId: userId,
            profile: profile,
            avatarUrl: avatarUrl,
          )
        : null;

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
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                if (displaySummary != null)
                  ProfileAvatar(
                    profile: displaySummary,
                    radius: 48,
                    fontSize: 32,
                  )
                else
                  const CircleAvatar(radius: 48),
                Material(
                  color: AlfredColors.charcoal,
                  shape: const CircleBorder(),
                  child: IconButton(
                    icon: profileController.isUploadingAvatar
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_outlined, size: 18),
                    color: Colors.white,
                    tooltip: 'Cambia foto profilo',
                    onPressed: profileController.isUploadingAvatar
                        ? null
                        : _pickAvatar,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (displaySummary != null)
            Center(
              child: ProfileIdentityLines(
                profile: displaySummary,
                showPronouns: false,
                nameStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AlfredColors.textSecondary,
                ),
                usernameStyle: const TextStyle(
                  color: AlfredColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: 24),
          TextFormField(
            initialValue: auth.email ?? '',
            readOnly: true,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              helperText: 'Solo lettura — usata per accesso e recupero password',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(labelText: 'Nome visualizzato'),
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
    );
  }
}
