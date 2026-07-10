import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'ai_helper_page.dart';
import 'ruang_belajar_page.dart';
import '../core/db_helper.dart';
import 'pet_ku_page.dart';
import 'buat_pertanyaan_page.dart';
import 'detail_pertanyaan_page.dart';
import 'profil_page.dart';
import 'public_profile_page.dart'; // 📍 Import Halaman Profil Publik

class DashboardPage extends StatefulWidget {
  final UserModel user;
  const DashboardPage({super.key, required this.user});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selectedIndex = 0;
  final Color _primaryPurple = const Color(0xFF7B61FF);

  // State untuk Data User
  late UserModel currentUser;

  // State untuk Forum & Kategori Dinamis
  String _searchQuery = "";
  String _selectedCategory = "Semua";
  List<String> _availableCategories = ["Semua"]; 
  final ImagePicker _picker = ImagePicker();

  // 📍 Menyimpan status like di memori HP
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    _initPrefs(); 
    _checkAndResetStreak(); 
    _refreshUserData();
  }

  // 📍 Inisialisasi SharedPreferences
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {});
  }

  // --- LOGIKA STREAK HARIAN (Reset jam 12 malam) ---
  Future<void> _checkAndResetStreak() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastActiveStr = prefs.getString('last_active_date_${currentUser.username}');
    
    DateTime now = DateTime.now();
    DateTime todayMidnight = DateTime(now.year, now.month, now.day); 

    final db = await DbHelper().database;

    if (lastActiveStr != null) {
      DateTime lastActive = DateTime.parse(lastActiveStr);
      DateTime lastActiveMidnight = DateTime(lastActive.year, lastActive.month, lastActive.day);

      int difference = todayMidnight.difference(lastActiveMidnight).inDays;

      if (difference == 1) {
        // Login di hari berikutnya (Streak Bertambah)
        int newStreak = currentUser.streakCount + 1;
        await db.rawUpdate('UPDATE users SET streak_count = ? WHERE username = ?', [newStreak, currentUser.username]);
      } else if (difference > 1) {
        // Terlewat lebih dari 1 hari (Streak Reset ke 1)
        await db.rawUpdate('UPDATE users SET streak_count = ? WHERE username = ?', [1, currentUser.username]);
      }
      // Jika difference == 0 (Hari yang sama), tidak terjadi apa-apa
    } else {
      // Login pertama kali
      await db.rawUpdate('UPDATE users SET streak_count = ? WHERE username = ?', [1, currentUser.username]);
    }
    
    // Simpan waktu aktif hari ini
    await prefs.setString('last_active_date_${currentUser.username}', now.toIso8601String());
  }

  // --- SINKRONISASI DATA DAN KATEGORI ---
  Future<void> _refreshUserData() async {
    final dbHelper = DbHelper();
    final updatedUser = await dbHelper.getUserData(currentUser.username ?? '');
    
    // 📍 Mengambil hanya kategori yang benar-benar ada di tabel pertanyaan
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> categoryRes = await db.rawQuery('SELECT DISTINCT category FROM questions');
    
    List<String> fetchedCategories = ["Semua"];
    for (var row in categoryRes) {
      if (row['category'] != null && row['category'].toString().trim().isNotEmpty) {
        fetchedCategories.add(row['category'].toString());
      }
    }

    if (mounted) {
      setState(() {
        if (updatedUser != null) currentUser = updatedUser;
        _availableCategories = fetchedCategories; 
        
        // Reset pilihan jika kategori yang sedang dipilih ternyata sudah tidak ada
        if (!_availableCategories.contains(_selectedCategory)) {
          _selectedCategory = "Semua";
        }
      });
    }
  }

  // --- FUNGSI LIKE PERTANYAAN (Diperbaiki 1 Akun 1 Like) ---
  Future<void> _likeQuestion(int questionId) async {
    if (_prefs == null) return;

    // Membuat kunci unik (misal: liked_q_5_Budi)
    String likeKey = 'liked_q_${questionId}_${currentUser.username}';
    bool isLiked = _prefs!.getBool(likeKey) ?? false;

    final db = await DbHelper().database;

    if (isLiked) {
      // Batal Like (Unlike)
      await db.rawUpdate('UPDATE questions SET likes = likes - 1 WHERE id = ?', [questionId]);
      await _prefs!.setBool(likeKey, false);
    } else {
      // Beri Like
      await db.rawUpdate('UPDATE questions SET likes = likes + 1 WHERE id = ?', [questionId]);
      await _prefs!.setBool(likeKey, true);
    }
    
    setState(() {}); // Refresh UI
  }

  void _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0 || index == 4) {
      await _refreshUserData();
    }
  }

  // --- FUNGSI POP-UP NOTIFIKASI ---
  void _showNotificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 350,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Notifikasi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber.shade100,
                        child: const Icon(Icons.auto_awesome, color: Colors.amber),
                      ),
                      title: const Text("Selamat datang di EduQuest!", style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text("Mulai petualangan belajarmu, kumpulkan poin, dan tingkatkan level Pet kamu hari ini."),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue.shade100,
                        child: const Icon(Icons.local_fire_department, color: Colors.blue),
                      ),
                      title: const Text("Streak Harian Aktif"),
                      subtitle: const Text("Jangan lupa login setiap hari agar streak belajarmu tidak putus!"),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- FUNGSI POP-UP BANTU JAWAB ---
  void _showAnswerBottomSheet(BuildContext context, Map<String, dynamic> question) {
    final TextEditingController ansController = TextEditingController();
    XFile? ansImage;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) {
          return StatefulBuilder(builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom, 
                left: 24, right: 24, top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bantu Jawab ${question['username']}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ansController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: "Ketik penjelasanmu di sini...",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (ansImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(ansImage!.path),
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover)),
                        Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                                onTap: () =>
                                    setSheetState(() => ansImage = null),
                                child: const CircleAvatar(
                                    backgroundColor: Colors.red,
                                    radius: 12,
                                    child: Icon(Icons.close,
                                        color: Colors.white, size: 12))))
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                            child: OutlinedButton.icon(
                                onPressed: () async {
                                  final img = await _picker.pickImage(
                                      source: ImageSource.camera);
                                  if (img != null)
                                    setSheetState(() => ansImage = img);
                                },
                                icon: const Icon(Icons.camera_alt),
                                label: const Text("Kamera"))),
                        const SizedBox(width: 12),
                        Expanded(
                            child: OutlinedButton.icon(
                                onPressed: () async {
                                  final img = await _picker.pickImage(
                                      source: ImageSource.gallery);
                                  if (img != null)
                                    setSheetState(() => ansImage = img);
                                },
                                icon: const Icon(Icons.photo_library),
                                label: const Text("Galeri"))),
                      ],
                    ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      onPressed: () async {
                        if (ansController.text.trim().isEmpty &&
                            ansImage == null) return;

                        await DbHelper().insertAnswer({
                          'question_id': question['id'],
                          'username': currentUser.username ?? '',
                          'content': ansController.text.trim(),
                          'image_path': ansImage?.path ?? '',
                          'created_at': DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                          'likes': 0 // Set default likes
                        });

                        final db = await DbHelper().database;
                        await db.rawUpdate('UPDATE questions SET comments = comments + 1 WHERE id = ?', [question['id']]);

                        await DbHelper().addPoints(currentUser.username ?? '', 10);
                        await _refreshUserData(); 

                        if (!context.mounted) return;
                        Navigator.pop(context); 
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Jawaban terkirim! +10 Poin Pet 🌟"),
                                backgroundColor: Colors.green));
                        setState(() {}); 
                      },
                      child: const Text("Kirim Jawaban",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          });
        });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeContent(),
      AiHelperPage(user: currentUser),
      RuangBelajarPage(user: currentUser),
      PetKuPage(user: currentUser),
      ProfilPage(user: currentUser),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => BuatPertanyaanPage(user: currentUser)),
                );
                if (result == true) {
                  await _refreshUserData();
                  setState(() {});
                }
              },
              backgroundColor: _primaryPurple,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5))
        ]),
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
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Beranda'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.auto_awesome_outlined),
                  activeIcon: Icon(Icons.auto_awesome),
                  label: 'AI Helper'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.people_outline),
                  activeIcon: Icon(Icons.people),
                  label: 'Ruang Belajar'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.favorite_border),
                  activeIcon: Icon(Icons.favorite),
                  label: 'Pet Ku'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await _refreshUserData();
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.only(
                      top: 60, left: 20, right: 20, bottom: 50),
                  decoration: BoxDecoration(
                    color: _primaryPurple,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Halo, ${currentUser.username}! 👋",
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500),
                          ),
                          Container(
                            decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.notifications_none,
                                  color: Colors.white),
                              onPressed: _showNotificationBottomSheet, 
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text("Mau belajar apa hari ini?",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatCard("Poin", "${currentUser.points}",
                              Icons.emoji_events, Colors.amber),
                          _buildStatCard(
                              "Streak",
                              "${currentUser.streakCount} hari",
                              Icons.local_fire_department,
                              Colors.orange),
                          _buildStatCard("Level", "${currentUser.petLevel}",
                              Icons.trending_up, Colors.greenAccent),
                        ],
                      )
                    ],
                  ),
                ),
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
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5))
                      ],
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Cari pertanyaan atau akun orang...",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon:
                            Icon(Icons.search, color: Colors.grey.shade400),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 18),
                      ),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(height: 45),
            
            // 📍 HASIL PENCARIAN AKUN (DITAMBAHKAN DI SINI)
            if (_searchQuery.isNotEmpty)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: DbHelper().searchUsers(_searchQuery),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        child: Text("Hasil Pencarian Akun", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      ),
                      SizedBox(
                        height: 90,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: snapshot.data!.length,
                          itemBuilder: (context, index) {
                            var userResult = snapshot.data![index];
                            String userImg = userResult['profile_image'] ?? '';
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(targetUser: userResult, currentUser: currentUser)));
                              },
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: _primaryPurple,
                                      backgroundImage: userImg.isNotEmpty ? FileImage(File(userImg)) : null,
                                      child: userImg.isEmpty ? Text(userResult['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(userResult['username'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  );
                },
              ),

            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: _availableCategories.map((kategori) {
                  return _buildCategoryChip(kategori);
                }).toList(),
              ),
            ),
            
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: DbHelper().getQuestions(_searchQuery, _selectedCategory),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(Icons.forum_outlined,
                                size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 16),
                            Text(
                                "Belum ada pertanyaan di kategori ini.\nJadilah yang pertama bertanya!",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade500)),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: snapshot.data!.map((q) {
                      return _buildQuestionCard(questionData: q);
                    }).toList()
                      ..add(const SizedBox(height: 80)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color iconColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 14),
                const SizedBox(width: 4),
                Text(title,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label) {
    bool isActive = _selectedCategory == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = label;
        });
      },
      child: Container(
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
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard({required Map<String, dynamic> questionData}) {
    List<String> tags = (questionData['tags'] as String).split(',');
    int questionId = questionData['id'];

    // 📍 Cek apakah user sudah melike ini
    bool isLiked = _prefs?.getBool('liked_q_${questionId}_${currentUser.username}') ?? false;

    // 📍 MENGGUNAKAN FUTURE BUILDER UNTUK MENGAMBIL FOTO PROFIL TERBARU
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DbHelper().database.then((db) => db.query('users', where: 'username = ?', whereArgs: [questionData['username']])),
      builder: (context, userSnapshot) {
        String profileImgPath = '';
        Map<String, dynamic>? authorData;

        if (userSnapshot.hasData && userSnapshot.data!.isNotEmpty) {
          authorData = userSnapshot.data!.first;
          profileImgPath = authorData['profile_image'] ?? '';
        }

        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => DetailPertanyaanPage(
                      question: questionData, user: currentUser)),
            );
            setState(() {}); // Refresh setelah kembali untuk update jumlah like/komen
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 📍 Avatar & Nama yang bisa di-klik untuk membuka Profil
                    GestureDetector(
                      onTap: () {
                        if (authorData != null) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(targetUser: authorData!, currentUser: currentUser)));
                        }
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                              backgroundColor: _primaryPurple,
                              radius: 18,
                              backgroundImage: profileImgPath.isNotEmpty ? FileImage(File(profileImgPath)) : null,
                              child: profileImgPath.isEmpty
                                  ? Text(questionData['username'][0].toUpperCase(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold))
                                  : null),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(questionData['username'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14)),
                              Row(
                                children: [
                                  Icon(Icons.access_time,
                                      size: 12, color: Colors.grey.shade500),
                                  const SizedBox(width: 4),
                                  Text(
                                      questionData['created_at']
                                          .toString()
                                          .split(' ')[0],
                                      style: TextStyle(
                                          color: Colors.grey.shade500, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: _primaryPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(questionData['category'],
                          style: TextStyle(
                              color: _primaryPurple,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Text(questionData['question'],
                    style:
                        const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Text(questionData['description'],
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 13, height: 1.4)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: tags
                      .map((tag) => Text(tag,
                          style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)))
                      .toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // 📍 TOMBOL LIKE DENGAN WARNA DINAMIS
                        InkWell(
                          onTap: () => _likeQuestion(questionId),
                          child: Row(
                            children: [
                              Icon(isLiked ? Icons.thumb_up : Icons.thumb_up_outlined, 
                                  size: 18, 
                                  color: isLiked ? Colors.blueAccent : Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text("${questionData['likes']}", 
                                  style: TextStyle(
                                      color: isLiked ? Colors.blueAccent : Colors.grey.shade600, 
                                      fontWeight: isLiked ? FontWeight.bold : FontWeight.normal)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.chat_bubble_outline,
                            size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        Text("${questionData['comments']}",
                            style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () =>
                          _showAnswerBottomSheet(context, questionData),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryPurple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          elevation: 0),
                      child: const Text("Bantu Jawab",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}