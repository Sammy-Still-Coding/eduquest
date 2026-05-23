import 'package:flutter/material.dart';
import '../core/db_helper.dart';
import '../models/user_model.dart';
import 'dashboard_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _dbHelper = DbHelper();
  
  final _identifierController = TextEditingController(); // Bisa diisi email atau username
  final _passwordController = TextEditingController();
  
  bool _obscureText = true;

  void _prosesLogin() async {
    String identifier = _identifierController.text.trim();
    String password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email/Username dan Password harus diisi!')),
      );
      return;
    }

    // Panggil fungsi login dari DbHelper
    UserModel? user = await _dbHelper.loginUser(identifier, password);

    if (user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat datang kembali, ${user.username}! ✨'),
          backgroundColor: Colors.green,
        ),
      );
      
      // 📍 PINDAH KE DASHBOARD MENGGUNAKAN pushReplacement
      // (Supaya user tidak bisa menekan tombol "Back" ke halaman login lagi)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardPage(user: user)),
      );
      
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login Gagal! Email/Username atau Password salah.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Contoh ditaruh di atas teks "Mulai Petualangan!" atau "Selamat Datang!"
              Image.asset(
                'assets/images/eduquestlogo.png',
                width: 120,  // Kamu bisa atur ukurannya di sini
                height: 120,
              ),
              const Text(
                "Selamat Datang!",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xff6366F1)),
              ),
              const SizedBox(height: 8),
              const Text(
                "Masuk ke akun EduQuest kamu untuk melanjutkan belajar.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              // Input Email atau Username
              TextField(
                controller: _identifierController,
                decoration: InputDecoration(
                  labelText: 'Username atau Email',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              
              // Input Password
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 32),
              
              // Tombol Masuk
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _prosesLogin,
                  child: const Text("Masuk Akun 🚀", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              
              // Navigasi balik ke Register jika belum punya akun
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Kembali ke halaman pendaftaran
                  },
                  child: const Text("Belum punya akun? Daftar di sini"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}