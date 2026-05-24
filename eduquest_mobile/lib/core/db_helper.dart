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
      version: 3, // 📍 Naik ke versi 3 untuk tabel forum (questions & answers)
      onCreate: (db, version) async {
        // 1. Pembuatan tabel users
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

        // 2. Pembuatan tabel chats AI
        await db.execute('''
          CREATE TABLE chats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            role TEXT NOT NULL,
            message TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // 3. Pembuatan tabel questions (Forum)
        await db.execute('''
          CREATE TABLE questions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT,
            category TEXT,
            question TEXT,
            description TEXT,
            tags TEXT,
            image_path TEXT,
            likes INTEGER DEFAULT 0,
            comments INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

        // 4. Pembuatan tabel answers (Komentar Forum)
        await db.execute('''
          CREATE TABLE answers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            question_id INTEGER,
            username TEXT,
            content TEXT,
            image_path TEXT,
            likes INTEGER DEFAULT 0,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // Upgrade dari versi 1 ke 2 (Tambah tabel chat)
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
        // Upgrade dari versi 2 ke 3 (Tambah tabel forum tanpa perlu hapus aplikasi)
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE questions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              username TEXT,
              category TEXT,
              question TEXT,
              description TEXT,
              tags TEXT,
              image_path TEXT,
              likes INTEGER DEFAULT 0,
              comments INTEGER DEFAULT 0,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');

          await db.execute('''
            CREATE TABLE answers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              question_id INTEGER,
              username TEXT,
              content TEXT,
              image_path TEXT,
              likes INTEGER DEFAULT 0,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''');
        }
      },
    );
  }

  // --- KODE AUTENTIKASI USER ---
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

  // --- FUNGSI MENGAMBIL DATA USER TERBARU (Untuk Sync Real-Time) ---
  Future<UserModel?> getUserData(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  // --- MANAJEMEN CHAT AI ---
  Future<int> saveMessage(String role, String message) async {
    final db = await database;
    return await db.insert('chats', {
      'role': role,
      'message': message,
    });
  }

  Future<List<Map<String, String>>> getChatHistory() async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query('chats', orderBy: 'id ASC');
    
    return List.generate(maps.length, (i) {
      return {
        'role': maps[i]['role'].toString(),
        'message': maps[i]['message'].toString(),
      };
    });
  }

  Future<void> clearChatHistory() async {
    final db = await database;
    await db.delete('chats');
  }
  
  // --- FITUR GAMIFIKASI: TAMBAH POIN & NAIK LEVEL ---
  Future<void> addPoints(String username, int pointsToAdd) async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query('users', where: 'username = ?', whereArgs: [username]);
    
    if (maps.isNotEmpty) {
      int currentPoints = maps.first['points'] as int;
      int newPoints = currentPoints + pointsToAdd;

      int newLevel = 1;
      if (newPoints >= 200) {
        newLevel = 5;
      } else if (newPoints >= 150) newLevel = 4;
      else if (newPoints >= 100) newLevel = 3;
      else if (newPoints >= 50) newLevel = 2;

      await db.update(
        'users', 
        {'points': newPoints, 'pet_level': newLevel}, 
        where: 'username = ?', 
        whereArgs: [username]
      );
    }
  }

  // --- FUNGSI FORUM (MENGAMBIL PERTANYAAN DENGAN FILTER & SEARCH) ---
  Future<List<Map<String, dynamic>>> getQuestions(String query, String category) async {
    final db = await database;
    String whereString = "";
    List<dynamic> whereArgs = [];

    if (category != "Semua") {
      whereString += "category = ?";
      whereArgs.add(category);
    }

    if (query.isNotEmpty) {
      if (whereString.isNotEmpty) whereString += " AND ";
      whereString += "(question LIKE ? OR description LIKE ? OR tags LIKE ?)";
      whereArgs.addAll(["%$query%", "%$query%", "%$query%"]);
    }

    return await db.query(
      'questions',
      where: whereString.isEmpty ? null : whereString,
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: "id DESC", // Pertanyaan terbaru muncul di paling atas
    );
  }
  // --- FUNGSI TAMBAH PERTANYAAN BARU ---
  Future<int> insertQuestion(Map<String, dynamic> questionData) async {
    final db = await database;
    return await db.insert('questions', questionData);
  }

  // --- FUNGSI FORUM JAWABAN ---
  Future<int> insertAnswer(Map<String, dynamic> answerData) async {
    final db = await database;
    // Update jumlah komentar di tabel questions
    await db.rawUpdate('UPDATE questions SET comments = comments + 1 WHERE id = ?', [answerData['question_id']]);
    return await db.insert('answers', answerData);
  }

  Future<List<Map<String, dynamic>>> getAnswers(int questionId) async {
    final db = await database;
    return await db.query('answers', where: 'question_id = ?', whereArgs: [questionId], orderBy: 'id ASC');
  }
  // --- FUNGSI AMBIL STATISTIK REAL-TIME ---
  Future<Map<String, int>> getUserStats(String username) async {
    final db = await database;
    
    // Hitung Pertanyaan
    final qCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM questions WHERE username = ?', [username])) ?? 0;
    
    // Hitung Jawaban
    final aCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM answers WHERE username = ?', [username])) ?? 0;
    
    // Hitung Chat AI (Mengambil total chat yang ada)
    final aiCount = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM chats')) ?? 0;

    return {
      'questions': qCount,
      'answers': aCount,
      'ai_chats': aiCount,
    };
  }

  // --- FUNGSI UPDATE NAMA USER ---
  Future<void> updateUsername(String oldUsername, String newUsername) async {
    final db = await database;
    await db.update(
      'users',
      {'username': newUsername},
      where: 'username = ?',
      whereArgs: [oldUsername],
    );
  }
}