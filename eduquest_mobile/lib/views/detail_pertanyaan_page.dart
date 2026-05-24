import 'dart:io';
import 'package:flutter/material.dart';
import '../core/db_helper.dart';
import '../models/user_model.dart';

class DetailPertanyaanPage extends StatefulWidget {
  final Map<String, dynamic> question;
  final UserModel user;
  const DetailPertanyaanPage({super.key, required this.question, required this.user});

  @override
  State<DetailPertanyaanPage> createState() => _DetailPertanyaanPageState();
}

class _DetailPertanyaanPageState extends State<DetailPertanyaanPage> {
  final Color _primaryPurple = const Color(0xFF7B61FF);

  // Fungsi pura-pura untuk LIKE komentar (agar interaktif)
  void _likeAnswer(int index) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Menyukai jawaban ini! ❤️")));
  }

  @override
  Widget build(BuildContext context) {
    List<String> tags = (widget.question['tags'] as String).split(',');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
        title: const Text("Detail Diskusi", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 1. HEADER PERTANYAAN
                Row(
                  children: [
                    CircleAvatar(backgroundColor: _primaryPurple, radius: 20, child: Text(widget.question['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.question['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(widget.question['created_at'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _primaryPurple.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Text(widget.question['category'], style: TextStyle(color: _primaryPurple, fontSize: 11, fontWeight: FontWeight.bold)))
                  ],
                ),
                const SizedBox(height: 20),
                Text(widget.question['question'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const SizedBox(height: 12),
                Text(widget.question['description'], style: const TextStyle(fontSize: 15, height: 1.5)),
                const SizedBox(height: 16),
                
                // Gambar Soal Jika Ada
                if (widget.question['image_path'] != null && widget.question['image_path'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(widget.question['image_path']))),
                  ),

                Wrap(spacing: 8, children: tags.map((tag) => Text(tag, style: TextStyle(color: Colors.blue.shade700, fontSize: 13, fontWeight: FontWeight.w500))).toList()),
                
                const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Divider(thickness: 1)),
                
                // 2. BAGIAN KOMENTAR / JAWABAN
                Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 20),
                    const SizedBox(width: 8),
                    Text("${widget.question['comments']} Jawaban", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 20),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: DbHelper().getAnswers(widget.question['id']),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(child: Padding(padding: const EdgeInsets.all(40.0), child: Text("Belum ada yang menjawab.", style: TextStyle(color: Colors.grey.shade400))));
                    }

                    return Column(
                      children: snapshot.data!.map((ans) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(backgroundColor: Colors.blueGrey, radius: 16, child: Text(ans['username'][0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12))),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16).copyWith(topLeft: const Radius.circular(0))),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(ans['username'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              Text(ans['created_at'].toString().split(' ')[0], style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (ans['content'].isNotEmpty) Text(ans['content'], style: const TextStyle(fontSize: 14, height: 1.4)),
                                          if (ans['image_path'].isNotEmpty) 
                                            Padding(padding: const EdgeInsets.only(top: 12), child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(ans['image_path']), height: 150, width: double.infinity, fit: BoxFit.cover))),
                                        ],
                                      ),
                                    ),
                                    // Tombol Like Komentar (Tiktok Style)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, left: 8),
                                      child: GestureDetector(
                                        onTap: () => _likeAnswer(ans['id']),
                                        child: Row(
                                          children: [
                                            Icon(Icons.favorite_border, size: 16, color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text("Suka (${ans['likes']})", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500)),
                                            const SizedBox(width: 16),
                                            Text("Balas", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500))
                                          ],
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}