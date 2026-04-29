import 'package:flutter/foundation.dart';

import '../models/user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/token_storage_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    required this.authService,
    required this.tokenStorageService,
    required this.apiClient,
  }) {
    apiClient.setUnauthorizedHandler(_handleUnauthorized);
  }

  final AuthService authService;
  final TokenStorageService tokenStorageService;
  final ApiClient apiClient;

  bool _isInitializing = true;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  String? _token;
  User? _currentUser;
  String? _errorMessage;

  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String? get token => _token;
  User? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final savedToken = await tokenStorageService.readToken();

      if (savedToken == null || savedToken.isEmpty) {
        _isLoggedIn = false;
        _token = null;
        _currentUser = null;
        apiClient.setToken(null);
        return;
      }

      _token = savedToken;
      apiClient.setToken(savedToken);

      final me = await authService.getMe();
      _currentUser = me;
      _isLoggedIn = true;
    } catch (_) {
      await tokenStorageService.clearToken();
      _token = null;
      _currentUser = null;
      _isLoggedIn = false;
      apiClient.setToken(null);
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResponse = await authService.login(
        email: email,
        password: password,
      );

      _token = authResponse.accessToken;
      apiClient.setToken(_token);

      await tokenStorageService.saveToken(_token!);

      final me = await authService.getMe();
      _currentUser = me;
      _isLoggedIn = true;

      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoggedIn = false;
      _currentUser = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signup({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await authService.register(
        email: email,
        password: password,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await tokenStorageService.clearToken();
    } finally {
      _token = null;
      _currentUser = null;
      _isLoggedIn = false;
      _errorMessage = null;
      apiClient.setToken(null);
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _handleUnauthorized() async {
    await tokenStorageService.clearToken();
    _token = null;
    _currentUser = null;
    _isLoggedIn = false;
    _errorMessage = '認証の有効期限が切れました。再度ログインしてください。';
    apiClient.setToken(null);
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}