import 'dart:async';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../constants/api_constants.dart';
import '../errors/failures.dart';
import 'network_info.dart';

typedef ResponseParser<T> = T Function(dynamic data);

@LazySingleton()
class ApiClient {
  ApiClient(this._dio, this._networkInfo);

  final Dio _dio;
  final NetworkInfo _networkInfo;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    ResponseParser<T>? parser,
  }) async {
    return _request(
      () => _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      ),
      parser,
      maxRetries: 2,
    );
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    ResponseParser<T>? parser,
  }) async {
    return _request(
      () => _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      parser,
    );
  }

  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    ResponseParser<T>? parser,
  }) async {
    return _request(
      () => _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      ),
      parser,
    );
  }

  Future<T> _request<T>(
    Future<Response<dynamic>> Function() action,
    ResponseParser<T>? parser, {
    int maxRetries = 0,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    var attempt = 0;

    while (true) {
      final connected = await _networkInfo.isConnected;
      if (!connected) {
        throw const NetworkFailure(message: 'No internet connection');
      }
      try {
        final response = await action();
        if (parser != null) {
          return parser(response.data);
        }
        return response.data as T;
      } on DioException catch (error) {
        final shouldRetry = attempt < maxRetries && _isRetryable(error);
        if (!shouldRetry) {
          final message = error.response?.data?['message']?.toString() ??
              error.message ??
              'Unknown server error';
          throw ServerFailure(message: message, cause: error);
        }
        attempt++;
        await Future.delayed(retryDelay);
      } catch (error) {
        throw LocalFailure(message: error.toString(), cause: error);
      }
    }
  }

  bool _isRetryable(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode ?? 0;
        return statusCode >= 500;
      case DioExceptionType.cancel:
        return false;
      default:
        return true;
    }
  }
}

BaseOptions buildBaseOptions() {
  return BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    responseType: ResponseType.json,
    contentType: 'application/json',
  );
}
