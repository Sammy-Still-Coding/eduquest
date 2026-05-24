import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/db_helper.dart';
import '../models/user_model.dart';
import 'package:intl/intl.dart';

class BuatPertanyaanPage extends StatefulWidget {
  final UserModel user;
  const BuatPertanyaanPage({super.key, required this.user});

  @override
  State<BuatPertanyaanPage> createState() => _BuatPertanyaanPageState();
}

class _BuatPertanyaanPageState extends State<BuatPertanyaanPage> {
  final _questionController = TextEditingController();
  final _descController = TextEditingController();
  final _tagsController = TextEditingController();
  
  String _selectedCategory = "Matematika";
  final List<String> _categories = ["Matematika", "Fisika", "Kimia", "Biologi", "Bahasa Inggris", "Lainnya"];
  
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  final Color _primaryPurple = const Color(0xFF7B61FF);

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = pickedFile;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gagal mengambil gambar")));
    }
  }

  Future<void> _submitQuestion() async {
    if (_questionController.text.trim().isEmpty || _descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Judul dan deskripsi pertanyaan tidak boleh kosong!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);

    // Format tanggal hari ini (Contoh: 24/05/2026)
    String currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());

    // Membersihkan dan memformat hashtag
    String rawTags = _tagsController.text.trim();
    List<String> formattedTags = [];
    if (rawTags.isNotEmpty) {
      formattedTags = rawTags.split(' ').map((tag) => tag.startsWith('#') ? tag : '#$tag').toList();
    }

    Map<String, dynamic> questionData = {
      'username': widget.user.username,
      'category': _selectedCategory,
      'question': _questionController.text.trim(),
      'description': _descController.text.trim(),
      'tags': formattedTags.join(','), // Simpan sebagai string pisah koma
      'image_path': _selectedImage?.path ?? '', // Path gambar lokal jika ada
      'likes': 0,
      'comments': 0,
      'created_at': currentDate,
    };

    final dbHelper = DbHelper();
    await dbHelper.insertQuestion(questionData);

    setState(() => _isLoading = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Pertanyaan berhasil diposting! 🚀"), backgroundColor: Colors.green),
    );
    
    // Kembali ke Beranda sambil membawa sinyal "true" agar beranda me-refresh datanya
    Navigator.pop(context, true); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _primaryPurple,
        foregroundColor: Colors.white,
        title: const Text("Tanya Sesuatu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kategori
            const Text("Kategori Pelajaran", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  items: _categories.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)));
                  }).toList(),
                  onChanged: (newValue) => setState(() => _selectedCategory = newValue!),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Judul Pertanyaan
            const Text("Pertanyaan Inti", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _questionController,
              decoration: InputDecoration(
                hintText: "Contoh: Cara menghitung integral tentu?",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true, fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // Deskripsi Detail
            const Text("Deskripsi Lengkap", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _descController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: "Jelaskan bagian mana yang kamu bingung...\nKamu juga bisa melampirkan foto soal di bawah.",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true, fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),

            // Hashtags
            const Text("Hashtags (Pisahkan dengan spasi)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _tagsController,
              decoration: InputDecoration(
                hintText: "Contoh: #Kalkulus #MatematikaDasar",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                filled: true, fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                prefixIcon: const Icon(Icons.tag, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 24),

            // Area Upload Gambar
            const Text("Lampirkan Foto Soal (Opsional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (_selectedImage != null)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(_selectedImage!.path), width: double.infinity, height: 200, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: const CircleAvatar(backgroundColor: Colors.redAccent, radius: 14, child: Icon(Icons.close, color: Colors.white, size: 16)),
                    ),
                  )
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt), label: const Text("Kamera"),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickImage(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library), label: const Text("Galeri"),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 40),

            // Tombol Kirim
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitQuestion,
                style: ElevatedButton.styleFrom(backgroundColor: _primaryPurple, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Posting Pertanyaan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}