import 'package:flutter/material.dart';
import '../models/user_model.dart';
import 'ai_helper_page.dart';

class DashboardPage extends StatefulWidget {
  final UserModel user;

  const DashboardPage({super.key, required this.user});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;

  // Warna ungu utama sesuai gambar
  final Color _primaryPurple = const Color(0xFF7B61FF);

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Daftar halaman sesuai menu yang dipilih
    final List<Widget> pages = [
      _buildHomeContent(), // Halaman Beranda Utama
      const AiHelperPage(),
      _buildPlaceholder("Ruang Belajar", Icons.people),
      _buildPlaceholder("Pet Ku", Icons.favorite),
      _buildPlaceholder("Profil", Icons.person),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Latar belakang abu-abu sangat muda
      
      // Menggunakan body biasa, tanpa AppBar bawaan agar desain atasnya bisa melengkung
      body: pages[_selectedIndex],

      // Tombol Mengambang (FAB) di pojok kanan bawah
      floatingActionButton: _selectedIndex == 0 
        ? FloatingActionButton(
            onPressed: () {},
            backgroundColor: _primaryPurple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.add, color: Colors.white),
          ) 
        : null,

      // Custom Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
          ]
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: _primaryPurple,
            unselectedItemColor: Colors.grey.shade400,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Beranda'),
              BottomNavigationBarItem(icon: Icon(Icons.auto_awesome_outlined), activeIcon: Icon(Icons.auto_awesome), label: 'AI Helper'),
              BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Ruang Belajar'),
              BottomNavigationBarItem(icon: Icon(Icons.favorite_border), activeIcon: Icon(Icons.favorite), label: 'Pet Ku'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // KUMPULAN WIDGET HALAMAN BERANDA (HOME)
  // ==========================================

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Bagian Header (Ungu) dan Search Bar yang menimpa (Stack)
          Stack(
            clipBehavior: Clip.none, // Penting agar search bar bisa menembus batas ungu
            children: [
              // Latar Belakang Ungu Melengkung
              Container(
                padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 50),
                decoration: BoxDecoration(
                  color: _primaryPurple,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sapaan dan Tombol Plus Atas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Halo, ${widget.user.username}! 👋",
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.add, color: Colors.white),
                            onPressed: () {},
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Mau belajar apa hari ini?",
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    
                    // Deretan Kartu Status (Poin, Streak, Level)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatCard("Poin", "${widget.user.points}", Icons.emoji_events, Colors.amber),
                        _buildStatCard("Streak", "${widget.user.streakCount} hari", Icons.local_fire_department, Colors.orange),
                        _buildStatCard("Level", "${widget.user.petLevel}", Icons.trending_up, Colors.greenAccent),
                      ],
                    )
                  ],
                ),
              ),

              // Kotak Pencarian (Search Bar) - Posisinya melayang di antara ungu dan putih
              Positioned(
                bottom: -25,
                left: 20,
                right: 20,
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Cari pertanyaan atau topik...",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
              )
            ],
          ),
          
          const SizedBox(height: 45), // Jarak pengganti Search Bar yang menjorok ke bawah

          // Kategori Topik (Scroll Horizontal)
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildCategoryChip("Semua", true),
                _buildCategoryChip("Matematika", false),
                _buildCategoryChip("Fisika", false),
                _buildCategoryChip("Kimia", false),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // Daftar Kartu Pertanyaan (Feed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                _buildQuestionCard(
                  name: "Budi Santoso",
                  date: "23/5/2026",
                  category: "Matematika",
                  question: "Cara menghitung integral tentu dari fungsi trigonometri?",
                  desc: "Saya bingung bagaimana menghitung ∫(0 to π/2) sin(x)cos(x) dx. Apakah harus pakai substitusi at...",
                  tags: ["#Kalkulus", "#Integral", "#Trigonometri"],
                  likes: 12,
                  comments: 2,
                  avatarColor: const Color(0xFF7B61FF),
                  initial: "B",
                ),
                _buildQuestionCard(
                  name: "Siti Nurhaliza",
                  date: "23/5/2026",
                  category: "Fisika",
                  question: "Kenapa resultan gaya bisa nol tapi benda tetap bergerak?",
                  desc: "Di hukum Newton 1 dikatakan jika resultan gaya nol maka benda diam atau bergerak lurus bera...",
                  tags: ["#Dinamika", "#HukumNewton"],
                  likes: 5,
                  comments: 1,
                  avatarColor: const Color(0xFF5C6BC0),
                  initial: "S",
                ),
                const SizedBox(height: 80), // Jarak ekstra agar card paling bawah tidak tertutup Navbar
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- KOMPONEN BANTUAN UI ---

  // 1. Kartu Status Kecil (Poin, Streak, Level)
  Widget _buildStatCard(String title, String value, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15), // Efek transparan/glassmorphism
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 14),
                const SizedBox(width: 4),
                Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  // 2. Tombol Kategori Topik
  Widget _buildCategoryChip(String label, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? _primaryPurple : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? null : Border.all(color: Colors.grey.shade300),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey.shade600,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // 3. Kartu Pertanyaan Feed Forum
  Widget _buildQuestionCard({
    required String name, required String date, required String category, required String question,
    required String desc, required List<String> tags, required int likes, required int comments,
    required Color avatarColor, required String initial
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Profil & Kategori
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: avatarColor, radius: 18, child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(date, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _primaryPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(category, style: TextStyle(color: _primaryPurple, fontSize: 11, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 16),
          // Judul dan Isi
          Text(question, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          Text(desc, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
          const SizedBox(height: 12),
          // Tags
          Wrap(
            spacing: 8,
            children: tags.map((tag) => Text(tag, style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500))).toList(),
          ),
          const SizedBox(height: 16),
          // Footer (Likes, Comments, Button)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.thumb_up_outlined, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text("$likes", style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(width: 16),
                  Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text("$comments", style: TextStyle(color: Colors.grey.shade600)),
                ],
              ),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  elevation: 0,
                ),
                child: const Text("Bantu Jawab", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          )
        ],
      ),
    );
  }

  // 4. Halaman Placeholder untuk menu Navbar lainnya
  Widget _buildPlaceholder(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text("Halaman $title", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 8),
          const Text("Sedang dalam pengembangan 🚀", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}