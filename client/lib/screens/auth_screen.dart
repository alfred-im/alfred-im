import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_controller.dart';
import '../theme/alfred_colors.dart';
import '../widgets/alfred_logo.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    this.addingAccount = false,
    this.onCancel,
  });

  /// Credenziali per aggiungere un altro account (account già aperti sotto).
  final bool addingAccount;
  final VoidCallback? onCancel;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthController>();
    if (_isSignUp) {
      await auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
        displayName: _displayNameController.text.trim(),
      );
    } else {
      await auth.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (!mounted || auth.error != null) return;
  }

  Future<void> _forgotPassword() async {
    final auth = context.read<AuthController>();
    final emailController = TextEditingController(text: _emailController.text);

    final sent = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recupero password'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'mario@esempio.it',
          ),
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          enableSuggestions: false,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Invia link'),
          ),
        ],
      ),
    );

    if (sent != true || !mounted) {
      emailController.dispose();
      return;
    }

    final ok = await auth.resetPassword(emailController.text.trim());
    emailController.dispose();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Se l\'email è registrata, riceverai un link per reimpostare la password.'
              : auth.error ?? 'Impossibile inviare il link di recupero.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AlfredColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AlfredLogo(size: 56),
            const SizedBox(height: 16),
            Text(
              widget.addingAccount
                  ? 'Aggiungi account Alfred'
                  : _isSignUp
                      ? 'Crea account Alfred'
                      : 'Accedi ad Alfred',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'mario@esempio.it',
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              enableSuggestions: false,
            ),
            if (_isSignUp) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'mario_rossi',
                ),
                textInputAction: TextInputAction.next,
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _displayNameController,
                decoration: const InputDecoration(
                  labelText: 'Nome visualizzato',
                ),
                textInputAction: TextInputAction.next,
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
              onSubmitted: (_) => _submit(),
            ),
            if (!_isSignUp) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: auth.isLoading ? null : _forgotPassword,
                  child: const Text('Password dimenticata?'),
                ),
              ),
            ],
            if (auth.error != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: auth.isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AlfredColors.charcoal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isSignUp ? 'Registrati' : 'Accedi'),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(
                _isSignUp
                    ? 'Hai già un account? Accedi'
                    : 'Non hai un account? Registrati',
              ),
            ),
            if (widget.addingAccount && widget.onCancel != null)
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Annulla'),
              ),
          ],
        ),
      ),
    );
  }
}
