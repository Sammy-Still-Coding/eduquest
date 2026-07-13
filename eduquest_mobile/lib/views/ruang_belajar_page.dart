import 'package:flutter/material.dart';
import 'ruang_belajar_detail_page.dart';
import '../models/user_model.dart';
import '../core/db_helper.dart';
import 'dashboard_page.dart';

class RuangBelajarPage extends StatefulWidget {
  final UserModel user;
  const RuangBelajarPage({super.key, required this.user});

  @override
  State<RuangBelajarPage> createState() => _RuangBelajarPageState();
}

class _RuangBelajarPageState extends State<RuangBelajarPage> {
  List<Map<String, dynamic>> rooms = [];

  final _titleController = TextEditingController();
  final _topicController = TextEditingController();
  final _classController = TextEditingController();
  final _durationController = TextEditingController();
  final _maxPeopleController = TextEditingController();
  String _selectedCategory = "Matematika";

  void _showCreateRoomBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Buat Ruang Belajar Baru",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                      labelText: "Judul Ruangan",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(
                  controller: _topicController,
                  decoration: InputDecoration(
                      labelText: "Topik Pembahasan",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: InputDecoration(
                          labelText: "Kategori",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12))),
                      items: [
                        "Matematika",
                        "Fisika",
                        "Kimia",
                        "Biologi",
                        "Lainnya"
                      ]
                          .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategory = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: _classController,
                          decoration: InputDecoration(
                              labelText: "Untuk Kelas",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _durationController,
                          decoration: InputDecoration(
                              labelText: "Durasi (Menit)",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              suffixText: "min"),
                          keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: _maxPeopleController,
                          decoration: InputDecoration(
                              labelText: "Maks Orang",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              suffixIcon: const Icon(Icons.people)),
                          keyboardType: TextInputType.number)),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B61FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16))),
                  onPressed: () async { // Benerin bagian async di sini
                    setState(() {
                      rooms.insert(0, {
                        "id": DateTime.now()
                            .millisecondsSinceEpoch
                            .toString(), 
                        "title": _titleController.text.isEmpty
                            ? "Ruang Belajar Baru"
                            : _titleController.text,
                        "category": _selectedCategory,
                        "topic": _topicController.text.isEmpty
                            ? "Belajar Bebas"
                            : _topicController.text,
                        "participants": 1,
                        "max_participants":
                            int.tryParse(_maxPeopleController.text) ?? 10,
                        "duration":
                            int.tryParse(_durationController.text) ?? 25,
                        "isCreator": true, 
                        "participant_list": [
                          {"name": "Kamu", "color": Colors.indigo},
                          {"name": "Budi", "color": Colors.green},
                          {"name": "Siti", "color": Colors.orange},
                        ]
                      });
                    });

                    _titleController.clear();
                    _topicController.clear();
                    _classController.clear();
                    _durationController.clear();
                    _maxPeopleController.clear();
                    Navigator.pop(context);

                    // Benerin pemanggilan database point
                    await DbHelper().addPoints(widget.user.username, 5);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Ruangan berhasil dibuat! +5 Poin Pet 🚀"),
                            backgroundColor: Colors.green),
                      );
                    }
                  },
                  child: const Text("Buat & Mulai Belajar",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 40),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFF26D0CE), Color(0xFF1A2980)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2), 
                  shape: BoxShape.circle
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    // 📍 PERBAIKAN: Gunakan pushAndRemoveUntil untuk kembali ke Dashboard
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        // Pastikan variabel user sesuai dengan yang ada di halaman ini (misal: widget.user)
                        builder: (context) => DashboardPage(user: widget.user), 
                      ),
                      (route) => false, // Menghapus tumpukan rute sebelumnya agar tidak blank
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ruang Belajar",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold
                    )
                  ),
                  Text(
                    "Belajar bareng teman-teman",
                    style: TextStyle(color: Colors.white70, fontSize: 14)
                  ),
                ],
              )
            ],
          )
        ],
      ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _showCreateRoomBottomSheet,
              icon: const Icon(Icons.add),
              label: const Text("Buat Ruang Belajar Baru",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B61FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text("Ruang Tersedia",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
        const SizedBox(height: 16),
        Expanded(
          child: rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.meeting_room,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                          "Belum ada ruang belajar aktif.\nYuk buat ruangan baru!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03), 
                                blurRadius: 10,
                                offset: const Offset(0, 4))
                          ]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Text(room['title'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16))),
                              const Row(children: [
                                Icon(Icons.circle,
                                    color: Colors.green, size: 10),
                                SizedBox(width: 4),
                                Text("Active",
                                    style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12))
                              ])
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: const Color(0xFF7B61FF).withValues(alpha: 0.1), 
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(room['category'],
                                style: const TextStyle(
                                    color: Color(0xFF7B61FF),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.menu_book,
                                  size: 16, color: Colors.grey),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(
                                      "Sedang belajar: ${room['topic']}",
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider()),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.people_outline,
                                      size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                      "${room['participants']}/${room['max_participants']}",
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13)),
                                  const SizedBox(width: 16),
                                  Icon(Icons.access_time,
                                      size: 16, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text("${room['duration']} min",
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 13)),
                                ],
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final shouldDelete = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            RuangBelajarDetailPage(
                                                roomData: room)),
                                  );

                                  if (shouldDelete == true) {
                                    setState(() {
                                      rooms.removeWhere(
                                          (r) => r['id'] == room['id']);
                                    });
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00B4DB),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20))),
                                child: const Text("Gabung",
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                              )
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}