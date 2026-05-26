import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import 'register_page.dart';

class ProfilPage extends StatefulWidget {
  final UserModel user;

  const ProfilPage({super.key, required this.user});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  late String _currentUsername;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentUsername = widget.user.username;
  }

  // Fungsi membuka tautan eksternal saat www.EduQuest.com ditekan
  Future<void> _bukaWebEduQuest() async {
    final Uri url = Uri.parse('https://www.eduquest.com');
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Tidak bisa membuka $url');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Membuka web EduQuest: $url'),
          backgroundColor: Colors.blueAccent,
        ),
      );
    }
  }

  // Fungsi mengambil foto dari galeri
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diperbarui! ✨'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengambil gambar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Dialog Ubah Nama
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
              hintText: "Masukkan nama baru...",
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF6B48FF))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Batal", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B48FF)),
              onPressed: () {
                if (_nameController.text.trim().isNotEmpty) {
                  setState(() {
                    _currentUsername = _nameController.text.trim();
                  });
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Nama pengguna berhasil diubah!')),
                  );
                }
              },
              child:
                  const Text("Simpan", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Dialog Bersihkan Data Profil
  void _tampilkanDialogHapusProfil() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_off_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Hapus Data Profil?'),
            ],
          ),
          content: const Text(
              'Apakah kamu yakin ingin mengosongkan data profil ini? Tindakan ini hanya membersihkan foto profil kamu tanpa menghapus akun.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                setState(() {
                  _imageFile = null;
                });
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data profil berhasil dibersihkan.'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              child: const Text('Ya, Bersihkan',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // Bottom Sheet Menu Edit Profile
  void _tampilkanMenuEditProfile() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Pengaturan Profil",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF6B48FF)),
                title: const Text("Ubah Nama Pengguna"),
                onTap: () {
                  _tampilkanDialogUbahNama();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.no_accounts_rounded,
                    color: Colors.redAccent),
                title: const Text("Hapus Data Profil",
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  _tampilkanDialogHapusProfil();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER UNGU ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(
                  top: 60, bottom: 30, left: 24, right: 24),
              decoration: const BoxDecoration(
                color: Color(0xFF6B48FF),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
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
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : null,
                            child: _imageFile == null
                                ? const Icon(Icons.person,
                                    size: 55, color: Colors.grey)
                                : null,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt,
                              size: 16, color: Color(0xFF6B48FF)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentUsername,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _tampilkanMenuEditProfile,
                        child: const Icon(Icons.edit,
                            color: Colors.white70, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.user.email,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      "Level 1 Rookie",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14),
                    ),
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
                      _buildStatBox("5", "Poin"),
                      const SizedBox(width: 12),
                      _buildStatBox("0", "Streak"),
                      const SizedBox(width: 12),
                      _buildStatBox("1", "Level"),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Progress ke Level 2",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("5/50",
                          style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: const LinearProgressIndicator(
                      value: 5 / 50,
                      minHeight: 8,
                      backgroundColor: Color(0xFFE0E0E0),
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF6B48FF)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text("Pencapaian",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _buildBadge("😊 Rookie", isActive: true),
                      _buildBadge("🪄 Intermediate", isActive: false),
                      _buildBadge("🎓 Scholar", isActive: false),
                      _buildBadge("🕵️ Master", isActive: false),
                      _buildBadge("🌟 Legend", isActive: false),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const Text("Statistik Belajar",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E2C))),
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
                        _buildRowStatDetail(Icons.chat_bubble_outline_rounded,
                            "Pertanyaan Dijawab", "0"),
                        const Divider(height: 24, thickness: 0.5),
                        _buildRowStatDetail(
                            Icons.indeterminate_check_box_outlined,
                            "Jawaban Diberikan",
                            "0"),
                        const Divider(height: 24, thickness: 0.5),
                        _buildRowStatDetail(
                            Icons.auto_awesome_outlined, "Chat dengan AI", "4"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tombol Keluar Navigasi ke RegisterPage
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red.shade300, width: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        foregroundColor: Colors.redAccent,
                      ),
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const RegisterPage()),
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text("Keluar",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 💡 MODIFIKASI TERBARU: Sekarang yang bisa diklik hanya www.EduQuest.com
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Teks "Hubungi Kami" biasa (Abu-abu, tebal, tidak bisa diklik)
                      const Text(
                        "Hubungi Kami",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Teks "www.EduQuest.com" dibungkus InkWell (Biru, tipis, BISA DIKLIK)
                      InkWell(
                        onTap: _bukaWebEduQuest,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                          child: Text(
                            "www.EduQuest.com",
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 13,
                              fontWeight: FontWeight.w300,
                              decoration: TextDecoration
                                  .underline, // Opsional: garis bawah khas link web
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
        Text(label,
            style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87)),
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
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
        border: Border.all(
            color: isActive ? const Color(0xFFFFE066) : Colors.grey.shade200),
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
