import 'package:flutter/material.dart';
import 'views/register_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EduQuestApp());
}

class EduQuestApp extends StatelessWidget {
  const EduQuestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduQuest Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6366F1)),
        useMaterial3: true,
      ),
      home: const RegisterPage(), // Mengarahkan langsung ke halaman register untuk uji coba awal
    );
  }
}