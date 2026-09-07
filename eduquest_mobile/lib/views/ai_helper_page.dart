import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../core/db_helper.dart';
import '../models/user_model.dart';

class AiHelperPage extends StatefulWidget {
  final UserModel user;

  const AiHelperPage({
    super.key,
    required this.user,
  });

  @override
  State<AiHelperPage> createState() => _AiHelperPageState();
}

class _AiHelperPageState extends State<AiHelperPage> {
  final _dbHelper = DbHelper();

  // ============================================================
  // GROQ API
  // Buat API Key di:
  // https://console.groq.com/keys
  // ============================================================

  final String apiKey = "API Key";

  // Model Groq
  final String modelName = "openai/gpt-oss-120b";

  // Endpoint Groq
  final String groqUrl =
      "https://api.groq.com/openai/v1/chat/completions";

  bool isPersonalHelper = true;

  // ============================================================
  // PERSONAL HELPER
  // ============================================================

  final TextEditingController _chatController =
      TextEditingController();

  List<Map<String, String>> chatHistory = [];

  bool isChatLoading = false;
  bool _showInfoBanner = true;

  // ============================================================
  // FACT CHECKER
  // ============================================================

  final TextEditingController _factController =
      TextEditingController();

  bool isFactLoading = false;

  int? factScore;

  String factExplanation = "";

  // ============================================================
  // COLOR
  // ============================================================

  final Color _primaryPurple =
      const Color(0xFF7B61FF);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadChatHistory();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _factController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD CHAT HISTORY
  // ============================================================

  Future<void> _loadChatHistory() async {
    final history =
        await _dbHelper.getChatHistory(
      widget.user.username,
    );

    if (!mounted) return;

    setState(() {
      chatHistory = history;
    });
  }

  // ============================================================
  // PERSONAL HELPER
  // GROQ API
  // ============================================================

  Future<void> _sendMessage() async {
    final String text =
        _chatController.text.trim();

    if (text.isEmpty || isChatLoading) {
      return;
    }

    // Simpan pesan user
    await _dbHelper.saveMessage(
      widget.user.username,
      "user",
      text,
    );

    if (!mounted) return;

    setState(() {
      chatHistory.add({
        "role": "user",
        "message": text,
      });

      isChatLoading = true;
    });

    _chatController.clear();

    try {
      final url = Uri.parse(groqUrl);

      final String promptContext = '''
Kamu adalah tutor EduQuest.

Tugasmu adalah membantu siswa memahami pertanyaan, bukan hanya memberikan jawaban.

Berikan penjelasan dengan urutan:

1. Jelaskan konsep yang berhubungan dengan pertanyaan.
2. Berikan petunjuk atau langkah penyelesaian secara bertahap.
3. Gunakan bahasa Indonesia yang mudah dipahami siswa.
4. Jika ada perhitungan, tunjukkan proses perhitungannya.
5. Di bagian paling akhir, berikan jawaban final.

Gunakan format:

✅ Jawaban: [jawaban lengkap]

Pertanyaan siswa:
$text
''';

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
                  "Kamu adalah tutor EduQuest yang membantu siswa belajar dengan penjelasan dan petunjuk bertahap."
            },
            {
              "role": "user",
              "content": promptContext,
            }
          ],
          "temperature": 0.7,
          "max_tokens": 1024,
        }),
      );

      if (response.statusCode == 200) {
        final data =
            jsonDecode(response.body);

        final String reply =
            data['choices'][0]['message']['content']
                .toString()
                .trim();

        // Simpan balasan AI
        await _dbHelper.saveMessage(
          widget.user.username,
          "ai",
          reply,
        );

        if (!mounted) return;

        setState(() {
          chatHistory.add({
            "role": "ai",
            "message": reply,
          });
        });
      } else {
        throw Exception(
          "Status: ${response.statusCode}\n"
          "Body: ${response.body}",
        );
      }
    } catch (e) {
      debugPrint(
        "PERSONAL HELPER ERROR: $e",
      );

      if (!mounted) return;

      setState(() {
        chatHistory.add({
          "role": "ai",
          "message":
              "Maaf, terjadi kesalahan saat menghubungi AI.\n\n$e",
        });
      });
    } finally {
      if (mounted) {
        setState(() {
          isChatLoading = false;
        });
      }
    }
  }

  // ============================================================
  // FACT CHECKER
  // GROQ API
  // ============================================================

  Future<void> _checkFact() async {
    final String text =
        _factController.text.trim();

    if (text.isEmpty || isFactLoading) {
      return;
    }

    setState(() {
      isFactLoading = true;

      factScore = null;

      factExplanation = "";
    });

    try {
      final url = Uri.parse(groqUrl);

      final String promptContext = '''
Evaluasi keakuratan informasi berikut:

"$text"

Berikan skor berdasarkan ketentuan berikut:

100:
Informasi sepenuhnya benar dan akurat.

75-99:
Mayoritas informasi benar, tetapi terdapat sedikit detail yang kurang tepat.

40-74:
Informasi merupakan campuran fakta dan opini, ambigu, atau membutuhkan konteks tambahan.

1-39:
Mayoritas informasi salah atau mengandung informasi yang menyesatkan.

0:
Informasi sepenuhnya salah atau merupakan hoax.

Kembalikan hasil menggunakan JSON VALID dengan format:

{
  "score": 100,
  "explanation": "Penjelasan mengenai hasil analisis fakta."
}

Ketentuan:

- score wajib berupa integer dari 0 sampai 100.
- explanation wajib berupa string.
- Gunakan bahasa Indonesia.
- Jangan gunakan Markdown.
- Jangan gunakan ```json.
- Jangan memberikan teks apa pun di luar object JSON.
''';

      final response = await http.post(
        url,
        headers: {
          'Content-Type':
              'application/json',

          'Authorization':
              'Bearer $apiKey',
        },
        body: jsonEncode({
          "model": modelName,

          "messages": [
            {
              "role": "system",
              "content":
                  "Kamu adalah fact checker objektif. "
                  "Analisis keakuratan informasi dan selalu kembalikan JSON valid "
                  "dengan field score dan explanation."
            },
            {
              "role": "user",
              "content":
                  promptContext,
            }
          ],

          // Paksa AI menghasilkan JSON
          "response_format": {
            "type":
                "json_object",
          },

          "temperature": 0.2,

          "max_tokens": 512,
        }),
      );

      if (response.statusCode == 200) {
        final data =
            jsonDecode(
          response.body,
        );

        final String reply =
            data['choices'][0]['message']['content']
                .toString()
                .trim();

        debugPrint(
          "RAW FACT CHECK RESPONSE:",
        );

        debugPrint(reply);

        try {
          final Map<String, dynamic>
              jsonReply =
              jsonDecode(reply)
                  as Map<String, dynamic>;

          if (jsonReply['score'] == null ||
              jsonReply['explanation'] == null) {
            throw const FormatException(
              "Field score atau explanation tidak ditemukan.",
            );
          }

          final num scoreValue =
              jsonReply['score']
                  as num;

          int score =
              scoreValue.round();

          // Pastikan score selalu 0-100
          if (score < 0) {
            score = 0;
          }

          if (score > 100) {
            score = 100;
          }

          final String explanation =
              jsonReply['explanation']
                  .toString();

          if (!mounted) return;

          setState(() {
            factScore = score;

            factExplanation =
                explanation;
          });

          // ====================================================
          // TAMBAH POINT
          // ====================================================

          if (score > 60) {
            await _dbHelper.addPoints(
              widget.user.username,
              5,
            );

            if (!mounted) return;

            ScaffoldMessenger.of(context)
                .showSnackBar(
              const SnackBar(
                content: Text(
                  "Hebat! Fakta akurat. +5 Poin Pet! 🎉",
                ),
                backgroundColor:
                    Colors.green,
              ),
            );
          }
        } catch (formatError) {
          debugPrint(
            "JSON PARSE ERROR: $formatError",
          );

          debugPrint(
            "RAW RESPONSE: $reply",
          );

          if (!mounted) return;

          ScaffoldMessenger.of(context)
              .showSnackBar(
            SnackBar(
              content: Text(
                "Gagal membaca hasil AI.\n\n"
                "Balasan AI:\n$reply",
              ),
              backgroundColor:
                  Colors.orange,
            ),
          );
        }
      } else {
        throw Exception(
          "Status: ${response.statusCode}\n"
          "Body: ${response.body}",
        );
      }
    } catch (e) {
      debugPrint(
        "FACT CHECK ERROR: $e",
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            "Gagal mengecek fakta.\n\n$e",
          ),
          backgroundColor:
              Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isFactLoading = false;
        });
      }
    }
  }

  // ============================================================
  // MAIN UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey.shade50,

      body: Column(
        children: [
          // ====================================================
          // HEADER
          // ====================================================

          Container(
            padding:
                const EdgeInsets.only(
              top: 60,
              left: 20,
              right: 20,
              bottom: 30,
            ),

            decoration: BoxDecoration(
              color:
                  _primaryPurple,

              borderRadius:
                  const BorderRadius.vertical(
                bottom:
                    Radius.circular(
                  30,
                ),
              ),
            ),

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .spaceBetween,

                  children: [
                    const Text(
                      "AI Helper",
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize:
                            26,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    if (isPersonalHelper &&
                        chatHistory
                            .isNotEmpty)
                      IconButton(
                        icon:
                            const Icon(
                          Icons
                              .delete_sweep,
                          color:
                              Colors.white70,
                        ),

                        onPressed:
                            () async {
                          await _dbHelper
                              .clearChatHistory(
                            widget
                                .user
                                .username,
                          );

                          await _loadChatHistory();
                        },
                      ),
                  ],
                ),

                const SizedBox(
                  height: 4,
                ),

                const Text(
                  "Bantuan pintar untuk belajarmu",
                  style:
                      TextStyle(
                    color:
                        Colors.white70,
                    fontSize:
                        14,
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                // =================================================
                // PERSONAL / FACT SWITCH
                // =================================================

                Container(
                  decoration:
                      BoxDecoration(
                    color: Colors.white
                        .withValues(
                      alpha:
                          0.2,
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      30,
                    ),
                  ),

                  child: Row(
                    children: [
                      // ============================================
                      // PERSONAL HELPER
                      // ============================================

                      Expanded(
                        child:
                            GestureDetector(
                          onTap: () {
                            setState(
                              () {
                                isPersonalHelper =
                                    true;
                              },
                            );
                          },

                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical:
                                  12,
                            ),

                            decoration:
                                BoxDecoration(
                              color:
                                  isPersonalHelper
                                      ? Colors.white
                                      : Colors
                                          .transparent,

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                30,
                              ),
                            ),

                            child:
                                Center(
                              child:
                                  Text(
                                "💡 Personal Helper",

                                style:
                                    TextStyle(
                                  color: isPersonalHelper
                                      ? _primaryPurple
                                      : Colors.white,

                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ============================================
                      // FACT CHECKER
                      // ============================================

                      Expanded(
                        child:
                            GestureDetector(
                          onTap: () {
                            setState(
                              () {
                                isPersonalHelper =
                                    false;
                              },
                            );
                          },

                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical:
                                  12,
                            ),

                            decoration:
                                BoxDecoration(
                              color:
                                  !isPersonalHelper
                                      ? Colors.white
                                      : Colors
                                          .transparent,

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                30,
                              ),
                            ),

                            child:
                                Center(
                              child:
                                  Text(
                                "☑️ Fact Checker",

                                style:
                                    TextStyle(
                                  color: !isPersonalHelper
                                      ? _primaryPurple
                                      : Colors.white,

                                  fontWeight:
                                      FontWeight
                                          .bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ====================================================
          // CONTENT
          // ====================================================

          Expanded(
            child:
                isPersonalHelper
                    ? _buildPersonalHelper()
                    : _buildFactChecker(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PERSONAL HELPER UI
  // ============================================================

  Widget _buildPersonalHelper() {
    return Column(
      children: [
        // ======================================================
        // INFO BANNER
        // ======================================================

        if (_showInfoBanner)
          AnimatedSize(
            duration:
                const Duration(
              milliseconds:
                  300,
            ),

            curve:
                Curves.easeInOut,

            child:
                Container(
              margin:
                  const EdgeInsets
                      .all(
                20,
              ),

              padding:
                  const EdgeInsets
                      .all(
                16,
              ),

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFFFF8E1,
                ),

                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),

                border:
                    Border.all(
                  color:
                      Colors.amber
                          .shade200,
                ),
              ),

              child:
                  Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  const Icon(
                    Icons
                        .auto_awesome,
                    color:
                        Colors.amber,
                  ),

                  const SizedBox(
                    width:
                        12,
                  ),

                  const Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [
                        Text(
                          "Bagaimana Cara Kerja Personal Helper?",

                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,

                            color:
                                Colors
                                    .brown,
                          ),
                        ),

                        SizedBox(
                          height:
                              4,
                        ),

                        Text(
                          "AI memberikan petunjuk step-by-step, lalu jawaban final di akhir!",

                          style:
                              TextStyle(
                            fontSize:
                                12,

                            color:
                                Colors
                                    .brown,
                          ),
                        ),
                      ],
                    ),
                  ),

                  GestureDetector(
                    onTap: () {
                      setState(
                        () {
                          _showInfoBanner =
                              false;
                        },
                      );
                    },

                    child:
                        const Icon(
                      Icons.close,

                      size:
                          18,

                      color:
                          Colors.brown,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ======================================================
        // CHAT LIST
        // ======================================================

        Expanded(
          child:
              chatHistory.isEmpty
                  ? Center(
                      child:
                          Text(
                        "Belum ada obrolan. Mulai tanyakan sesuatu!",

                        style:
                            TextStyle(
                          color:
                              Colors.grey
                                  .shade400,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal:
                            20,
                      ),

                      itemCount:
                          chatHistory.length,

                      itemBuilder:
                          (
                        context,
                        index,
                      ) {
                        final bool
                            isUser =
                            chatHistory[index]
                                    ["role"] ==
                                "user";

                        return Align(
                          alignment: isUser
                              ? Alignment
                                  .centerRight
                              : Alignment
                                  .centerLeft,

                          child:
                              Container(
                            margin:
                                const EdgeInsets
                                    .only(
                              bottom:
                                  12,
                            ),

                            padding:
                                const EdgeInsets
                                    .all(
                              14,
                            ),

                            decoration:
                                BoxDecoration(
                              color:
                                  isUser
                                      ? _primaryPurple
                                      : Colors.white,

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ).copyWith(
                                bottomRight: isUser
                                    ? const Radius
                                        .circular(
                                        0,
                                      )
                                    : const Radius
                                        .circular(
                                        16,
                                      ),

                                bottomLeft: !isUser
                                    ? const Radius
                                        .circular(
                                        0,
                                      )
                                    : const Radius
                                        .circular(
                                        16,
                                      ),
                              ),

                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(
                                    alpha:
                                        0.05,
                                  ),

                                  blurRadius:
                                      5,
                                ),
                              ],
                            ),

                            child:
                                Text(
                              chatHistory[index]
                                      ["message"] ??
                                  "",

                              style:
                                  TextStyle(
                                color: isUser
                                    ? Colors.white
                                    : Colors
                                        .black87,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),

        // ======================================================
        // CHAT INPUT
        // ======================================================

        Padding(
          padding:
              const EdgeInsets.all(
            20,
          ),

          child:
              Row(
            children: [
              Expanded(
                child:
                    TextField(
                  controller:
                      _chatController,

                  textInputAction:
                      TextInputAction.send,

                  onSubmitted:
                      (_) {
                    if (!isChatLoading) {
                      _sendMessage();
                    }
                  },

                  decoration:
                      InputDecoration(
                    hintText:
                        "Tulis pertanyaanmu...",

                    filled:
                        true,

                    fillColor:
                        Colors.white,

                    border:
                        OutlineInputBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        30,
                      ),

                      borderSide:
                          BorderSide
                              .none,
                    ),

                    contentPadding:
                        const EdgeInsets
                            .symmetric(
                      horizontal:
                          20,

                      vertical:
                          14,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width:
                    12,
              ),

              CircleAvatar(
                radius:
                    25,

                backgroundColor:
                    _primaryPurple,

                child:
                    isChatLoading
                        ? const SizedBox(
                            width:
                                20,
                            height:
                                20,

                            child:
                                CircularProgressIndicator(
                              color:
                                  Colors.white,

                              strokeWidth:
                                  2,
                            ),
                          )
                        : IconButton(
                            icon:
                                const Icon(
                              Icons.send,

                              color:
                                  Colors.white,
                            ),

                            onPressed:
                                _sendMessage,
                          ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FACT CHECKER UI
  // ============================================================

  Widget _buildFactChecker() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.all(
        20,
      ),

      child:
          Column(
        children: [
          // ====================================================
          // INPUT
          // ====================================================

          TextField(
            controller:
                _factController,

            maxLines:
                4,

            decoration:
                InputDecoration(
              hintText:
                  "Masukkan fakta yang ingin kamu cek kebenarannya...\n"
                  "Contoh: Bumi adalah pusat tata surya.",

              filled:
                  true,

              fillColor:
                  Colors.white,

              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),

                borderSide:
                    BorderSide(
                  color:
                      _primaryPurple
                          .withValues(
                    alpha:
                        0.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            height:
                16,
          ),

          // ====================================================
          // BUTTON
          // ====================================================

          SizedBox(
            width:
                double.infinity,

            height:
                50,

            child:
                ElevatedButton.icon(
              onPressed:
                  isFactLoading
                      ? null
                      : _checkFact,

              icon:
                  isFactLoading
                      ? const SizedBox(
                          width:
                              20,

                          height:
                              20,

                          child:
                              CircularProgressIndicator(
                            color:
                                Colors.white,

                            strokeWidth:
                                2,
                          ),
                        )
                      : const Icon(
                          Icons.search,
                        ),

              label:
                  Text(
                isFactLoading
                    ? "Mengecek..."
                    : "Cek Fakta Sekarang",
              ),

              style:
                  ElevatedButton
                      .styleFrom(
                backgroundColor:
                    _primaryPurple,

                foregroundColor:
                    Colors.white,

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    30,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(
            height:
                40,
          ),

          // ====================================================
          // RESULT
          // ====================================================

          if (factScore != null) ...[
            Stack(
              alignment:
                  Alignment.center,

              children: [
                SizedBox(
                  width:
                      120,

                  height:
                      120,

                  child:
                      CircularProgressIndicator(
                    value:
                        factScore! /
                            100,

                    strokeWidth:
                        12,

                    backgroundColor:
                        Colors.grey
                            .shade200,

                    color: factScore! >
                            70
                        ? Colors.green
                        : factScore! >
                                40
                            ? Colors.orange
                            : Colors.red,

                    strokeCap:
                        StrokeCap
                            .round,
                  ),
                ),

                Text(
                  "$factScore%",

                  style:
                      TextStyle(
                    fontSize:
                        32,

                    fontWeight:
                        FontWeight
                            .bold,

                    color:
                        _primaryPurple,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height:
                  24,
            ),

            Container(
              width:
                  double.infinity,

              padding:
                  const EdgeInsets.all(
                16,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.white,

                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),

              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,

                children: [
                  const Text(
                    "Hasil Analisis AI:",

                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight
                              .bold,

                      fontSize:
                          16,
                    ),
                  ),

                  const SizedBox(
                    height:
                        8,
                  ),

                  Text(
                    factExplanation,

                    style:
                        TextStyle(
                      color:
                          Colors.grey
                              .shade700,

                      height:
                          1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}