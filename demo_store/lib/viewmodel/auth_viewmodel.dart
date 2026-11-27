import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/datasources/auth_remote_datasource.dart';
import '../data/model/user_model.dart';

class AuthViewModel extends ChangeNotifier {
  static const String _tokenKey = 'auth_jwt_token';

  final AuthRemoteDatasource _datasource = AuthRemoteDatasource();

  UserModel? _currentUser;
  String? _token;
  bool _isLoading = false;
  bool _isCheckingAuth = true; // Đang kiểm tra token cũ lúc mới mở app
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoggedIn => _currentUser != null && _token != null;
  bool get isLoading => _isLoading;
  bool get isCheckingAuth => _isCheckingAuth;
  String? get errorMessage => _errorMessage;

  /// Tự động kiểm tra xem máy đã lưu token đăng nhập trước đó chưa
  Future<void> checkAuthStatus() async {
    _isCheckingAuth = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(_tokenKey);

      if (savedToken != null && savedToken.isNotEmpty) {
        final user = await _datasource.getMe(savedToken);
        _token = savedToken;
        _currentUser = user;
      }
    } catch (_) {
      // Token hết hạn hoặc không hợp lệ -> xóa đi để đăng nhập lại
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      _token = null;
      _currentUser = null;
    } finally {
      _isCheckingAuth = false;
      notifyListeners();
    }
  }

  /// Đăng nhập -> thành công thì lưu token vào máy
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _datasource.login(
        username: username.trim(),
        password: password,
      );

      _token = result.token;
      _currentUser = result.user;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, result.token);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng ký tài khoản mới
  Future<bool> register({
    required String username,
    required String password,
    required String fullName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _datasource.register(
        username: username.trim(),
        password: password,
        fullName: fullName.trim(),
      );

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('=== REGISTER ERROR: $e ===');
      _errorMessage = _cleanError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Đăng xuất -> xóa token khỏi máy
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);

    _token = null;
    _currentUser = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _cleanError(Object e) {
    final msg = e.toString();
    if (msg.startsWith('Exception: ')) {
      return msg.replaceFirst('Exception: ', '');
    }
    return 'Không thể kết nối tới máy chủ, vui lòng kiểm tra lại mạng';
  }
}