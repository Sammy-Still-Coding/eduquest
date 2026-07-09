import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../core/db_helper.dart';

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
  bool _isLoading = true;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _initPrefsAndLoadAnswers();
  }

  Future<void> _initPrefsAndLoadAnswers() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadAnswers();
  }

  // 📍 MENGAMBIL DATA JAWABAN: Diurutkan berdasarkan Like Terbanyak!
  Future<void> _loadAnswers() async {
    final db = await DbHelper().database;
    final int qId = widget.question['id'];
    
    // Instruksi ORDER BY likes DESC memastikan jawaban dengan like terbanyak ada di atas
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT * FROM answers WHERE question_id = ? ORDER BY likes DESC, id ASC',
      [qId]
    );

    if (mounted) {
      setState(() {
        _answers = result;
        _isLoading = false;
      });
    }
  }

  // 📍 FUNGSI LIKE UNTUK JAWABAN (1 Akun 1 Like)
  Future<void> _toggleLikeAnswer(int answerId) async {
    if (_prefs == null) return;
    
    String likeKey = 'liked_a_${answerId}_${widget.user.username}';
    bool isLiked = _prefs!.getBool(likeKey) ?? false;
    
    final db = await DbHelper().database;

    if (isLiked) {
      await db.rawUpdate('UPDATE answers SET likes = likes - 1 WHERE id = ?', [answerId]);
      await _prefs!.setBool(likeKey, false);
    } else {
      await db.rawUpdate('UPDATE answers SET likes = likes + 1 WHERE id = ?', [answerId]);
      await _prefs!.setBool(likeKey, true);
    }
    
    await _loadAnswers(); // Load ulang agar posisi otomatis terurut ulang jika like berubah
  }

  @override
  Widget build(BuildContext context) {
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
                // KARTU PERTANYAAN INTI
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(backgroundColor: _primaryPurple, radius: 20, child: Text(widget.question['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.question['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                              Text(widget.question['created_at'].toString(), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(widget.question['question'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      Text(widget.question['description'], style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87)),
                      
                      if (widget.question['image_path'] != null && widget.question['image_path'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(widget.question['image_path']), width: double.infinity, fit: BoxFit.cover),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // HEADER JAWABAN
                Row(
                  children: [
                    const Icon(Icons.forum, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Text("${_answers.length} Jawaban", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 16),
                
                // LIST JAWABAN (Sudah diurutkan secara otomatis dari DB)
                if (_answers.isEmpty)
                  Center(child: Padding(padding: const EdgeInsets.all(20), child: Text("Belum ada jawaban. Jadilah yang pertama membantu!", style: TextStyle(color: Colors.grey.shade500))))
                else
                  ..._answers.map((answer) {
                    bool isAnswerLiked = _prefs?.getBool('liked_a_${answer['id']}_${widget.user.username}') ?? false;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(backgroundColor: Colors.grey.shade300, radius: 14, child: const Icon(Icons.person, size: 16, color: Colors.white)),
                                  const SizedBox(width: 8),
                                  Text(answer['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ],
                              ),
                              Text(answer['created_at'].toString().split(' ')[0], style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(answer['content'], style: const TextStyle(fontSize: 14, height: 1.4)),
                          
                          if (answer['image_path'] != null && answer['image_path'].toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(answer['image_path']), height: 150, width: double.infinity, fit: BoxFit.cover)),
                            ),

                          const SizedBox(height: 12),
                          const Divider(),
                          
                          // 📍 TOMBOL LIKE JAWABAN
                          InkWell(
                            onTap: () => _toggleLikeAnswer(answer['id']),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(isAnswerLiked ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18, color: isAnswerLiked ? Colors.blueAccent : Colors.grey.shade500),
                                  const SizedBox(width: 6),
                                  Text(
                                    "Membantu (${answer['likes']})", 
                                    style: TextStyle(color: isAnswerLiked ? Colors.blueAccent : Colors.grey.shade600, fontWeight: isAnswerLiked ? FontWeight.bold : FontWeight.normal, fontSize: 13)
                                  ),
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