import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inisialisasi Supabase secara global
  await Supabase.initialize(
    url: 'https://filppwcwnspbdnjesggp.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZpbHBwd2N3bnNwYmRuamVzZ2dwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkwMDY3MTgsImV4cCI6MjA5NDU4MjcxOH0.WoGRuu8bxGjWLp_4Ni1sQBug0dEyAmmxG2y0Y6zA6o8',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lapor Infrastruktur',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}