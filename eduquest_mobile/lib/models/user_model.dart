class UserModel {
  final int? id;
  final String username;
  final String email;
  final String password;
  final int points;
  final int streakCount;
  final String petName;
  final int petLevel;
  final int petExp;

  UserModel({
    this.id,
    required this.username,
    required this.email,
    required this.password,
    this.points = 0,
    this.streakCount = 0,
    this.petName = 'Eggie',
    this.petLevel = 1,
    this.petExp = 0,
  });

  // Mengubah objek UserModel menjadi Map (untuk dimasukkan ke SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'points': points,
      'streak_count': streakCount,
      'pet_name': petName,
      'pet_level': petLevel,
      'pet_exp': petExp,
    };
  }

  // Mengubah Map dari SQLite kembali menjadi objek UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      password: map['password'],
      points: map['points'] ?? 0,
      streakCount: map['streak_count'] ?? 0,
      petName: map['pet_name'] ?? 'Eggie',
      petLevel: map['pet_level'] ?? 1,
      petExp: map['pet_exp'] ?? 0,
    );
  }
}