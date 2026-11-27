import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import '../model/user_model.dart';

class AuthRemoteDatasource {
  static String get baseUrl => '${ApiConfig.baseUrl}/auth';

  /// 1. Gọi API Đăng ký
  Future<UserModel> register({
    required String username,
    required String password,
    required String fullName,
  }) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'full_name': fullName,
      }),
    )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 201 && body['success'] == true) {
      return UserModel.fromJson(body['data'] as Map<String, dynamic>);
    }

    throw Exception(body['message'] ?? 'Đăng ký thất bại');
  }

  /// 2. Gọi API Đăng nhập -> trả về cả token và user
  Future<({String token, UserModel user})> login({
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>;
      return (
      token: data['token'] as String,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
      );
    }

    throw Exception(body['message'] ?? 'Đăng nhập thất bại');
  }

  /// 3. Gọi API lấy thông tin user từ token đã lưu
  Future<UserModel> getMe(String token) async {
    final response = await http
        .get(
      Uri.parse('$baseUrl/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    )
        .timeout(const Duration(seconds: 10));

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && body['success'] == true) {
      return UserModel.fromJson(body['data'] as Map<String, dynamic>);
    }

    throw Exception(body['message'] ?? 'Phiên đăng nhập hết hạn');
  }
}