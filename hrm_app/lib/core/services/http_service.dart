import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hrm_app/core/constants/app_constants.dart';

class HttpException implements Exception {
  final String message;
  const HttpException(this.message);
  @override
  String toString() => message;
}

class HttpService {
  late final Dio _dio;

  HttpService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
        validateStatus: (status) {
          return status != null && status < 500;
        },
      ),
    );
  }

  Future<dynamic> _handleRequest(
    Future<Response> Function() requestFn, {
    String? contextName,
    bool isVoid = false,
    int expectedStatusCode = 200,
  }) async {
    try {
      final response = await requestFn();

      if (response.statusCode != expectedStatusCode &&
          response.statusCode != 201 &&
          response.statusCode != 200) {
        if (response.statusCode != expectedStatusCode) {
          String message = 'API Error: Status Code ${response.statusCode}';
          if (response.data is Map<String, dynamic> &&
              (response.data as Map).containsKey('message')) {
            message = response.data['message'];
          } else if (response.data is String) {
            message = response.data;
          }
          throw HttpException(message);
        }
      }

      if (isVoid) return null;
      return response.data;
    } on DioException catch (e) {
      String message = 'An unexpected error occurred';
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const SocketException('Request timeout - server not responding');
      } else if (e.type == DioExceptionType.connectionError) {
        throw const SocketException(
          'No Internet connection or server is down.',
        );
      }

      if (e.response?.data != null) {
        if (e.response!.data is Map<String, dynamic> &&
            (e.response!.data as Map).containsKey('message')) {
          message = e.response!.data['message'];
        } else if (e.response!.data is String) {
          message = e.response!.data;
        }
      }
      throw HttpException(message);
    } catch (e) {
      throw HttpException(e.toString());
    }
  }

  Options _getOptions(String? token) {
    if (token != null) {
      return Options(headers: {'Authorization': 'Bearer $token'});
    }
    return Options();
  }

  Future<dynamic> get(
    String endpoint, {
    String? token,
    Map<String, dynamic>? queryParams,
    String? contextName,
  }) async {
    return _handleRequest(
      () => _dio.get(
        endpoint,
        queryParameters: queryParams,
        options: _getOptions(token),
      ),
      contextName: contextName,
    );
  }

  Future<dynamic> post(
    String endpoint, {
    String? token,
    Object? body,
    String? contextName,
    int expectedStatusCode = 200,
    bool isVoid = false,
  }) async {
    return _handleRequest(
      () => _dio.post(endpoint, data: body, options: _getOptions(token)),
      contextName: contextName,
      expectedStatusCode: expectedStatusCode,
      isVoid: isVoid,
    );
  }

  Future<dynamic> put(
    String endpoint, {
    String? token,
    Object? body,
    String? contextName,
    bool isVoid = false,
  }) async {
    return _handleRequest(
      () => _dio.put(endpoint, data: body, options: _getOptions(token)),
      contextName: contextName,
      isVoid: isVoid,
    );
  }

  Future<dynamic> delete(
    String endpoint, {
    String? token,
    String? contextName,
    bool isVoid = false,
    int expectedStatusCode = 200,
  }) async {
    return _handleRequest(
      () => _dio.delete(endpoint, options: _getOptions(token)),
      contextName: contextName,
      isVoid: isVoid,
      expectedStatusCode: expectedStatusCode,
    );
  }

  Future<File> download(
    String endpoint, {
    String? token,
    String? contextName,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final tempDir = Directory.systemTemp;
      final fileName = endpoint
          .split('/')
          .last
          .replaceAll(RegExp(r'[^\w\.-]'), '_');
      final savePath = '${tempDir.path}${Platform.pathSeparator}$fileName';

      await _dio.download(
        endpoint,
        savePath,
        options: _getOptions(token),
        queryParameters: queryParams,
      );

      return File(savePath);
    } catch (e) {
      throw HttpException('Download failed: $e');
    }
  }
}
