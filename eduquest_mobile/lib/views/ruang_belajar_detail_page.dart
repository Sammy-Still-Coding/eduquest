import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RuangBelajarDetailPage extends StatefulWidget {
  final Map<String, dynamic> roomData;
  const RuangBelajarDetailPage({super.key, required this.roomData});

  @override
  State<RuangBelajarDetailPage> createState() => _RuangBelajarDetailPageState();
}

class _RuangBelajarDetailPageState extends State<RuangBelajarDetailPage> {
  late int timeLeft;
  Timer? _timer;
  bool isRunning = false;
  bool isMicOn = false;

  final TextEditingController _chatController = TextEditingController();
  List<Map<String, dynamic>> chatMessages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    timeLeft = widget.roomData['duration'] * 60; 
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chatController.dispose();
    super.dispose();
  }

  void _toggleTimer() {
    if (isRunning) {
      _timer?.cancel();
      setState(() => isRunning = false);
    } else {
      setState(() => isRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (timeLeft > 0) {
          setState(() => timeLeft--);
        } else {
          _timer?.cancel();
          setState(() => isRunning = false);
        }
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      isRunning = false;
      timeLeft = widget.roomData['duration'] * 60;
    });
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() => chatMessages.add({"type": "image", "path": pickedFile.path, "sender": "Kamu", "time": "Baru saja"}));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengambil gambar")));
    }
  }

  void _sendText() {
    if (_chatController.text.trim().isEmpty) return;
    setState(() {
      chatMessages.add({"type": "text", "content": _chatController.text.trim(), "sender": "Kamu", "time": "Baru saja"});
      _chatController.clear();
    });
  }

  // Dialog Konfirmasi Bubarkan Ruangan
  void _showDisbandDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Bubarkan Ruangan?"),
        content: const Text("Apakah kamu yakin ingin menutup ruangan ini? Semua orang akan dikeluarkan."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context); // Tutup dialog
              Navigator.pop(context, true); // Kembali ke halaman list dengan sinyal 'true' untuk dihapus
            },
            child: const Text("Ya, Bubarkan"),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mengambil data peserta dari ruangData (dikirim dari halaman sebelumnya)
    List participants = widget.roomData['participant_list'] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF26D0CE), Color(0xFF1A2980)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                        child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.45,
                            child: Text(widget.roomData['title'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Text("${widget.roomData['participants']}/${widget.roomData['max_participants']} peserta", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  
                  // TOMBOL BUBARKAN (Hanya muncul jika user adalah creator)
                  if (widget.roomData['isCreator'] == true)
                    Container(
                      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(12)),
                      child: IconButton(
                        icon: const Icon(Icons.power_settings_new, color: Colors.white),
                        tooltip: "Bubarkan Ruangan",
                        onPressed: _showDisbandDialog,
                      ),
                    )
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // --- KARTU POMODORO TIMER ---
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                    child: Column(
                      children: [
                        const Text("Pomodoro Timer", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Text(_formatTime(timeLeft), style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFF7B61FF))),
                        Text("Topik: ${widget.roomData['topic']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _toggleTimer,
                                icon: Icon(isRunning ? Icons.pause : Icons.play_arrow),
                                label: Text(isRunning ? "Pause" : "Mulai"),
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B4DB), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: _resetTimer,
                              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                              child: const Text("Reset", style: TextStyle(color: Colors.grey)),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- KARTU KENDALI SUARA & DAFTAR PESERTA ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Voice Chat (Open Mic)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  SizedBox(height: 4),
                                  Text("Nyalakan mic untuk berdiskusi langsung.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => isMicOn = !isMicOn),
                              child: CircleAvatar(
                                radius: 28,
                                backgroundColor: isMicOn ? Colors.red : const Color(0xFF7B61FF).withValues(alpha: 0.1),
                                child: Icon(isMicOn ? Icons.mic_off : Icons.mic, color: isMicOn ? Colors.white : const Color(0xFF7B61FF), size: 28),
                              ),
                            )
                          ],
                        ),
                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                        
                        // DAFTAR PESERTA (AVATAR DUMMY)
                        SizedBox(
                          height: 70, // Tinggi area foto profil
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: participants.length,
                            itemBuilder: (context, index) {
                              final p = participants[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 16.0),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: p['color'], // Warna acak dari data
                                      child: Text(
                                        p['name'][0], // Mengambil huruf pertama dari nama
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(p['name'], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- KARTU GROUP CHAT (FOTO/VIDEO) ---
                  Container(
                    height: 350, 
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
                    child: Column(
                      children: [
                        const Padding(padding: EdgeInsets.all(16.0), child: Text("Media & Diskusi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                        const Divider(height: 1),
                        Expanded(
                          child: chatMessages.isEmpty
                              ? Center(child: Text("Bagikan soal berupa foto di sini!", style: TextStyle(color: Colors.grey.shade400)))
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: chatMessages.length,
                                  itemBuilder: (context, index) {
                                    final msg = chatMessages[index];
                                    return Align(
                                      alignment: Alignment.centerRight,
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: const Color(0xFF7B61FF).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(0))),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            if (msg['type'] == 'image')
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.file(File(msg['path']), width: 200, height: 200, fit: BoxFit.cover),
                                              )
                                            else
                                              Text(msg['content'], style: const TextStyle(color: Colors.black87)),
                                            const SizedBox(height: 4),
                                            Text(msg['time'], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade200))),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.attach_file, color: Colors.grey),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (context) => SafeArea(
                                      child: Wrap(
                                        children: [
                                          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Ambil dari Galeri'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
                                          ListTile(leading: const Icon(Icons.camera_alt), title: const Text('Buka Kamera'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _chatController,
                                  decoration: InputDecoration(hintText: "Ketik pesan...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none), filled: true, fillColor: Colors.grey.shade100, contentPadding: const EdgeInsets.symmetric(horizontal: 16)),
                                ),
                              ),
                              IconButton(icon: const Icon(Icons.send, color: Color(0xFF7B61FF)), onPressed: _sendText)
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}