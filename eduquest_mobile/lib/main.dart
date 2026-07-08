import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/db_helper.dart'; // Sesuaikan jika path foldernya berbeda
import 'models/user_model.dart'; // Sesuaikan jika path foldernya berbeda
import 'views/login_page.dart';
import 'views/dashboard_page.dart';
// import 'views/register_page.dart'; // Boleh di-comment atau dihapus jika tidak jadi home default

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EduQuestApp());
}

class EduQuestApp extends StatelessWidget {
  const EduQuestApp({super.key});

  // --- FUNGSI UNTUK MENGECEK SESI LOGIN ---
  Future<Widget> _checkSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    String? username = prefs.getString('username');

    if (isLoggedIn && username != null) {
      // Menggunakan DbHelper milikmu dan memanggil fungsi getUserData yang sudah ada
      DbHelper dbHelper = DbHelper();
      UserModel? user = await dbHelper.getUserData(username);
      
      if (user != null) {
        return DashboardPage(user: user); // Sesi valid, langsung ke Dashboard
      }
    }
    
    // Jika tidak ada sesi atau data user hilang, arahkan ke Login
    return const LoginPage();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduQuest Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6366F1)),
        useMaterial3: true,
      ),
      // Mengganti properti "home" menjadi FutureBuilder untuk cek sesi
      home: FutureBuilder<Widget>(
        future: _checkSession(),
        builder: (context, snapshot) {
          // Selama masih mengecek memori HP, tampilkan animasi loading berputar
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: CircularProgressIndicator(
                  color: Color(0xff6366F1), // Sesuai dengan warna tema utamamu
                ),
              ),
            );
          }
          // Jika pengecekan selesai, tampilkan hasilnya (Dashboard atau Login)
          return snapshot.data ?? const LoginPage();
        },
      ),
    );
  }
}