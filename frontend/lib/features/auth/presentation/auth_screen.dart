import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_feedback.dart';
import '../../../features/reports/presentation/citizen_dashboard_screen.dart';
import '../data/auth_repository.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authRepository = AuthRepository();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistering = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isRegistering) {
        await _authRepository.signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (!mounted) return;
        showAppSnackBar(context, 'Registrasi berhasil. Silakan login.');
        setState(() => _isRegistering = false);
        return;
      }

      final user = await _authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final profile = await _authRepository.getProfile(user.id);

      if (profile.isBlocked) {
        await _authRepository.signOut();
        if (!mounted) return;
        showAppSnackBar(
          context,
          'Akun Anda diblokir karena laporan palsu atau spam.',
        );
        return;
      }

      if (!profile.isCitizen) {
        await _authRepository.signOut();
        if (!mounted) return;
        showAppSnackBar(
          context,
          'Akun admin/dishub hanya dapat digunakan melalui web admin.',
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CitizenDashboardScreen()),
      );
    } on AuthException catch (error) {
      if (mounted) showAppSnackBar(context, error.message);
    } catch (error) {
      if (mounted) showAppSnackBar(context, 'Gagal memproses akun: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isRegistering ? 'Buat Akun Warga' : 'Masuk Warga';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 56,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Laporkan masalah infrastruktur jalan dengan foto, kategori, dan lokasi presisi.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 28),
                    if (_isRegistering) ...[
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Nama lengkap',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (!_isRegistering) return null;
                          return value == null || value.trim().isEmpty
                              ? 'Nama wajib diisi'
                              : null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Email wajib diisi';
                        if (!email.contains('@')) return 'Format email belum valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.length < 6) {
                          return 'Password minimal 6 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isRegistering ? 'Daftar' : 'Masuk'),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => setState(
                                () => _isRegistering = !_isRegistering,
                              ),
                      child: Text(
                        _isRegistering
                            ? 'Sudah punya akun? Masuk'
                            : 'Belum punya akun? Daftar',
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
