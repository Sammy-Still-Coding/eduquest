import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';

class DbHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String pathDb = join(await getDatabasesPath(), 'eduquest_local.db');
    
    return await openDatabase(
      pathDb,
      version: 2, // 📍 Naik ke versi 2 untuk menambahkan tabel baru
      onCreate: (db, version) async {
        // Pembuatan tabel users
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL UNIQUE,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            points INTEGER DEFAULT 0,
            streak_count INTEGER DEFAULT 0,
            pet_name TEXT DEFAULT 'Eggie',
            pet_level INTEGER DEFAULT 1,
            pet_exp INTEGER DEFAULT 0
          )
        ''');

        // 📍 Pembuatan tabel chats baru
        await db.execute('''
          CREATE TABLE chats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            role TEXT NOT NULL, -- 'user' atau 'ai'
            message TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Logika jika aplikasi mendeteksi user punya DB versi 1, otomatis disuntik tabel chats
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE chats (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              role TEXT NOT NULL,
              message TEXT NOT NULL,
              timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');
        }
      },
    );
  }

  // --- KODE AUTENTIKASI USER (KEMARIN) ---
  String _hashPassword(String password) {
    var bytes = utf8.encode(password); 
    return sha256.convert(bytes).toString();
  }

  Future<int> registerUser(UserModel user) async {
    final db = await database;
    String encryptedPassword = _hashPassword(user.password);
    Map<String, dynamic> row = user.toMap();
    row['password'] = encryptedPassword; 
    try {
      return await db.insert('users', row);
    } catch (e) {
      return -1;
    }
  }

  Future<UserModel?> loginUser(String emailOrUsername, String password) async {
    final db = await database;
    String encryptedPassword = _hashPassword(password);
    List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: '(email = ? OR username = ?) AND password = ?',
      whereArgs: [emailOrUsername, emailOrUsername, encryptedPassword],
    );
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  // --- 📍 FITUR BARU: MANAJEMEN CHAT AI ---

  // 1. Fungsi menyimpan pesan baru (User/AI) ke database
  Future<int> saveMessage(String role, String message) async {
    final db = await database;
    return await db.insert('chats', {
      'role': role,
      'message': message,
    });
  }

  // 2. Fungsi mengambil seluruh riwayat chat secara berurutan
  Future<List<Map<String, String>>> getChatHistory() async {
    final db = await database;
    // Mengambil data diurutkan berdasarkan id paling lama ke terbaru
    List<Map<String, dynamic>> maps = await db.query('chats', orderBy: 'id ASC');
    
    return List.generate(maps.length, (i) {
      return {
        'role': maps[i]['role'].toString(),
        'message': maps[i]['message'].toString(),
      };
    });
  }

  // 3. Fungsi opsional jika ingin menghapus seluruh obrolan (Clear Chat)
  Future<void> clearChatHistory() async {
    final db = await database;
    await db.delete('chats');
  }
}