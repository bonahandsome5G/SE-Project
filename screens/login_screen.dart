import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'citizen_menu_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController(); // Digunakan saat registrasi
  bool _isLoading = false;
  bool _isRegistering = false; // Toggle antara mode Login dan Register

  Future<void> _handleAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Email dan password tidak boleh kosong');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isRegistering) {
        // 1. PROSES REGISTRASI (Daftar Akun Baru)
        if (_nameController.text.isEmpty) {
          _showSnackBar('Nama lengkap wajib diisi untuk registrasi');
          setState(() => _isLoading = false);
          return;
        }

        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          data: {'full_name': _nameController.text.trim()}, // Dikirim ke metadata user
        );

        _showSnackBar('Registrasi berhasil! Silakan login.');
        setState(() => _isRegistering = false);
      } else {
        // 2. PROSES LOGIN
        final AuthResponse response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (response.user != null) {
          _checkUserRoleAndNavigate(response.user!.id);
        }
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('Terjadi kesalahan tidak terduga: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Fungsi untuk memeriksa Role dan status Blokir di tabel Profiles
  Future<void> _checkUserRoleAndNavigate(String userId) async {
    try {
        final data = await Supabase.instance.client
          .from('profiles')
          .select('role, is_blocked')
          .eq('id', userId)
          .single();

      final bool isBlocked = data['is_blocked'] ?? false;
      final String role = data['role'] ?? 'citizen';

      // Proteksi Non-Functional: Cek jika diblokir oleh Admin/Dishub
      if (isBlocked) {
        _showSnackBar('Akun Anda telah diblokir karena melakukan laporan palsu/spam.');
        await Supabase.instance.client.auth.signOut();
        return;
      }

      if (!mounted) return;

      // Admin/Dishub hanya bisa login melalui website desktop khusus admin
      if (role == 'dishub' || role == 'admin') {
        _showSnackBar('Akun admin hanya dapat diakses melalui website desktop khusus admin. Silakan gunakan browser desktop.');
        await Supabase.instance.client.auth.signOut();
        return;
      }

      // Navigasi untuk warga biasa
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CitizenMenuScreen()),
      );
    } catch (e) {
      _showSnackBar('Gagal mengambil data profil: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon(Icons.location_city, size: 80, color: Theme.of(context).primaryColor),
              const SizedBox(height: 16),
              Text(
                _isRegistering ? 'Daftar Akun Baru' : 'Tes Client User kelompok 5',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              
              if (_isRegistering) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 24),
              
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleAuth,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: Text(_isRegistering ? 'DAFTAR' : 'MASUK'),
                    ),
              const SizedBox(height: 16),
              if (!_isRegistering)
                const Text(
                  'Akun admin/dishub hanya dapat login melalui website desktop khusus admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.redAccent),
                ),
              if (!_isRegistering) const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isRegistering = !_isRegistering),
                child: Text(_isRegistering
                    ? 'Sudah punya akun? Masuk di sini'
                    : 'Belum punya akun? Daftar di sini'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}