import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/db_helper.dart';
import '../models/user_model.dart';
import 'register_page.dart';

class ProfilPage extends StatefulWidget {
  final UserModel user;

  const ProfilPage({super.key, required this.user});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  final DbHelper _dbHelper = DbHelper();
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  late String _currentUsername;
  final TextEditingController _nameController = TextEditingController();

  // Variabel Data Real-time
  bool _isLoading = true;
  int _points = 0;
  int _level = 1;
  int _streak = 0;
  
  int _myQuestionsAnswered = 0; 
  int _myAnswersGiven = 0; 
  
  // Variabel Persentase
  int _aiUsagePercentage = 0;
  int _forumUsagePercentage = 0;
  int _factCheckAccuracy = 0; 

  @override
  void initState() {
    super.initState();
    _currentUsername = widget.user.username;
    _loadUserData();
  }

  // --- FUNGSI MENGAMBIL DATA DARI DATABASE ---
  Future<void> _loadUserData() async {
    final db = await _dbHelper.database;
    
    // 1. Ambil data User (Level, Poin, Streak, Foto)
    var userRes = await db.query('users', where: 'username = ?', whereArgs: [_currentUsername]);
    if (userRes.isNotEmpty) {
      _points = userRes.first['points'] as int;
      _level = userRes.first['pet_level'] as int;
      _streak = userRes.first['streak_count'] as int;
      
      String savedImage = userRes.first['profile_image'] as String;
      if (savedImage.isNotEmpty) {
        _imageFile = File(savedImage);
      }

      // Simulasi akurasi fact checker (Meningkat seiring level, maks 98%)
      _factCheckAccuracy = _points == 0 ? 0 : (65 + (_level * 6)).clamp(0, 98);
    }

    // 2. Hitung: Jumlah Pertanyaan yang SAYA buat
    var qCountRes = await db.rawQuery('SELECT COUNT(*) as total FROM questions WHERE username = ?', [_currentUsername]);
    int myQuestionsCount = (qCountRes.first['total'] as int?) ?? 0;

    // Hitung: Total komentar/jawaban yang masuk ke pertanyaan SAYA
    var qRes = await db.rawQuery('SELECT SUM(comments) as total FROM questions WHERE username = ?', [_currentUsername]);
    _myQuestionsAnswered = (qRes.first['total'] as int?) ?? 0;

    // 3. Hitung: Jawaban yang SAYA berikan di forum
    var aRes = await db.rawQuery('SELECT COUNT(*) as total FROM answers WHERE username = ?', [_currentUsername]);
    _myAnswersGiven = (aRes.first['total'] as int?) ?? 0;

    // 4. Hitung: Total Interaksi AI milik saya
    var aiRes = await db.rawQuery('SELECT COUNT(*) as total FROM chats WHERE username = ?', [_currentUsername]);
    int totalAiChats = (aiRes.first['total'] as int?) ?? 0;

    // --- LOGIKA PERHITUNGAN PERSENTASE PENGGUNAAN FITUR ---
    int totalAktivitas = myQuestionsCount + _myAnswersGiven + totalAiChats;
    
    if (totalAktivitas > 0) {
      _aiUsagePercentage = ((totalAiChats / totalAktivitas) * 100).round();
      _forumUsagePercentage = (((myQuestionsCount + _myAnswersGiven) / totalAktivitas) * 100).round();
    } else {
      _aiUsagePercentage = 0;
      _forumUsagePercentage = 0;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- FUNGSI AMBIL FOTO PROFIL ---
  Future<void> _pilihFotoProfil() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });

        await _dbHelper.updateUserProfileImage(_currentUsername, pickedFile.path);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto profil berhasil diperbarui! ✨'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil gambar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // --- FUNGSI UBAH NAMA ---
  void _tampilkanDialogUbahNama() {
    _nameController.text = _currentUsername;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Ubah Nama"),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: "Contoh: Budi Santoso",
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6B48FF))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6B48FF)),
              onPressed: () async {
                String newName = _nameController.text.trim();
                
                if (newName.isNotEmpty && newName != _currentUsername) {
                  final db = await _dbHelper.database;
                  
                  try {
                    await db.transaction((txn) async {
                      await txn.update('users', {'username': newName}, where: 'username = ?', whereArgs: [_currentUsername]);
                      await txn.update('chats', {'username': newName}, where: 'username = ?', whereArgs: [_currentUsername]);
                      await txn.update('questions', {'username': newName}, where: 'username = ?', whereArgs: [_currentUsername]);
                      await txn.update('answers', {'username': newName}, where: 'username = ?', whereArgs: [_currentUsername]);
                    });

                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setString('username', newName);

                    setState(() {
                      _currentUsername = newName;
                    });
                    
                    if (context.mounted) {
                      Navigator.pop(context); 
                      if (Navigator.canPop(context)) Navigator.pop(context); 
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama pengguna berhasil diubah!')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama ini mungkin sudah dipakai orang lain.'), backgroundColor: Colors.red));
                    }
                  }
                }
              },
              child: const Text("Simpan", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // --- FUNGSI BUKA PENGATURAN ---
  void _bukaPengaturan() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PengaturanPage(
          onUbahNama: _tampilkanDialogUbahNama,
          onHapusFoto: () async {
            setState(() => _imageFile = null);
            await _dbHelper.updateUserProfileImage(_currentUsername, "");
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF6B48FF))));
    }

    double progressValue = (_level >= 5) ? 1.0 : (_points % 50) / 50.0;
    int nextTarget = (_level >= 5) ? _points : (_level * 50);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER UNGU ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, bottom: 30, left: 24, right: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF6B48FF),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: _bukaPengaturan,
                    ),
                  ),
                  GestureDetector(
                    onTap: _pilihFotoProfil,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 47,
                            backgroundColor: const Color(0xFFE0E0E0),
                            backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                            child: _imageFile == null
                                ? const Icon(Icons.person, size: 55, color: Colors.grey)
                                : null,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, size: 16, color: Color(0xFF6B48FF)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentUsername,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.user.email, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text("Level $_level Pet Owner", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ),
            ),

            // --- KONTEN UTAMA PROFILE ---
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatBox("$_points", "Poin"),
                      const SizedBox(width: 12),
                      _buildStatBox("$_streak", "Streak"),
                      const SizedBox(width: 12),
                      _buildStatBox("$_level", "Level"),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_level >= 5 ? "Level Maksimal Tercapai!" : "Progress ke Level ${_level + 1}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("$_points/$nextTarget", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFE0E0E0),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF6B48FF)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text("Pencapaian", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildBadge("😊 Rookie", isActive: _level >= 1),
                      _buildBadge("🪄 Intermediate", isActive: _level >= 2),
                      _buildBadge("🎓 Scholar", isActive: _level >= 3),
                      _buildBadge("🕵️ Master", isActive: _level >= 4),
                      _buildBadge("🌟 Legend", isActive: _level >= 5),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text("Statistik Belajar",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C))),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      children: [
                        _buildRowStatDetail(Icons.question_answer_rounded, "Pertanyaanmu Dijawab", "$_myQuestionsAnswered"),
                        const Divider(height: 24, thickness: 0.5),
                        _buildRowStatDetail(Icons.check_circle_outline, "Jawaban Diberikan", "$_myAnswersGiven"),
                        const Divider(height: 24, thickness: 0.5),
                        _buildRowStatDetail(Icons.forum_outlined, "Rata-rata Penggunaan Forum", "$_forumUsagePercentage%"),
                        const Divider(height: 24, thickness: 0.5),
                        _buildRowStatDetail(Icons.smart_toy_outlined, "Rata-rata Penggunaan AI Helper", "$_aiUsagePercentage%"),
                        const Divider(height: 24, thickness: 0.5),
                        _buildRowStatDetail(Icons.fact_check_outlined, "Rata-rata Akurasi Fakta", "$_factCheckAccuracy%"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowStatDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF6B48FF), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w500)),
        ),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  Widget _buildStatBox(String value, String title) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, {required bool isActive}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFFF3CD) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isActive ? const Color(0xFFFFE066) : Colors.grey.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isActive ? const Color(0xFF8B5E34) : Colors.grey.shade400,
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

// ======================================================================
// HALAMAN PENGATURAN (SETTINGS PAGE) DENGAN DARK MODE
// ======================================================================
class PengaturanPage extends StatefulWidget {
  final VoidCallback onUbahNama;
  final VoidCallback onHapusFoto;

  const PengaturanPage({super.key, required this.onUbahNama, required this.onHapusFoto});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  // --- Fungsi untuk memuat status Dark Mode ---
  Future<void> _loadTheme() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    });
  }

  // --- Fungsi untuk menyimpan status Dark Mode ---
  Future<void> _toggleDarkMode(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    setState(() {
      _isDarkMode = value;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Mode Gelap diaktifkan!' : 'Mode Terang diaktifkan!'),
          backgroundColor: value ? Colors.black87 : Colors.green,
          action: SnackBarAction(
            label: 'Info',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _bukaWebEduQuest(BuildContext context) async {
    final Uri url = Uri.parse('https://www.eduquest.com');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Tidak bisa membuka URL');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Membuka web EduQuest...'), backgroundColor: Colors.blueAccent),
      );
    }
  }

  void _tampilkanDialogHapusProfil(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_off_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Hapus Foto Profil?'),
            ],
          ),
          content: const Text('Apakah kamu yakin ingin menghapus foto profilmu saat ini?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                widget.onHapusFoto();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Foto profil berhasil dihapus.'), backgroundColor: Colors.orange),
                );
              },
              child: const Text('Ya, Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _prosesLogout(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('username');

    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const RegisterPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengaturan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF9FAFB),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text("Akun & Profil", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.edit, color: Color(0xFF6B48FF)),
                  title: const Text("Ubah Nama Pengguna"),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: widget.onUbahNama,
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.no_photography_outlined, color: Colors.orange),
                  title: const Text("Hapus Foto Profil"),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () => _tampilkanDialogHapusProfil(context),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // --- BAGIAN BARU: TAMPILAN (DARK MODE) ---
          const Text("Tampilan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: SwitchListTile(
              activeColor: const Color(0xFF6B48FF),
              secondary: Icon(
                _isDarkMode ? Icons.dark_mode : Icons.light_mode, 
                color: _isDarkMode ? Colors.indigo : Colors.orange
              ),
              title: const Text("Mode Gelap (Dark Mode)"),
              value: _isDarkMode,
              onChanged: _toggleDarkMode,
            ),
          ),

          const SizedBox(height: 24),
          const Text("Bantuan & Dukungan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.language, color: Colors.blue),
              title: const Text("Kunjungi Website Kami"),
              subtitle: const Text("www.EduQuest.com", style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
              trailing: const Icon(Icons.open_in_new, color: Colors.grey, size: 18),
              onTap: () => _bukaWebEduQuest(context),
            ),
          ),

          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.red.shade300, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                foregroundColor: Colors.redAccent,
              ),
              onPressed: () => _prosesLogout(context),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text("Keluar dari Akun", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}