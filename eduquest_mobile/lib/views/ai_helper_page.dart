import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/db_helper.dart';
import '../models/user_model.dart';

class AiHelperPage extends StatefulWidget {
  final UserModel user;
  const AiHelperPage({super.key, required this.user});

  @override
  State<AiHelperPage> createState() => _AiHelperPageState();
}

class _AiHelperPageState extends State<AiHelperPage> {
  final _dbHelper = DbHelper();

  // ============================================================
  // GANTI DENGAN API KEY GROQ KAMU
  // Daftar gratis di: https://console.groq.com
  // ============================================================
  final String apiKey = "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";

  // Model Groq gratis yang tersedia (2026):
  // - "llama-3.1-8b-instant"      → ringan & sangat cepat
  // - "llama-3.3-70b-versatile"   → lebih pintar, REKOMENDASI
  // - "qwen/qwen3-32b"            → alternatif bagus
  final String modelName = "llama-3.3-70b-versatile";

  bool isPersonalHelper = true;

  final TextEditingController _chatController = TextEditingController();
  List<Map<String, String>> chatHistory = [];
  bool isChatLoading = false;
  bool _showInfoBanner = true;

  final TextEditingController _factController = TextEditingController();
  bool isFactLoading = false;
  int? factScore;
  String factExplanation = "";

  final Color _primaryPurple = const Color(0xFF7B61FF);

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
  }

  void _loadChatHistory() async {
    var history = await _dbHelper.getChatHistory();
    setState(() {
      chatHistory = history;
    });
  }

  // --- FUNGSI KIRIM CHAT (GROQ API) ---
  Future<void> _sendMessage() async {
    String text = _chatController.text.trim();
    if (text.isEmpty) return;

    await _dbHelper.saveMessage("user", text);

    setState(() {
      chatHistory.add({"role": "user", "message": text});
      isChatLoading = true;
    });
    _chatController.clear();

    try {
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      String promptContext =
          "Kamu adalah tutor EduQuest. Berikan petunjuk step-by-step dulu "
          "agar siswa memahami konsepnya, lalu di bagian akhir berikan "
          "jawaban finalnya dengan format: '✅ Jawaban: [jawaban lengkap]'. "
          "Pertanyaan: $text";

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": modelName,
          "messages": [
            {
              "role": "system",
              "content":
                  "Kamu adalah tutor EduQuest yang membantu siswa belajar dengan petunjuk bertahap."
            },
            {"role": "user", "content": promptContext}
          ],
          "temperature": 0.7,
          "max_tokens": 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data['choices'][0]['message']['content'];

        await _dbHelper.saveMessage("ai", reply);

        setState(() {
          chatHistory.add({"role": "ai", "message": reply});
        });
      } else {
        throw Exception("Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      setState(() {
        chatHistory.add({"role": "ai", "message": "Error: $e"});
      });
    } finally {
      setState(() {
        isChatLoading = false;
      });
    }
  }

  // --- FUNGSI FACT CHECKER (GROQ API) ---
  Future<void> _checkFact() async {
    String text = _factController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      isFactLoading = true;
      factScore = null;
      factExplanation = "";
    });

    try {
      final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

      String promptContext =
          "Evaluasi fakta ini: '$text'. "
          "Balas HANYA dengan format JSON persis seperti ini tanpa tambahan apapun: "
          "{\"score\": angka_0_sampai_100, \"explanation\": \"penjelasan singkat kenapa salah atau benar\"}";

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": modelName,
          "messages": [
            {
              "role": "system",
              "content":
                  "Kamu adalah fact checker. Selalu balas HANYA dengan JSON murni, tanpa markdown, tanpa penjelasan tambahan."
            },
            {"role": "user", "content": promptContext}
          ],
          "temperature": 0.3,
          "max_tokens": 256,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data['choices'][0]['message']['content'];

        reply = reply
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();

        final jsonReply = jsonDecode(reply);

        // ✅ FIX: 1. UPDATE UI dulu (sinkron, tidak boleh ada await di sini)
        setState(() {
          factScore = jsonReply['score'];
          factExplanation = jsonReply['explanation'];
        });

        // ✅ FIX: 2. Baru jalankan await DI LUAR setState
        if (factScore! > 60) {
          await _dbHelper.addPoints(widget.user.username, 5);

          // Pastikan halaman belum ditutup user sebelum tampilkan SnackBar
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Hebat! Fakta akurat. +5 Poin Pet! 🎉"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception("Status: ${response.statusCode}, Body: ${response.body}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mengecek fakta. Coba lagi.")),
        );
      }
    } finally {
      setState(() {
        isFactLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 30),
          decoration: BoxDecoration(
            color: _primaryPurple,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "AI Helper",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold),
                  ),
                  if (isPersonalHelper && chatHistory.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, color: Colors.white70),
                      onPressed: () async {
                        await _dbHelper.clearChatHistory();
                        _loadChatHistory();
                      },
                    )
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                "Bantuan pintar untuk belajarmu",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isPersonalHelper = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isPersonalHelper
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: Text(
                              "💡 Personal Helper",
                              style: TextStyle(
                                color: isPersonalHelper
                                    ? _primaryPurple
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => isPersonalHelper = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !isPersonalHelper
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Center(
                            child: Text(
                              "☑️ Fact Checker",
                              style: TextStyle(
                                color: !isPersonalHelper
                                    ? _primaryPurple
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
        Expanded(
          child: isPersonalHelper ? _buildPersonalHelper() : _buildFactChecker(),
        ),
      ],
    );
  }

  Widget _buildPersonalHelper() {
    return Column(
      children: [
        if (_showInfoBanner)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          "Bagaimana Cara Kerja Personal Helper?",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.brown),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "AI memberikan petunjuk step-by-step, lalu jawaban final di akhir!",
                          style: TextStyle(fontSize: 12, color: Colors.brown),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _showInfoBanner = false),
                    child: const Icon(Icons.close, size: 18, color: Colors.brown),
                  ),
                ],
              ),
            ),
          ),
        Expanded(
          child: chatHistory.isEmpty
              ? Center(
                  child: Text(
                    "Belum ada obrolan. Mulai tanyakan sesuatu!",
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: chatHistory.length,
                  itemBuilder: (context, index) {
                    bool isUser = chatHistory[index]["role"] == "user";
                    return Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isUser ? _primaryPurple : Colors.white,
                          borderRadius: BorderRadius.circular(16).copyWith(
                            bottomRight: isUser
                                ? const Radius.circular(0)
                                : const Radius.circular(16),
                            bottomLeft: !isUser
                                ? const Radius.circular(0)
                                : const Radius.circular(16),
                          ),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5)
                          ],
                        ),
                        child: Text(
                          chatHistory[index]["message"]!,
                          style: TextStyle(
                              color: isUser ? Colors.white : Colors.black87),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: "Tulis pertanyaanmu...",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 25,
                backgroundColor: _primaryPurple,
                child: isChatLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: _sendMessage,
                      ),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget _buildFactChecker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            controller: _factController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText:
                  "Masukkan fakta yang ingin kamu cek kebenarannya...\nContoh: Bumi adalah pusat tata surya.",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: _primaryPurple.withOpacity(0.5)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isFactLoading ? null : _checkFact,
              icon: isFactLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.search),
              label: Text(isFactLoading ? "Mengecek..." : "Cek Fakta Sekarang"),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ),
          const SizedBox(height: 40),
          if (factScore != null) ...[
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: factScore! / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade200,
                    color: factScore! > 70
                        ? Colors.green
                        : (factScore! > 40 ? Colors.orange : Colors.red),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Text(
                  "$factScore%",
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _primaryPurple),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Hasil Analisis AI:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(factExplanation,
                      style: TextStyle(
                          color: Colors.grey.shade700, height: 1.5)),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }
}