import 'package:flutter/material.dart';
import '../core/db_helper.dart';
import '../models/user_model.dart';

class ProfilPage extends StatefulWidget {
  final UserModel user;
  const ProfilPage({super.key, required this.user});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  Map<String, int> stats = {'questions': 0, 'answers': 0, 'ai_chats': 0};

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  // Mengambil data statistik dari database
  Future<void> _loadStats() async {
    final data = await DbHelper().getUserStats(widget.user.username);
    if (mounted) {
      setState(() => stats = data);
    }
  }

  // Logika Nama Level
  String getLevelTitle(int level) {
    switch (level) {
      case 1: return "Rookie";
      case 2: return "Intermediate";
      case 3: return "Scholar";
      case 4: return "Master";
      case 5: return "Legend";
      default: return "Novice";
    }
  }

  // 📍 FUNGSI POP-UP EDIT PROFIL
  void _showEditProfileDialog() {
    TextEditingController nameController = TextEditingController(text: widget.user.username);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Edit Profil"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: "Nama Baru", border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  await DbHelper().updateUsername(widget.user.username, nameController.text.trim());
                  
                  setState(() {
                    widget.user.username = nameController.text.trim();
                  });
                  
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Nama berhasil diubah!")));
                }
              },
              child: const Text("Simpan"),
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double progress = (widget.user.points % 50) / 50.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(top: 60, bottom: 30),
              decoration: const BoxDecoration(
                color: Color(0xFF7B61FF),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      // 📍 Tombol Settings
                      IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: () {
                         // Arahkan ke halaman settings nanti
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Halaman Settings (Next step)")));
                      }),
                    ]),
                  ),
                  const CircleAvatar(radius: 50, backgroundColor: Colors.white, child: Icon(Icons.person, size: 50, color: Color(0xFF7B61FF))),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(widget.user.username, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    // 📍 Tombol Edit Nama (Panggil Pop-up)
                    IconButton(icon: const Icon(Icons.edit, size: 16, color: Colors.white70), onPressed: _showEditProfileDialog),
                  ]),
                  Text(widget.user.email, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 10),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)), child: Text("Level ${widget.user.petLevel} ${getLevelTitle(widget.user.petLevel)}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            
            // Stats Row
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(children: [
                    _buildStatBox("Poin", "${widget.user.points}", Colors.amber),
                    _buildStatBox("Streak", "${widget.user.streakCount}", Colors.orange),
                    _buildStatBox("Level", "${widget.user.petLevel}", Colors.green),
                  ]),
                  const SizedBox(height: 20),
                  // Progress Bar Level
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Progress ke Level ${widget.user.petLevel + 1}"), Text("${widget.user.points % 50}/50")]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress, color: const Color(0xFF7B61FF), backgroundColor: Colors.grey.shade300),
                  ]),
                ],
              ),
            ),

            // Pencapaian & Statistik
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Pencapaian", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    _buildBadge("Rookie", Icons.child_care, widget.user.petLevel >= 1),
                    _buildBadge("Intermediate", Icons.auto_graph, widget.user.petLevel >= 2),
                    _buildBadge("Scholar", Icons.school, widget.user.petLevel >= 3),
                    _buildBadge("Master", Icons.psychology, widget.user.petLevel >= 4),
                    _buildBadge("Legend", Icons.workspace_premium, widget.user.petLevel >= 5),
                  ]),
                  const SizedBox(height: 20),
                  const Text("Statistik Belajar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _buildListTile("Pertanyaan Dijawab", "${stats['questions']}", Icons.question_answer),
                  _buildListTile("Jawaban Diberikan", "${stats['answers']}", Icons.comment),
                  _buildListTile("Chat dengan AI", "${stats['ai_chats']}", Icons.auto_awesome),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context), 
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text("Keluar", style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String title, String val, Color color) => Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withValues(alpha: 0.3))), child: Column(children: [Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey))])));
  Widget _buildBadge(String title, IconData icon, bool unlocked) => Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: unlocked ? Colors.amber.shade50 : Colors.grey.shade100, border: Border.all(color: unlocked ? Colors.amber : Colors.grey.shade300), borderRadius: BorderRadius.circular(10)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: unlocked ? Colors.amber : Colors.grey), const SizedBox(width: 5), Text(title, style: TextStyle(color: unlocked ? Colors.black : Colors.grey))]));
  Widget _buildListTile(String title, String val, IconData icon) => ListTile(leading: Icon(icon, color: const Color(0xFF7B61FF)), title: Text(title), trailing: Text(val, style: const TextStyle(fontWeight: FontWeight.bold)));
}