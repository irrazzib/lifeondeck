import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient({String baseUrl = 'http://localhost:5000/api/v1'}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
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
      ),
    );
  }

  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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
}
