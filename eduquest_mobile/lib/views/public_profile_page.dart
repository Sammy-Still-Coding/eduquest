import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/db_helper.dart';
import '../models/user_model.dart';
import 'detail_pertanyaan_page.dart'; // 📍 Import Halaman Detail

class PublicProfilePage extends StatefulWidget {
  final Map<String, dynamic> targetUser; 
  final UserModel currentUser; 

  const PublicProfilePage({super.key, required this.targetUser, required this.currentUser});

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  final DbHelper _dbHelper = DbHelper();
  bool _isLoading = true;
  
  late String _targetUsername;
  String _targetEmail = "";
  File? _imageFile;
  
  int _points = 0;
  int _level = 1;
  int _streak = 0;
  
  int _myQuestionsAnswered = 0; 
  int _myAnswersGiven = 0; 
  
  int _aiUsagePercentage = 0;
  int _forumUsagePercentage = 0;
  int _factCheckAccuracy = 0; 

  int _totalQuestionLikes = 0; 
  int _totalAnswerLikes = 0;   
  double _totalHoursUsage = 0.0; 

  Color _headerColor = const Color(0xFF6B48FF);
  File? _headerImageFile;

  @override
  void initState() {
    super.initState();
    _targetUsername = widget.targetUser['username'];
    _loadTargetUserData();
  }

  Future<void> _loadTargetUserData() async {
    try {
      final db = await _dbHelper.database;
      
      var userRes = await db.query('users', where: 'username = ?', whereArgs: [_targetUsername]);
      if (userRes.isNotEmpty) {
        _targetEmail = userRes.first['email'] as String? ?? "";
        _points = userRes.first['points'] as int;
        _level = userRes.first['pet_level'] as int;
        _streak = userRes.first['streak_count'] as int;
        
        String savedImage = userRes.first['profile_image'] as String;
        if (savedImage.isNotEmpty) {
          _imageFile = File(savedImage);
        }

        _factCheckAccuracy = _points == 0 ? 0 : (65 + (_level * 6)).clamp(0, 98);
      }

      var qCountRes = await db.rawQuery('SELECT COUNT(*) as total, SUM(likes) as totalLikes FROM questions WHERE username = ?', [_targetUsername]);
      int myQuestionsCount = (qCountRes.first['total'] as int?) ?? 0;
      _totalQuestionLikes = (qCountRes.first['totalLikes'] as int?) ?? 0;

      var qRes = await db.rawQuery('SELECT SUM(comments) as total FROM questions WHERE username = ?', [_targetUsername]);
      _myQuestionsAnswered = (qRes.first['total'] as int?) ?? 0;

      var aRes = await db.rawQuery('SELECT COUNT(*) as total, SUM(likes) as totalLikes FROM answers WHERE username = ?', [_targetUsername]);
      _myAnswersGiven = (aRes.first['total'] as int?) ?? 0;
      _totalAnswerLikes = (aRes.first['totalLikes'] as int?) ?? 0;

      var aiRes = await db.rawQuery('SELECT COUNT(*) as total FROM chats WHERE username = ?', [_targetUsername]);
      int totalAiChats = (aiRes.first['total'] as int?) ?? 0;

      int totalAktivitas = myQuestionsCount + _myAnswersGiven + totalAiChats;
      if (totalAktivitas > 0) {
        _aiUsagePercentage = ((totalAiChats / totalAktivitas) * 100).round();
        _forumUsagePercentage = (((myQuestionsCount + _myAnswersGiven) / totalAktivitas) * 100).round();
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      int savedColor = prefs.getInt('header_color_$_targetUsername') ?? 0xFF6B48FF;
      _headerColor = Color(savedColor);
      
      String? savedHeaderImage = prefs.getString('header_image_$_targetUsername');
      if (savedHeaderImage != null && savedHeaderImage.isNotEmpty) {
        _headerImageFile = File(savedHeaderImage);
      }

      _totalHoursUsage = prefs.getDouble('app_usage_hours_$_targetUsername') ?? ((_streak * 1.5) + (totalAktivitas * 0.2));

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF6B48FF))));

    double progressValue = (_level >= 5) ? 1.0 : (_points % 50) / 50.0;
    int nextTarget = (_level >= 5) ? _points : (_level * 50);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER (Struktur asli) ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 50, bottom: 30, left: 24, right: 24),
              decoration: BoxDecoration(
                color: _headerImageFile == null ? _headerColor : null,
                image: _headerImageFile != null 
                    ? DecorationImage(image: FileImage(_headerImageFile!), fit: BoxFit.cover, colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken)) 
                    : null,
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(32), bottomRight: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  ),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 47,
                      backgroundColor: const Color(0xFFE0E0E0),
                      backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                      child: _imageFile == null ? const Icon(Icons.person, size: 55, color: Colors.grey) : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(_targetUsername, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black26, blurRadius: 4)])),
                  const SizedBox(height: 4),
                  Text(_targetEmail, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text("Level $_level Pet Owner", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ],
              ),
            ),

            // --- KONTEN UTAMA PROFILE (Struktur asli) ---
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
                      Text(_level >= 5 ? "Level Maksimal Tercapai!" : "Progress ke Level ${_level + 1}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text("$_points/$nextTarget", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progressValue, minHeight: 8, backgroundColor: const Color(0xFFE0E0E0), valueColor: AlwaysStoppedAnimation<Color>(_headerColor), 
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

                  const Text("Statistik Belajar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C))),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                    child: Column(
                      children: [
                        _buildRowStatDetail(Icons.thumb_up_alt_outlined, "Like Diterima (Pertanyaan)", "$_totalQuestionLikes"),
                        const Divider(height: 24, thickness: 0.5),
                        _buildRowStatDetail(Icons.thumb_up_alt, "Like Diterima (Jawaban)", "$_totalAnswerLikes"),
                        const Divider(height: 24, thickness: 0.5),
                        _buildRowStatDetail(Icons.access_time_rounded, "Total Jam Penggunaan", "${_totalHoursUsage.toStringAsFixed(1)} Jam"),
                        const Divider(height: 24, thickness: 0.5),
                        _buildRowStatDetail(Icons.question_answer_rounded, "Pertanyaan Dijawab", "$_myQuestionsAnswered"),
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

                  // 📍 BAGIAN BARU: RIWAYAT JAWABAN (PORTFOLIO)
                  Text("Jawaban oleh $_targetUsername", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2C))),
                  const SizedBox(height: 12),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: DbHelper().getUserAnswers(_targetUsername),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container(
                          width: double.infinity, padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                          child: Column(
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 12),
                              Text("Belum ada jawaban yang diberikan.", style: TextStyle(color: Colors.grey.shade500)),
                            ],
                          ),
                        );
                      }

                      return Column(
                        children: snapshot.data!.map((data) => _buildAnswerHistoryCard(data)).toList(),
                      );
                    },
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

  // 📍 WIDGET BARU: KARTU RIWAYAT JAWABAN
  Widget _buildAnswerHistoryCard(Map<String, dynamic> data) {
    Map<String, dynamic> questionData = {
      'id': data['id'], 'username': data['username'], 'category': data['category'],
      'question': data['question'], 'description': data['description'], 'tags': data['tags'],
      'image_path': data['image_path'], 'created_at': data['created_at'],
      'likes': data['likes'], 'comments': data['comments'],
    };

    return GestureDetector(
      onTap: () {
        // Navigasi ke detail pertanyaan
        Navigator.push(context, MaterialPageRoute(builder: (context) => DetailPertanyaanPage(question: questionData, user: widget.currentUser)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Pertanyaan Asli
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.help_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text("Pertanyaan dari ${data['username']}:\n\"${data['question']}\"", style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            
            // Konten Jawaban
            Row(children: [Icon(Icons.chat_bubble_outline, size: 16, color: _headerColor), const SizedBox(width: 8), const Text("Jawaban Saya:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]),
            const SizedBox(height: 6),
            Text(data['answer_content'], maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: Colors.black87)),
            
            const SizedBox(height: 12),
            
            // Footer: Tanggal & Like
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(data['answer_date'].toString().split(' ')[0], style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                Row(
                  children: [
                    const Icon(Icons.thumb_up_alt, size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 4),
                    Text("${data['answer_likes']} Like", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRowStatDetail(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: _headerColor, size: 20),
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
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
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