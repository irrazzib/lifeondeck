import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient({String? baseUrl}) {
    const String rawBaseUrl = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:5000/api/v1',
    );
    // In prod API_BASE_URL is a relative path (e.g. /api/v1); resolving
    // it against Uri.base yields a same-origin absolute URL (no hardcoded domain,
    // no CORS). In dev the default is already absolute, so resolve leaves it intact.
    final String resolvedBaseUrl =
        baseUrl ?? Uri.base.resolve(rawBaseUrl).toString();
    _dio = Dio(
      BaseOptions(
        baseUrl: resolvedBaseUrl,
        connectTimeout: const Duration(seconds: 10),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) async {
          final String? token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: _onError,
      ),
    );
  }

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Refreshes the server JWT (typically via [AuthService]) and returns the new
  /// token, or null if refresh failed. Wired externally to avoid a circular
  /// dependency between [ApiClient] and the auth layer.
  Future<String?> Function()? onRefresh;

  static const String _retriedFlag = '__jwt_retried';

  /// On a 401, transparently refresh the JWT once and replay the request.
  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions options = err.requestOptions;
    final bool isAuthCall = options.path.contains('/auth/firebase');
    final bool alreadyRetried = options.extra[_retriedFlag] == true;

    if (err.response?.statusCode != 401 ||
        onRefresh == null ||
        alreadyRetried ||
        isAuthCall) {
      handler.next(err);
      return;
    }

    final String? newToken = await onRefresh!();
    if (newToken == null) {
      // Refresh failed (caller already signed out); propagate the original 401.
      handler.next(err);
      return;
    }

    options.extra[_retriedFlag] = true;
    options.headers['Authorization'] = 'Bearer $newToken';
    try {
      final Response<dynamic> response = await _dio.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    }
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final Response<Map<String, dynamic>> response =
        await _dio.post<Map<String, dynamic>>(path, data: body);
    return response.data!;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? params,
  }) async {
    final Response<Map<String, dynamic>> response =
        await _dio.get<Map<String, dynamic>>(path, queryParameters: params);
    return response.data!;
  }

  Future<void> postVoid(String path, Map<String, dynamic> body) async {
    await _dio.post<void>(path, data: body);
  }

  /// Probes the API `/health` endpoint (no auth required). Returns true when
  /// the server responds 200, false on any error/timeout/non-2xx.
  Future<bool> checkHealth() async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
