import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({
    required this.baseUrl,
  });

  final String baseUrl;

  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _authTimeout = Duration(seconds: 75);

  String? _token;
  Future<void> Function()? _onUnauthorized;

  void setToken(String? token) {
    _token = token;
  }

  void setUnauthorizedHandler(Future<void> Function()? handler) {
    _onUnauthorized = handler;
  }

  Map<String, String> _headers({bool includeJson = true}) {
    final headers = <String, String>{};

    if (includeJson) {
      headers['Content-Type'] = 'application/json';
    }

    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return headers;
  }

  Uri _uri(String path) {
    return Uri.parse('$baseUrl$path');
  }

  Duration _timeoutFor(String path) {
    if (path.startsWith('/auth')) {
      return _authTimeout;
    }
    return _defaultTimeout;
  }

  Future<http.Response> _handleResponse(
    Future<http.Response> request, {
    required String path,
  }) async {
    try {
      final response = await request.timeout(
        _timeoutFor(path),
        onTimeout: () {
          throw Exception('サーバーへの接続がタイムアウトしました。バックエンドが起動しているか確認してください。');
        },
      );

      if (response.statusCode == 401 && _onUnauthorized != null) {
        await _onUnauthorized!();
      }

      return response;
    } on http.ClientException catch (e) {
      throw Exception('サーバーに接続できません。API_BASE_URL、CORS設定、バックエンドの起動状態を確認してください。$e');
    }
  }

  Future<http.Response> get(String path) {
    return _handleResponse(
      http.get(
        _uri(path),
        headers: _headers(),
      ),
      path: path,
    );
  }

  Future<http.Response> postJson(String path, Map<String, dynamic> body) {
    return _handleResponse(
      http.post(
        _uri(path),
        headers: _headers(),
        body: jsonEncode(body),
      ),
      path: path,
    );
  }

  Future<http.Response> putJson(String path, Map<String, dynamic> body) {
    return _handleResponse(
      http.put(
        _uri(path),
        headers: _headers(),
        body: jsonEncode(body),
      ),
      path: path,
    );
  }

  Future<http.Response> delete(String path) {
    return _handleResponse(
      http.delete(
        _uri(path),
        headers: _headers(),
      ),
      path: path,
    );
  }

  Future<http.Response> postForm(
    String path,
    Map<String, String> body,
  ) {
    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
    };

    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    return _handleResponse(
      http.post(
        _uri(path),
        headers: headers,
        body: body,
      ),
      path: path,
    );
  }
}
