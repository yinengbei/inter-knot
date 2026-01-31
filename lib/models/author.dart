class AuthorModel {
  String login;
  String avatar;
  late String name;
  String? email;
  String? userId;

  // Adjusted for custom backend
  String get url => ''; // No external profile URL yet

  AuthorModel({
    required this.login,
    required this.avatar,
    required String? name,
    this.email,
    this.userId,
  }) : name = name ?? login;

  factory AuthorModel.fromJson(Map<String, dynamic> json) {
    // Strapi Media 字段可能包含 data 层，也可能通过 flatten plugin 只有 attributes
    // 假设结构是 avatar: { url: "..." }
    final avatarData = json['avatar'];
    String? avatarUrl;
    if (avatarData is Map) {
      avatarUrl = avatarData['url'] as String?;
    }
    
    // 补全完整 URL
    if (avatarUrl != null && !avatarUrl.startsWith('http')) {
      avatarUrl = 'https://ik.tiwat.cn$avatarUrl';
    }

    final username = json['username'] as String?;
    final userId = json['id']?.toString();
    return AuthorModel(
      login: json['name'] as String? ?? username ?? 'unknown',
      avatar: avatarUrl ?? 'https://ik.tiwat.cn/uploads/default_avatar.png',
      name: json['name'] as String? ?? username,
      email: json['email'] as String?,
      userId: userId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthorModel && other.login == login;

  @override
  int get hashCode => login.hashCode;
}
