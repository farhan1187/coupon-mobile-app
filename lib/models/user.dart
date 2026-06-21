class AppUser {
  final String id;
  final String username;
  final String password;
  final String role;
  final String name;
  final bool twoFAEnabled;

  AppUser({
    required this.id,
    required this.username,
    required this.password,
    required this.role,
    required this.name,
    required this.twoFAEnabled,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      role: json['role'] as String,
      name: json['name'] as String,
      twoFAEnabled: json['two_fa_enabled'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'role': role,
      'name': name,
      'two_fa_enabled': twoFAEnabled,
    };
  }
}
