import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/summary_model.dart';

abstract class SummaryRemoteDataSource {
  Future<SummaryModel> summarizeText({
    required String text,
  });

  Future<SummaryModel> summarizePdf({
    required String pdfUrl,
  });

  Future<SummaryModel> getSummary(String id);
}

@LazySingleton(as: SummaryRemoteDataSource)
class SummaryRemoteDataSourceImpl implements SummaryRemoteDataSource {
  SummaryRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  /// Options with extended timeout for AI summarization operations
  Options get _summarizationOptions => Options(
        receiveTimeout: AppConstants.summarizationTimeout,
        sendTimeout: const Duration(minutes: 2),
      );

  @override
  Future<SummaryModel> summarizeText({
    required String text,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.summarize,
        data: {
          'text': text,
          'sourceType': 'text',
        },
        options: _summarizationOptions,
        parser: (data) => Map<String, dynamic>.from(data as Map),
        maxRetries: 1, // Reduce retries for long operations
      );
      return SummaryModel.fromJson(response);
    } on Failure {
      rethrow;
    } catch (error) {
      throw ServerFailure(
        message: _extractErrorMessage(error, 'Failed to summarize text'),
        cause: error,
      );
    }
  }

  @override
  Future<SummaryModel> summarizePdf({
    required String pdfUrl,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.summarize,
        data: {
          'pdfUrl': pdfUrl,
          'sourceType': 'pdf',
        },
        options: _summarizationOptions,
        parser: (data) => Map<String, dynamic>.from(data as Map),
        maxRetries: 1, // Reduce retries for long operations
      );
      return SummaryModel.fromJson(response);
    } on Failure {
      rethrow;
    } catch (error) {
      throw ServerFailure(
        message: _extractErrorMessage(error, 'Failed to summarize PDF'),
        cause: error,
      );
    }
  }

  @override
  Future<SummaryModel> getSummary(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConstants.summarize}/$id',
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      return SummaryModel.fromJson(response);
    } on Failure {
      rethrow;
    } catch (error) {
      throw ServerFailure(
        message: _extractErrorMessage(error, 'Failed to fetch summary'),
        cause: error,
      );
    }
  }

  /// Extract a more specific error message from the error
  String _extractErrorMessage(Object error, String fallback) {
    if (error is DioException) {
      // Check for response error messages
      final responseData = error.response?.data;
      if (responseData is Map) {
        final message = responseData['message'] ?? responseData['error'];
        if (message != null && message.toString().isNotEmpty) {
          return message.toString();
        }
      }

      // Handle specific error types
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return 'Connection timed out. Please check your internet connection.';
        case DioExceptionType.sendTimeout:
          return 'Request timed out while sending data.';
        case DioExceptionType.receiveTimeout:
          return 'Server took too long to respond. Please try again.';
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 413) {
            return 'PDF file is too large to process.';
          } else if (statusCode == 503) {
            return 'Service temporarily unavailable. Please try again later.';
          } else if (statusCode != null && statusCode >= 500) {
            return 'Server error. Please try again later.';
          }
          break;
        case DioExceptionType.connectionError:
          return 'Connection error. Please check your internet connection.';
        default:
          break;
      }

      // Use error message if available
      if (error.message != null && error.message!.isNotEmpty) {
        return error.message!;
      }
    }

    return fallback;
  }
}
