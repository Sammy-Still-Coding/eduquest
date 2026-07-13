import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../core/db_helper.dart';
import 'public_profile_page.dart';

class DetailPertanyaanPage extends StatefulWidget {
  final Map<String, dynamic> question;
  final UserModel user;

  const DetailPertanyaanPage({super.key, required this.question, required this.user});

  @override
  State<DetailPertanyaanPage> createState() => _DetailPertanyaanPageState();
}

class _DetailPertanyaanPageState extends State<DetailPertanyaanPage> {
  final Color _primaryPurple = const Color(0xFF7B61FF);
  List<Map<String, dynamic>> _answers = [];
  Map<String, dynamic>? _authorData; // 📍 Data author yang disinkronkan
  bool _isLoading = true;
  SharedPreferences? _prefs;

  // 📍 Toggle filter: false = urutan kronologis (default, stabil, tidak pernah
  // berubah sendiri), true = diurutkan by likes terbanyak HANYA saat user
  // menekan tombol filter secara eksplisit.
  bool _sortByMostLiked = false;

  @override
  void initState() {
    super.initState();
    _initPrefsAndLoadData();
  }

  Future<void> _initPrefsAndLoadData() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadAnswersAndAuthor();
  }

  // 📍 MENGAMBIL DATA JAWABAN & DATA PENULIS PERTANYAAN
  // Query & sorting (ORDER BY likes DESC) HANYA dipanggil di sini, yaitu saat
  // pertama kali halaman dibuka. Ini sengaja TIDAK dipanggil lagi setiap kali
  // ada like baru, supaya urutan jawaban tidak berubah-ubah / "kepental" ke atas
  // tiap kali salah satu jawaban di-like (itu penyebab bug "harus like urutan").
  Future<void> _loadAnswersAndAuthor() async {
    final db = await DbHelper().database;
    final int qId = widget.question['id'];

    // 1. Ambil data author terbaru
    final authorList = await db.query('users', where: 'username = ?', whereArgs: [widget.question['username']]);
    if (authorList.isNotEmpty) _authorData = authorList.first;

    // 2. Ambil data jawaban (JOIN untuk foto profil penjawab)
    // 📍 Default-nya kronologis (id ASC), BUKAN by likes. Urutan ini akan
    // tetap sama meskipun ada like baru masuk. Sort by likes cuma dipakai
    // sementara di tampilan (lihat _sortByMostLiked), tidak menyentuh query ini.
    final List<Map<String, dynamic>> answers = await db.rawQuery('''
      SELECT answers.*, users.profile_image 
      FROM answers 
      LEFT JOIN users ON answers.username = users.username 
      WHERE answers.question_id = ? 
      ORDER BY answers.id ASC
    ''', [qId]);

    if (mounted) {
      setState(() {
        _answers = answers;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleLikeAnswer(Map<String, dynamic> answer) async {
    if (_prefs == null) return;

    final int answerId = answer['id'];
    final String likeKey = 'liked_a_${answerId}_${widget.user.username}';
    final bool isLiked = _prefs!.getBool(likeKey) ?? false;
    final int delta = isLiked ? -1 : 1;

    final db = await DbHelper().database;

    if (isLiked) {
      await db.rawUpdate('UPDATE answers SET likes = likes - 1 WHERE id = ?', [answerId]);
      await _prefs!.setBool(likeKey, false);
    } else {
      await db.rawUpdate('UPDATE answers SET likes = likes + 1 WHERE id = ?', [answerId]);
      await _prefs!.setBool(likeKey, true);

      // Kirim Notifikasi ke penjawab bahwa jawabannya disukai
      await DbHelper().insertNotification(answer['username'], widget.user.username ?? '', 'like_a', answer['content']);
    }

    // 📍 FIX: Update angka like SECARA LOKAL di posisi yang sama (by id),
    // BUKAN reload+resort seluruh list dari DB. Ini menjaga urutan jawaban
    // tetap stabil, sehingga tidak perlu "like yang di atas dulu" supaya
    // like di bawahnya bisa diproses.
    if (mounted) {
      final index = _answers.indexWhere((a) => a['id'] == answerId);
      if (index != -1) {
        setState(() {
          _answers[index] = {
            ..._answers[index],
            'likes': (_answers[index]['likes'] as int) + delta,
          };
        });
      }
    }
  }

  // 📍 List yang ditampilkan. _answers (sumber asli, urutan kronologis) tidak
  // pernah diubah urutannya; kalau _sortByMostLiked aktif, kita bikin SALINAN
  // lalu diurutkan berdasarkan likes, khusus untuk tampilan saja.
  List<Map<String, dynamic>> get _displayedAnswers {
    if (!_sortByMostLiked) return _answers;
    final sorted = List<Map<String, dynamic>>.from(_answers);
    sorted.sort((a, b) {
      final likeCompare = (b['likes'] as int).compareTo(a['likes'] as int);
      if (likeCompare != 0) return likeCompare;
      return (a['id'] as int).compareTo(b['id'] as int); // tie-breaker biar stabil
    });
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    String? authorImg = _authorData?['profile_image'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Detail Diskusi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 📍 KARTU PERTANYAAN INTI (Sinkron & Klikable)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () {
                          if (_authorData != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(targetUser: _authorData!, currentUser: widget.user)));
                          }
                        },
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: _primaryPurple,
                              backgroundImage: (authorImg != null && authorImg.isNotEmpty) ? FileImage(File(authorImg)) : null,
                              child: (authorImg == null || authorImg.isEmpty) ? Text(widget.question['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
                            ),
                            const SizedBox(width: 12),
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.question['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text(widget.question['created_at'].toString(), style: TextStyle(color: Colors.grey.shade500, fontSize: 12))]),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(widget.question['question'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      Text(widget.question['description'], style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
                      if (widget.question['image_path'] != null && widget.question['image_path'].toString().isNotEmpty)
                        Padding(padding: const EdgeInsets.only(top: 16), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(widget.question['image_path']), width: double.infinity, fit: BoxFit.cover))),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [const Icon(Icons.forum, color: Colors.blueAccent), const SizedBox(width: 8), Text("${_answers.length} Jawaban", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
                    // 📍 TOMBOL FILTER: klik untuk toggle antara urutan kronologis
                    // dan urutan like terbanyak. Sorting cuma di tampilan (_displayedAnswers),
                    // urutan asli & data di _answers tidak ikut berubah.
                    InkWell(
                      onTap: () => setState(() => _sortByMostLiked = !_sortByMostLiked),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _sortByMostLiked ? _primaryPurple.withValues(alpha: 0.12) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.thumb_up, size: 14, color: _sortByMostLiked ? _primaryPurple : Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(
                              _sortByMostLiked ? "Like Terbanyak" : "Terbaru",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _sortByMostLiked ? _primaryPurple : Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                if (_displayedAnswers.isEmpty)
                  Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Belum ada jawaban.", style: TextStyle(color: Colors.grey.shade500))))
                else
                  ..._displayedAnswers.map((answer) {
                    bool isAnswerLiked = _prefs?.getBool('liked_a_${answer['id']}_${widget.user.username}') ?? false;
                    String? ansAuthorImg = answer['profile_image'];

                    return Container(
                      key: ValueKey(answer['id']),
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 📍 TOMBOL NAVIGASI PROFIL PENJAWAB
                          GestureDetector(
                            onTap: () async {
                              final db = await DbHelper().database;
                              final userList = await db.query('users', where: 'username = ?', whereArgs: [answer['username']]);
                              if (userList.isNotEmpty && mounted) {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => PublicProfilePage(targetUser: userList.first, currentUser: widget.user)));
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: _primaryPurple,
                                      backgroundImage: (ansAuthorImg != null && ansAuthorImg.isNotEmpty) ? FileImage(File(ansAuthorImg)) : null,
                                      child: (ansAuthorImg == null || ansAuthorImg.isEmpty) ? const Icon(Icons.person, size: 16, color: Colors.white) : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(answer['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  ],
                                ),
                                Text(answer['created_at'].toString().split(' ')[0], style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(answer['content'], style: const TextStyle(fontSize: 14, height: 1.4)),
                          if (answer['image_path'] != null && answer['image_path'].toString().isNotEmpty)
                            Padding(padding: const EdgeInsets.only(top: 12), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(answer['image_path']), height: 150, width: double.infinity, fit: BoxFit.cover))),
                          const SizedBox(height: 12),
                          const Divider(),
                          InkWell(
                            onTap: () => _toggleLikeAnswer(answer),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(isAnswerLiked ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18, color: isAnswerLiked ? Colors.blueAccent : Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text("Membantu (${answer['likes']})", style: TextStyle(color: isAnswerLiked ? Colors.blueAccent : Colors.grey.shade600, fontWeight: isAnswerLiked ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}