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
      version: 5, // 📍 Versi dinaikkan menjadi 5
      onCreate: (db, version) async {
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
            pet_exp INTEGER DEFAULT 0,
            profile_image TEXT DEFAULT '' 
          )
        ''');

        // 📍 Ditambahkan kolom username untuk memisahkan chat
        await db.execute('''
          CREATE TABLE chats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT,
            role TEXT NOT NULL,
            message TEXT NOT NULL,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
          )
        ''');

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

        await db.execute('''
          CREATE TABLE follows (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            follower TEXT,
            following TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
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
        if (oldVersion < 4) {
          await db.execute(
              'ALTER TABLE users ADD COLUMN profile_image TEXT DEFAULT ""');
        }
        // 📍 Update untuk versi 5: Menambahkan kolom username ke tabel chats lama
        if (oldVersion < 5) {
          await db.execute(
              'ALTER TABLE chats ADD COLUMN username TEXT DEFAULT ""');
        }
      },
    );
  }

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

  // --- AMBIL DATA USER (SINKRONISASI REAL-TIME) ---
  Future<UserModel?> getUserRealtime(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query('users', where: 'username = ?', whereArgs: [username]);
    if (maps.isNotEmpty) {
      return UserModel.fromMap(maps.first);
    }
    return null;
  }

  Future<UserModel?> getUserData(String username) async {
    return await getUserRealtime(username);
  }

  // --- UPDATE FOTO PROFIL ---
  Future<int> updateUserProfileImage(String username, String imagePath) async {
    final db = await database;
    return await db.update(
      'users',
      {'profile_image': imagePath},
      where: 'username = ?',
      whereArgs: [username],
    );
  }

  // --- SISTEM POIN ---
  Future<void> addPoints(String username, int points) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE users SET points = points + ? WHERE username = ?',
      [points, username],
    );
  }

  // --- MANAJEMEN CHAT AI ---
  // 📍 Dimodifikasi: Menyimpan username pemilik chat
  Future<int> saveMessage(String username, String role, String message) async {
    final db = await database;
    return await db.insert('chats', {
      'username': username,
      'role': role,
      'message': message,
    });
  }

  // 📍 Dimodifikasi: Mengambil chat khusus milik username yang sedang login
  Future<List<Map<String, String>>> getChatHistory(String username) async {
    final db = await database;
    List<Map<String, dynamic>> maps = await db.query(
      'chats',
      where: 'username = ?',
      whereArgs: [username],
      orderBy: 'id ASC',
    );

    return List.generate(maps.length, (i) {
      return {
        'role': maps[i]['role'].toString(),
        'message': maps[i]['message'].toString(),
      };
    });
  }

  // 📍 Dimodifikasi: Menghapus chat khusus milik username yang sedang login
  Future<void> clearChatHistory(String username) async {
    final db = await database;
    await db.delete('chats', where: 'username = ?', whereArgs: [username]);
  }

  // --- MANAJEMEN FORUM & STATS ---
  Future<int> insertQuestion(Map<String, dynamic> questionData) async {
    final db = await database;
    return await db.insert('questions', questionData);
  }

  Future<List<Map<String, dynamic>>> getQuestions(
      String searchQuery, String selectedCategory) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchQuery.isNotEmpty) {
      whereClause += 'question LIKE ?';
      whereArgs.add('%$searchQuery%');
    }

    if (selectedCategory != 'Semua' && selectedCategory.isNotEmpty) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'category = ?';
      whereArgs.add(selectedCategory);
    }

    if (whereClause.isNotEmpty) {
      return await db.query('questions',
          where: whereClause, whereArgs: whereArgs, orderBy: 'id DESC');
    } else {
      return await db.query('questions', orderBy: 'id DESC');
    }
  }

  Future<int> insertAnswer(Map<String, dynamic> answerData) async {
    final db = await database;
    await db.rawUpdate(
        'UPDATE questions SET comments = comments + 1 WHERE id = ?',
        [answerData['question_id']]);
    return await db.insert('answers', answerData);
  }

  Future<List<Map<String, dynamic>>> getAnswers(int questionId) async {
    final db = await database;
    return await db.query('answers',
        where: 'question_id = ?', whereArgs: [questionId], orderBy: 'id ASC');
  }

  Future<Map<String, int>> getUserStats(String username) async {
    final db = await database;

    final qCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM questions WHERE username = ?',
            [username])) ??
        0;
    final aCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM answers WHERE username = ?', [username])) ??
        0;
    // 📍 Dimodifikasi: Statistik chat hanya menghitung chat miliknya
    final aiCount = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM chats WHERE username = ?', [username])) ??
        0;

    return {
      'questions': qCount,
      'answers': aCount,
      'ai_chats': aiCount,
    };
  }

  Future<void> updateUsername(String oldUsername, String newUsername) async {
    final db = await database;
    await db.update(
      'users',
      {'username': newUsername},
      where: 'username = ?',
      whereArgs: [oldUsername],
    );
  }


// 1. Fungsi mencari akun user berdasarkan ketikan di Search Bar
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await database;
    return await db.query(
      'users',
      where: 'username LIKE ?',
      whereArgs: ['%$query%'],
      limit: 5, // Batasi hasil pencarian akun
    );
  }

  // 2. Fungsi Follow / Unfollow
  Future<void> toggleFollow(String follower, String following) async {
    final db = await database;
    final existing = await db.query('follows', where: 'follower = ? AND following = ?', whereArgs: [follower, following]);
    
    if (existing.isNotEmpty) {
      // Jika sudah follow, maka Unfollow
      await db.delete('follows', where: 'follower = ? AND following = ?', whereArgs: [follower, following]);
    } else {
      // Jika belum, maka Follow
      await db.insert('follows', {'follower': follower, 'following': following});
    }
  }

  // 3. Cek status Follow
  Future<bool> isFollowing(String follower, String following) async {
    final db = await database;
    final res = await db.query('follows', where: 'follower = ? AND following = ?', whereArgs: [follower, following]);
    return res.isNotEmpty;
  }

  // 4. Hitung Followers & Following
  Future<int> getFollowersCount(String username) async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM follows WHERE following = ?', [username]);
    return res.first['count'] as int? ?? 0;
  }

  Future<int> getFollowingCount(String username) async {
    final db = await database;
    final res = await db.rawQuery('SELECT COUNT(*) as count FROM follows WHERE follower = ?', [username]);
    return res.first['count'] as int? ?? 0;
  }

  // --- FUNGSI MENGAMBIL RIWAYAT JAWABAN USER ---
  Future<List<Map<String, dynamic>>> getUserAnswers(String username) async {
    final db = await database;
    // Mengambil teks jawaban sekaligus detail pertanyaan aslinya
    return await db.rawQuery('''
      SELECT 
        a.content AS answer_content, 
        a.created_at AS answer_date,
        a.likes AS answer_likes, 
        q.id, q.username, q.category, q.question, q.description, 
        q.tags, q.image_path, q.created_at, q.likes, q.comments
      FROM answers a
      JOIN questions q ON a.question_id = q.id
      WHERE a.username = ?
      ORDER BY a.id DESC
    ''', [username]);
  }
}