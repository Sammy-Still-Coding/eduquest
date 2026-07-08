import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 📍 Tambahan import
import '../core/db_helper.dart';
import '../models/user_model.dart';

final DateTime sessionStart = DateTime.now();

class PetKuPage extends StatefulWidget {
  final UserModel user;
  const PetKuPage({super.key, required this.user});

  @override
  State<PetKuPage> createState() => _PetKuPageState();
}

class _PetKuPageState extends State<PetKuPage> {
  final _dbHelper = DbHelper();
  
  int currentPoints = 0;
  int currentLevel = 1;
  int sessionMinutes = 0;
  Timer? _screenTimer;

  // State Kustomisasi Pet
  String petName = "Eggie";
  String selectedPetEmoji = "🐣";
  String selectedItemEmoji = ""; 
  final TextEditingController _nameController = TextEditingController();

  // Master Data Karakter Pet
  final List<Map<String, dynamic>> petOptions = [
    {"emoji": "🐣", "name": "Chikoo (Anak Ayam)", "level_req": 1},
    {"emoji": "🐱", "name": "Meowth (Kucing Pintar)", "level_req": 2},
    {"emoji": "🦊", "name": "Foxy (Rubah Cerdik)", "level_req": 3},
    {"emoji": "🦁", "name": "Leo (Singa Bijak)", "level_req": 4},
    {"emoji": "🐉", "name": "Draco (Naga Master)", "level_req": 5},
  ];

  // Master Data Aksesoris
  final List<Map<String, dynamic>> itemOptions = [
    {"emoji": "", "name": "Tanpa Item", "level_req": 1},
    {"emoji": "✏️", "name": "Pensil Belajar", "level_req": 2},
    {"emoji": "📚", "name": "Tumpukan Buku", "level_req": 3},
    {"emoji": "👓", "name": "Kacamata Genius", "level_req": 4},
    {"emoji": "🎓", "name": "Toga Wisuda", "level_req": 5},
  ];

  @override
  void initState() {
    super.initState();
    _loadPetData(); // 📍 Fungsi ini akan dipanggil otomatis saat halaman dibuka
    
    _screenTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          sessionMinutes = DateTime.now().difference(sessionStart).inMinutes;
        });
      }
    });
  }

  @override
  void dispose() {
    _screenTimer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  // 📍 LOGIKA MEMUAT DATA YANG TERSIMPAN (NAMA, EMOJI, AKSESORIS)
  Future<void> _loadPetData() async {
    final db = await _dbHelper.database;
    final data = await db.query('users', where: 'username = ?', whereArgs: [widget.user.username]);
    
    // 📍 Ambil data kosmetik (Emoji & Item) dari memori HP, khusus untuk user ini
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String savedEmoji = prefs.getString('pet_emoji_${widget.user.username}') ?? "🐣";
    String savedItem = prefs.getString('pet_item_${widget.user.username}') ?? "";

    if (data.isNotEmpty) {
      int dbPoints = data.first['points'] as int;
      int dbLevel = data.first['pet_level'] as int;
      String dbPetName = data.first['pet_name']?.toString() ?? "Eggie"; // 📍 Ambil nama dari SQLite

      // Logika Level Up
      int expectedLevel = (dbPoints ~/ 50) + 1;
      if (expectedLevel > 5) expectedLevel = 5; 

      if (expectedLevel > dbLevel) {
        await db.rawUpdate(
          'UPDATE users SET pet_level = ? WHERE username = ?',
          [expectedLevel, widget.user.username]
        );
        dbLevel = expectedLevel; 
      }

      setState(() {
        currentPoints = dbPoints;
        currentLevel = dbLevel;
        
        // 📍 Terapkan data yang tersimpan ke tampilan!
        petName = dbPetName;
        selectedPetEmoji = savedEmoji;
        selectedItemEmoji = savedItem;
      });
    }
  }

  double get levelProgress {
    if (currentLevel >= 5) return 1.0;
    double progress = (currentPoints % 50) / 50.0;
    return progress.clamp(0.0, 1.0); 
  }

  String get nextLevelTarget {
    if (currentLevel >= 5) return "MAX LEVEL";
    int nextTarget = currentLevel * 50; 
    return "$currentPoints / $nextTarget Pts";
  }

  // --- POP-UP DIALOG EDIT PET + AKSESORIS ---
  void _showEditPetDialog() {
    _nameController.text = petName;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text("Kustomisasi Pet", style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: "Nama Pet",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.edit),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text("Pilih Karakter:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFB53471))),
                    const SizedBox(height: 8),
                    
                    ...petOptions.map((pet) {
                      bool isUnlocked = currentLevel >= pet['level_req'];
                      bool isSelected = selectedPetEmoji == pet['emoji'];
                      return ListTile(
                        leading: Text(pet['emoji'], style: const TextStyle(fontSize: 24)),
                        title: Text(pet['name'], style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Color(0xFFB53471)) : (!isUnlocked ? const Icon(Icons.lock, size: 18) : null),
                        enabled: isUnlocked,
                        onTap: () => setDialogState(() => selectedPetEmoji = pet['emoji']),
                      );
                    }),

                    const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider()),
                    const Text("Benda yang Dipegang:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueAccent)),
                    const SizedBox(height: 8),

                    ...itemOptions.map((item) {
                      bool isUnlocked = currentLevel >= item['level_req'];
                      bool isSelected = selectedItemEmoji == item['emoji'];
                      return ListTile(
                        leading: Text(item['emoji'].isEmpty ? "❌" : item['emoji'], style: const TextStyle(fontSize: 24)),
                        title: Text(item['name'], style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                        subtitle: Text(isUnlocked ? "Terbuka" : "Butuh Lvl ${item['level_req']}", style: TextStyle(fontSize: 11, color: isUnlocked ? Colors.green : Colors.red)),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.blueAccent) : (!isUnlocked ? const Icon(Icons.lock, size: 18) : null),
                        enabled: isUnlocked,
                        onTap: () => setDialogState(() => selectedItemEmoji = item['emoji']),
                      );
                    }),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () {
                   // 📍 Jika batal, kembalikan ke wujud awal sebelum diedit
                   _loadPetData(); 
                   Navigator.pop(context);
                }, child: const Text("Batal", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB53471), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () async {
                    setState(() {
                      if (_nameController.text.trim().isNotEmpty) {
                        petName = _nameController.text.trim();
                      }
                    });
                    
                    // 1. Simpan Nama Pet ke SQLite
                    final db = await _dbHelper.database;
                    await db.rawUpdate('UPDATE users SET pet_name = ? WHERE username = ?', [petName, widget.user.username]);
                    
                    // 2. 📍 Simpan Emoji & Aksesoris ke Shared Preferences (Berdasarkan Username)
                    SharedPreferences prefs = await SharedPreferences.getInstance();
                    await prefs.setString('pet_emoji_${widget.user.username}', selectedPetEmoji);
                    await prefs.setString('pet_item_${widget.user.username}', selectedItemEmoji);
                    
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 40),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFFB53471), Color(0xFF833471)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(40)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () {
                     Navigator.pop(context);
                  })),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(petName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      Text("Study Pet Level $currentLevel", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _showEditPetDialog,
                icon: const Icon(Icons.tune, size: 16),
                label: const Text("Edit", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFB53471), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), elevation: 0),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadPetData,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                // Kartu Utama Pet
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.orange.shade50, Colors.yellow.shade50], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(selectedPetEmoji, style: const TextStyle(fontSize: 110)),
                          if (selectedItemEmoji.isNotEmpty)
                            Positioned(
                              bottom: 0,
                              right: 20,
                              child: Text(selectedItemEmoji, style: const TextStyle(fontSize: 36)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(petName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF833471))),
                      const SizedBox(height: 4),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sentiment_very_satisfied, color: Colors.green, size: 18),
                          SizedBox(width: 6),
                          Text("Sangat Senang", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Progress Bar Level Up
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(children: [Icon(Icons.trending_up, size: 16, color: Color(0xFFB53471)), SizedBox(width: 4), Text("Level Up", style: TextStyle(fontWeight: FontWeight.bold))]),
                          Text(nextLevelTarget, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: levelProgress, minHeight: 12, backgroundColor: Colors.grey.shade200, color: const Color(0xFFB53471))),
                      
                      const SizedBox(height: 20),

                      // Progress Bar Daily Screen Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(children: [Icon(Icons.timer, size: 16, color: Colors.orange), SizedBox(width: 4), Text("Daily Screen Time", style: TextStyle(fontWeight: FontWeight.bold))]),
                          Text("$sessionMinutes/30 mnt", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: (sessionMinutes / 30).clamp(0.0, 1.0), minHeight: 12, backgroundColor: Colors.grey.shade200, color: Colors.orange)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),

                // Kartu Info Aturan Merawat Pet
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.shade200)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [Icon(Icons.auto_awesome, color: Colors.blue), SizedBox(width: 8), Text("Cara Merawat Pet", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueAccent))]),
                      const SizedBox(height: 12),
                      _buildRuleBullet("Bantu jawab pertanyaan di Beranda (+10 poin)"),
                      _buildRuleBullet("Buat Ruang Belajar baru (+5 poin)"),
                      _buildRuleBullet("Cek Fakta AI Akurasi > 60% (+5 poin)"),
                      _buildRuleBullet("Capai 30 menit belajar per hari (+5 poin)"),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text("Hadiah Tersedia", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(child: _buildRewardCard("Aksesori Keren", "Terbuka di Lvl 3", Icons.checkroom, currentLevel >= 3)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildRewardCard("Ganti Model Naga", "Terbuka di Lvl 5", Icons.pets, currentLevel >= 5)),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)), Expanded(child: Text(text, style: TextStyle(color: Colors.blue.shade900)))]),
    );
  }

  Widget _buildRewardCard(String title, String subtitle, IconData icon, bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isUnlocked ? Colors.white : Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: isUnlocked ? const Color(0xFFB53471) : Colors.grey.shade300, width: isUnlocked ? 2 : 1)),
      child: Column(
        children: [
          Icon(icon, size: 40, color: isUnlocked ? const Color(0xFFB53471) : Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: isUnlocked ? Colors.black87 : Colors.grey)),
          const SizedBox(height: 4),
          Text(isUnlocked ? "Tersedia!" : subtitle, style: TextStyle(fontSize: 12, color: isUnlocked ? Colors.green : Colors.grey)),
        ],
      ),
    );
  }
}