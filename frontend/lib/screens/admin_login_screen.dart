import 'dart:async';

import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/admin_auth_service.dart';
import '../widgets/app_scaffold.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _busy = true;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final profile = await AdminAuthService.currentAdmin();
    if (mounted) {
      setState(() {
        _profile = profile;
        _busy = false;
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await AdminAuthService.login(_email.text, _password.text);
      _password.clear();
      if (mounted) {
        setState(() => _profile = profile);
        Navigator.of(context).pushReplacementNamed('/admin/dashboard');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = 'Connection timed out. Please try again.');
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error is Exception && error.toString().startsWith('Exception: ')
              ? error.toString().substring(11)
              : 'Unable to connect. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    try {
      await AdminAuthService.logout();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Signed out locally. Server sign-out could not be confirmed.',
        );
      }
    }
    if (mounted) {
      setState(() {
        _profile = null;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AppScaffold(
    appBar: AppBar(
      title: const Text('Autonomous Printer'),
      leading: IconButton(
        tooltip: 'Back to printing',
        icon: const Icon(Icons.arrow_back),
        onPressed: () =>
            Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false),
      ),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: AppTheme.primarySurface,
                          child: Icon(
                            Icons.admin_panel_settings_outlined,
                            color: AppTheme.primary,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _profile == null ? 'Admin login' : 'Admin account',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 24),
                      if (_profile != null) ...[
                        Text(
                          _profile!['full_name'] as String? ?? 'Administrator',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(_profile!['email'] as String),
                        const SizedBox(height: 8),
                        Text(
                          _profile!['role'] == 'SUPER_ADMIN'
                              ? 'Super administrator'
                              : 'Administrator',
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          icon: const Icon(Icons.dashboard_rounded),
                          label: const Text('Go to Dashboard'),
                          onPressed: () => Navigator.of(context).pushReplacementNamed('/admin/dashboard'),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _busy ? null : _logout,
                          child: const Text('Sign out'),
                        ),
                      ] else ...[
                        TextFormField(
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (value) =>
                              value == null ||
                                  !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                      .hasMatch(value.trim())
                              ? 'Enter a valid email.'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _password,
                          enabled: !_busy,
                          obscureText: _hidden,
                          autofillHints: const [AutofillHints.password],
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _login(),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _hidden
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () =>
                                  setState(() => _hidden = !_hidden),
                              icon: Icon(
                                _hidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your password.'
                              : null,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _login,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign in'),
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
