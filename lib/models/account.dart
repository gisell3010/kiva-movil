enum GlobalRole { user, support, admin, superAdmin }

class Account {
  const Account({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    required this.role,
    this.profileImage,
  });
  final int id;
  final String name;
  final String username;
  final String email;
  final GlobalRole role;
  final String? profileImage;
  bool get isStaff => role != GlobalRole.user;
  bool get isAdmin => role == GlobalRole.admin || role == GlobalRole.superAdmin;
  String get roleLabel => switch (role) {
    GlobalRole.user => 'Viajero',
    GlobalRole.support => 'Soporte',
    GlobalRole.admin => 'Administración',
    GlobalRole.superAdmin => 'Superadministración',
  };
  factory Account.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'ACTIVE') {
      throw const FormatException('Cuenta inactiva.');
    }
    final role = switch (json['role']) {
      'USER' => GlobalRole.user,
      'SUPPORT' => GlobalRole.support,
      'ADMIN' => GlobalRole.admin,
      'SUPER_ADMIN' => GlobalRole.superAdmin,
      _ => throw const FormatException('Rol no reconocido.'),
    };
    return Account(
      id: json['id'] as int,
      name: json['full_name'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      role: role,
      profileImage: json['profile_image'] as String?,
    );
  }
}
