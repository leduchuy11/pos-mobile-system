class UserModel {
  final int id;
  final String username;
  final String fullName;

  const UserModel({
    required this.id,
    required this.username,
    required this.fullName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      fullName: json['full_name'] as String,
    );
  }
}