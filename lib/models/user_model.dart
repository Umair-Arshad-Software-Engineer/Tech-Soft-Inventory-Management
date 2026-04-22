class UserModel {
  final int id;
  final String name;
  final String email;
  final String? token;
  final String role;        // ← add

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.token,
    required this.role,     // ← add
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      token: json['token'],
      role: json['role'] ?? 'worker',   // ← add
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    if (token != null) 'token': token,
    'role': role,    // ← add
  };
}