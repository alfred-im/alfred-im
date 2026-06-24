import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../providers/profile_controller.dart';
import '../theme/alfred_colors.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AuthController>().profile;
    _displayNameController =
        TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthController>();
    final userId = auth.userId;
    if (userId == null) return;

    final profileController = context.read<ProfileController>();
    await profileController.save(
      displayName: _displayNameController.text.trim(),
      bio: _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim(),
    );
    await auth.refreshProfile();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo aggiornato')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profileController = context.watch<ProfileController>();
    final profile = auth.profile;

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
            child: CircleAvatar(
              radius: 48,
              backgroundColor: AlfredColors.charcoal,
              child: Text(
                (profile?.displayName ?? '?')[0].toUpperCase(),
                style: const TextStyle(fontSize: 32, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '@${profile?.username ?? ''}',
              style: const TextStyle(color: AlfredColors.textSecondary),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _displayNameController,
            decoration: const InputDecoration(labelText: 'Nome visualizzato'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bioController,
            decoration: const InputDecoration(labelText: 'Bio'),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: Text(auth.email ?? ''),
            subtitle: const Text('Email account Alfred'),
          ),
        ],
      ),
    );
  }
}
