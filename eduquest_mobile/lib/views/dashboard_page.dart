import 'dart:async';
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
  final TextEditingController _answerController = TextEditingController();
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

  // =====================================================================
  // 📍 PERBAIKAN #1: Data pertanyaan disimpan di STATE, bukan dibuat ulang
  // di dalam build(). Ini mencegah list "refresh"/lompat ke atas setiap
  // kali setState() dipanggil (misalnya saat like ditekan).
  // =====================================================================
  List<Map<String, dynamic>> _cachedQuestions = [];
  // 📍 PERBAIKAN #2: Data profil penulis pertanyaan diambil SEKALI dalam
  // satu query (bukan satu query per kartu). Menghilangkan N+1 query yang
  // jadi penyebab utama aplikasi "Not Responding".
  Map<String, Map<String, dynamic>> _userDataMap = {};
  bool _isLoadingQuestions = true;

  // 📍 Untuk debounce pencarian & mencegah query bertumpuk
  Timer? _searchDebounce;
  int _loadRequestId = 0; // menandai request terbaru, mengabaikan hasil basi
  bool _isLikeProcessing = false; // mencegah tap ganda saat like

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    _initPrefs();
    _checkAndResetStreak();
    _refreshUserData(); // di dalamnya akan memanggil _loadQuestions()
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  // 📍 Inisialisasi SharedPreferences
  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {});
  }

  // --- LOGIKA STREAK HARIAN (Reset jam 12 malam) ---
  Future<void> _checkAndResetStreak() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? lastActiveStr = prefs.getString(
      'last_active_date_${currentUser.username}',
    );

    DateTime now = DateTime.now();
    DateTime todayMidnight = DateTime(now.year, now.month, now.day);

    final db = await DbHelper().database;

    if (lastActiveStr != null) {
      DateTime lastActive = DateTime.parse(lastActiveStr);
      DateTime lastActiveMidnight = DateTime(
        lastActive.year,
        lastActive.month,
        lastActive.day,
      );

      int difference = todayMidnight.difference(lastActiveMidnight).inDays;

      if (difference == 1) {
        // Login di hari berikutnya (Streak Bertambah)
        int newStreak = currentUser.streakCount + 1;
        await db.rawUpdate(
          'UPDATE users SET streak_count = ? WHERE username = ?',
          [newStreak, currentUser.username],
        );
      } else if (difference > 1) {
        // Terlewat lebih dari 1 hari (Streak Reset ke 1)
        await db.rawUpdate(
          'UPDATE users SET streak_count = ? WHERE username = ?',
          [1, currentUser.username],
        );
      }
      // Jika difference == 0 (Hari yang sama), tidak terjadi apa-apa
    } else {
      // Login pertama kali
      await db.rawUpdate(
        'UPDATE users SET streak_count = ? WHERE username = ?',
        [1, currentUser.username],
      );
    }

    // Simpan waktu aktif hari ini
    await prefs.setString(
      'last_active_date_${currentUser.username}',
      now.toIso8601String(),
    );
  }

  // --- SINKRONISASI DATA DAN KATEGORI ---
  Future<void> _refreshUserData() async {
    final dbHelper = DbHelper();
    final updatedUser = await dbHelper.getUserData(currentUser.username ?? '');

    // 📍 Mengambil hanya kategori yang benar-benar ada di tabel pertanyaan
    final db = await dbHelper.database;
    final List<Map<String, dynamic>> categoryRes = await db.rawQuery(
      'SELECT DISTINCT category FROM questions',
    );

    List<String> fetchedCategories = ["Semua"];
    for (var row in categoryRes) {
      if (row['category'] != null &&
          row['category'].toString().trim().isNotEmpty) {
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

    // 📍 Muat ulang daftar pertanyaan (di luar setState karena async)
    await _loadQuestions();
  }

  // =====================================================================
  // 📍 PERBAIKAN #3: Fungsi baru untuk memuat pertanyaan SATU KALI beserta
  // data profil semua penulisnya dalam satu query tambahan (bukan query
  // per kartu seperti sebelumnya).
  // =====================================================================
  Future<void> _loadQuestions() async {
    // 📍 Tandai request ini sebagai yang terbaru. Kalau ada request lain
    // yang lebih baru selesai duluan, hasil request lama akan diabaikan
    // (mencegah query bertumpuk/tabrakan saat mengetik cepat di pencarian).
    final int requestId = ++_loadRequestId;

    if (mounted) {
      setState(() {
        _isLoadingQuestions = true;
      });
    }

    try {
      final rawQuestions = await DbHelper().getQuestions(
        _searchQuery,
        _selectedCategory,
      );

      // 📍 PENTING: hasil query sqflite bersifat READ-ONLY (QueryRow),
      // tidak bisa langsung di-assign seperti `question['likes'] = ...`.
      // Maka di sini kita salin ke Map biasa yang bisa diedit, supaya
      // optimistic update di _likeQuestion tidak lagi throw
      // "Unsupported operation: read-only".
      final questions = rawQuestions
          .map((q) => Map<String, dynamic>.from(q))
          .toList();

      Map<String, Map<String, dynamic>> userDataMap = {};
      try {
        final db = await DbHelper().database;
        final usernames = questions
            .map((q) => q['username'].toString())
            .toSet()
            .toList();
        if (usernames.isNotEmpty) {
          final placeholders = List.filled(usernames.length, '?').join(',');
          final userRows = await db.rawQuery(
            'SELECT * FROM users WHERE username IN ($placeholders)',
            usernames,
          );
          for (var row in userRows) {
            userDataMap[row['username'].toString()] = row;
          }
        }
      } catch (e) {
        // 📍 Kalau query foto profil gagal (misal nama kolom beda),
        // jangan sampai seluruh daftar pertanyaan ikut gagal ditampilkan.
        debugPrint('Gagal memuat data user untuk kartu pertanyaan: $e');
      }

      // Kalau sudah ada request yang lebih baru dari ini, buang hasil ini.
      if (requestId != _loadRequestId) return;

      if (mounted) {
        setState(() {
          _cachedQuestions = questions;
          _userDataMap = userDataMap;
          _isLoadingQuestions = false;
        });
      }
    } catch (e, stack) {
      debugPrint('Gagal memuat daftar pertanyaan: $e\n$stack');
      if (requestId == _loadRequestId && mounted) {
        setState(() {
          _isLoadingQuestions = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal memuat pertanyaan. Coba tarik ke bawah untuk refresh.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // 📍 FUNGSI LIKE PERTANYAAN (Diperbarui dengan Notifikasi)
  // =====================================================================
  // 📍 PERBAIKAN #4: Update dilakukan secara lokal (optimistic update) pada
  // objek yang sama di _cachedQuestions, sehingga TIDAK perlu query ulang
  // seluruh daftar pertanyaan dari database. UI langsung berubah dan posisi
  // scroll tidak ikut lompat ke atas.
  // =====================================================================
  Future<void> _likeQuestion(Map<String, dynamic> question) async {
    if (_prefs == null) return;
    if (_isLikeProcessing)
      return; // 📍 Cegah tap berkali-kali saat proses berjalan
    _isLikeProcessing = true;

    try {
      int questionId = question['id'] as int;
      String likeKey = 'liked_q_${questionId}_${currentUser.username}';
      bool isLiked = _prefs!.getBool(likeKey) ?? false;

      final db = await DbHelper().database;

      // 📍 Ambil nilai likes saat ini dengan aman.
      int currentLikes =
          int.tryParse(question['likes']?.toString() ?? '0') ?? 0;

      debugPrint(
        'LIKE DEBUG: questionId=$questionId isLiked(sebelum)=$isLiked currentLikes=$currentLikes',
      );

      if (isLiked) {
        // 📍 Aman dari nilai minus: kalau likes sudah 0, tetap 0 (tidak error).
        await db.rawUpdate(
          'UPDATE questions SET likes = CASE WHEN likes > 0 THEN likes - 1 ELSE 0 END WHERE id = ?',
          [questionId],
        );
        await _prefs!.setBool(likeKey, false);
        question['likes'] = currentLikes > 0 ? currentLikes - 1 : 0;
      } else {
        await db.rawUpdate(
          'UPDATE questions SET likes = likes + 1 WHERE id = ?',
          [questionId],
        );
        await _prefs!.setBool(likeKey, true);
        question['likes'] = currentLikes + 1;
      }

      // 📍 PENTING: setState dipanggil SEGERA setelah update inti berhasil,
      // sebelum langkah tambahan (kirim notifikasi) yang jika gagal
      // sebelumnya bisa membuat tampilan tidak ter-update.
      debugPrint(
        'LIKE DEBUG: questionId=$questionId likes(sesudah)=${question['likes']}',
      );
      if (mounted) setState(() {});

      // 📍 Kirim notifikasi HANYA saat like (bukan unlike), dibungkus
      // try-catch sendiri supaya kegagalan di sini tidak mempengaruhi
      // tampilan like yang sudah ter-update di atas.
      if (!isLiked) {
        try {
          await DbHelper().insertNotification(
            question['username'],
            currentUser.username ?? '',
            'like_q',
            question['question'],
          );
        } catch (e) {
          debugPrint('Gagal mengirim notifikasi like: $e');
        }
      }
    } catch (e, stack) {
      debugPrint('Gagal memproses like: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyukai pertanyaan, coba lagi.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _isLikeProcessing = false;
    }
  }

  void _onItemTapped(int index) async {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0 || index == 4) {
      await _refreshUserData();
    }
  }

  // 📍 FUNGSI POP-UP NOTIFIKASI DINAMIS
  void _showNotificationBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Notifikasi",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: DbHelper().getNotifications(
                    currentUser.username ?? '',
                  ),
                  builder: (context, snapshot) {
                    List<Widget> listItems = [];

                    // 1. NOTIFIKASI INTERAKSI (Like & Jawaban)
                    if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                      listItems.add(
                        const Text(
                          "Aktivitas Terbaru",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      );
                      listItems.add(const SizedBox(height: 8));

                      for (var notif in snapshot.data!) {
                        String userImg = notif['profile_image'] ?? '';
                        bool isLike = notif['type'].startsWith('like');

                        String pesanNotif = "";
                        if (notif['type'] == 'like_q')
                          pesanNotif = "menyukai pertanyaanmu";
                        else if (notif['type'] == 'like_a')
                          pesanNotif = "menyukai jawabanmu";
                        else if (notif['type'] == 'answer')
                          pesanNotif = "menjawab pertanyaanmu";

                        listItems.add(
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: _primaryPurple,
                                  backgroundImage: userImg.isNotEmpty
                                      ? FileImage(File(userImg))
                                      : null,
                                  child: userImg.isEmpty
                                      ? Text(
                                          notif['actor'][0].toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        )
                                      : null,
                                ),
                                CircleAvatar(
                                  radius: 8,
                                  backgroundColor: isLike
                                      ? Colors.pink
                                      : Colors.blue,
                                  child: Icon(
                                    isLike ? Icons.favorite : Icons.chat_bubble,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            title: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: notif['actor'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: " $pesanNotif"),
                                ],
                              ),
                            ),
                            subtitle: Text(
                              "\"${notif['content_preview']}\"",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            trailing: Text(
                              notif['created_at'].toString().split(' ')[0],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                        listItems.add(const Divider(height: 8));
                      }
                      listItems.add(const SizedBox(height: 16));
                    }

                    // 2. NOTIFIKASI SISTEM
                    listItems.add(
                      const Text(
                        "Sistem",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    );
                    listItems.add(const SizedBox(height: 8));
                    listItems.add(
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.shade100,
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.amber,
                          ),
                        ),
                        title: const Text(
                          "Selamat datang di EduQuest!",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text(
                          "Mulai petualangan belajarmu hari ini.",
                        ),
                      ),
                    );

                    return ListView(children: listItems);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- FUNGSI POP-UP BANTU JAWAB ---
  void _showAnswerBottomSheet(
    BuildContext context,
    Map<String, dynamic> question,
  ) {
    final TextEditingController ansController = TextEditingController();
    XFile? ansImage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Bantu Jawab ${question['username']}",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (ansImage != null)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(ansImage!.path),
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setSheetState(() => ansImage = null),
                            child: const CircleAvatar(
                              backgroundColor: Colors.red,
                              radius: 12,
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final img = await _picker.pickImage(
                                source: ImageSource.camera,
                              );
                              if (img != null)
                                setSheetState(() => ansImage = img);
                            },
                            icon: const Icon(Icons.camera_alt),
                            label: const Text("Kamera"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final img = await _picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (img != null)
                                setSheetState(() => ansImage = img);
                            },
                            icon: const Icon(Icons.photo_library),
                            label: const Text("Galeri"),
                          ),
                        ),
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
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () async {
                        String answerText = ansController.text
                            .trim(); // Pastikan pakai ansController ya

                        // Boleh kirim foto saja (tanpa teks) atau teks saja
                        if (answerText.isEmpty && ansImage == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Jawaban atau foto tidak boleh kosong!',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // 1. Simpan ke database (Jawaban + Foto)
                        final db = await DbHelper().database;
                        await db.insert('answers', {
                          'question_id': question['id'],
                          'username': currentUser.username,
                          'content': answerText,
                          'image_path':
                              ansImage?.path ??
                              '', // 📍 INI YANG SEBELUMNYA HILANG!
                          'likes': 0,
                          'created_at': DateFormat(
                            'dd/MM/yyyy HH:mm',
                          ).format(DateTime.now()),
                        });

                        // 2. Tambah jumlah komentar di pertanyaan
                        await db.rawUpdate(
                          'UPDATE questions SET comments = comments + 1 WHERE id = ?',
                          [question['id']],
                        );

                        // 3. Kirim Notifikasi ke pembuat pertanyaan
                        await DbHelper().insertNotification(
                          question['username'],
                          currentUser.username ?? '',
                          'answer',
                          question['question'],
                        );

                        // 4. TUTUP POP-UP & TAMPILKAN PESAN SUKSES ✨
                        if (context.mounted) {
                          Navigator.pop(
                            context,
                          ); // Menutup bottom sheet (pop-up)

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Hore! Jawabanmu berhasil dikirim. 🎉',
                              ),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }

                        // 5. Bersihkan form & Refresh data
                        ansController.clear();
                        setSheetState(
                          () => ansImage = null,
                        ); // 📍 Pastikan fotonya di-reset
                        _refreshUserData();
                        setState(() {});
                      },
                      child: const Text(
                        "Kirim Jawaban",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
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
      body: IndexedStack(index: _selectedIndex, children: pages),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BuatPertanyaanPage(user: currentUser),
                  ),
                );
                if (result == true) {
                  await _refreshUserData();
                  setState(() {});
                }
              },
              backgroundColor: _primaryPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.edit, color: Colors.white),
            )
          : null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
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
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Beranda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.auto_awesome_outlined),
                activeIcon: Icon(Icons.auto_awesome),
                label: 'AI Helper',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people_outline),
                activeIcon: Icon(Icons.people),
                label: 'Ruang Belajar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite_border),
                activeIcon: Icon(Icons.favorite),
                label: 'Pet Ku',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profil',
              ),
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
                    top: 60,
                    left: 20,
                    right: 20,
                    bottom: 50,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryPurple,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(40),
                    ),
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
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.notifications_none,
                                color: Colors.white,
                              ),
                              onPressed: _showNotificationBottomSheet,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Mau belajar apa hari ini?",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatCard(
                            "Poin",
                            "${currentUser.points}",
                            Icons.emoji_events,
                            Colors.amber,
                          ),
                          _buildStatCard(
                            "Streak",
                            "${currentUser.streakCount} hari",
                            Icons.local_fire_department,
                            Colors.orange,
                          ),
                          _buildStatCard(
                            "Level",
                            "${currentUser.petLevel}",
                            Icons.trending_up,
                            Colors.greenAccent,
                          ),
                        ],
                      ),
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
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                        // 📍 Debounce: tunggu 400ms setelah user berhenti mengetik
                        // sebelum query ke database, supaya tidak query di
                        // setiap huruf yang diketik (penyebab macet/lag).
                        _searchDebounce?.cancel();
                        _searchDebounce = Timer(
                          const Duration(milliseconds: 400),
                          () {
                            _loadQuestions();
                          },
                        );
                      },
                      decoration: InputDecoration(
                        hintText: "Cari pertanyaan atau akun orang...",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 45),

            // 📍 HASIL PENCARIAN AKUN (DITAMBAHKAN DI SINI)
            if (_searchQuery.isNotEmpty)
              FutureBuilder<List<Map<String, dynamic>>>(
                future: DbHelper().searchUsers(_searchQuery),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty)
                    return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Text(
                          "Hasil Pencarian Akun",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
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
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PublicProfilePage(
                                      targetUser: userResult,
                                      currentUser: currentUser,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 12),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundColor: _primaryPurple,
                                      backgroundImage: userImg.isNotEmpty
                                          ? FileImage(File(userImg))
                                          : null,
                                      child: userImg.isEmpty
                                          ? Text(
                                              userResult['username'][0]
                                                  .toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      userResult['username'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
              // =================================================================
              // 📍 PERBAIKAN #5: Tidak lagi memakai FutureBuilder dengan Future
              // yang dibuat ulang setiap build(). Sekarang langsung memakai data
              // dari state (_cachedQuestions) yang hanya berubah saat memang
              // perlu dimuat ulang (search, ganti kategori, refresh, dsb).
              // =================================================================
              child: _isLoadingQuestions
                  ? const Center(child: CircularProgressIndicator())
                  : _cachedQuestions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            Icon(
                              Icons.forum_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "Belum ada pertanyaan di kategori ini.\nJadilah yang pertama bertanya!",
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      children: _cachedQuestions.map((q) {
                        return _buildQuestionCard(questionData: q);
                      }).toList()..add(const SizedBox(height: 80)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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
        // 📍 Muat ulang pertanyaan sesuai kategori yang dipilih
        _loadQuestions();
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
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard({required Map<String, dynamic> questionData}) {
    List<String> tags = (questionData['tags'] as String).split(',');
    int questionId = questionData['id'];

    // 📍 Cek apakah user sudah melike ini
    bool isLiked =
        _prefs?.getBool('liked_q_${questionId}_${currentUser.username}') ??
        false;

    // =====================================================================
    // 📍 PERBAIKAN #6: Data profil penulis diambil dari cache (_userDataMap)
    // yang sudah dimuat sekali bersamaan dengan daftar pertanyaan — TIDAK
    // ada lagi query database per kartu di sini. Ini yang paling berdampak
    // ke masalah "Not Responding".
    // =====================================================================
    final authorData = _userDataMap[questionData['username']];
    final String profileImgPath = authorData?['profile_image'] ?? '';

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DetailPertanyaanPage(question: questionData, user: currentUser),
          ),
        );
        // Refresh setelah kembali untuk update jumlah like/komen
        _loadQuestions();
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
              offset: const Offset(0, 4),
            ),
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PublicProfilePage(
                            targetUser: authorData,
                            currentUser: currentUser,
                          ),
                        ),
                      );
                    }
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _primaryPurple,
                        radius: 18,
                        backgroundImage: profileImgPath.isNotEmpty
                            ? FileImage(File(profileImgPath))
                            : null,
                        child: profileImgPath.isEmpty
                            ? Text(
                                questionData['username'][0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            questionData['username'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                questionData['created_at'].toString().split(
                                  ' ',
                                )[0],
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _primaryPurple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    questionData['category'],
                    style: TextStyle(
                      color: _primaryPurple,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              questionData['question'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              questionData['description'],
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: tags
                  .map(
                    (tag) => Text(
                      tag,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
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
                      onTap: () => _likeQuestion(questionData),
                      child: Row(
                        children: [
                          Icon(
                            isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                            size: 18,
                            color: isLiked
                                ? Colors.blueAccent
                                : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${questionData['likes']}",
                            style: TextStyle(
                              color: isLiked
                                  ? Colors.blueAccent
                                  : Colors.grey.shade600,
                              fontWeight: isLiked
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${questionData['actual_comment_count'] ?? questionData['comments']}",
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: () =>
                      _showAnswerBottomSheet(context, questionData),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Bantu Jawab",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
