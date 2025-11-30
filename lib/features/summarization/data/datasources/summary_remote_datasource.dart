import 'package:injectable/injectable.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/summary_model.dart';

abstract class SummaryRemoteDataSource {
  Future<SummaryModel> summarizeText({
    required String text,
    int maxLength = 200,
  });

  Future<SummaryModel> summarizePdf({
    required String pdfUrl,
    int maxLength = 200,
  });

  Future<SummaryModel> getSummary(String id);
}

@LazySingleton(as: SummaryRemoteDataSource)
class SummaryRemoteDataSourceImpl implements SummaryRemoteDataSource {
  SummaryRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<SummaryModel> summarizeText({
    required String text,
    int maxLength = 200,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.summarize,
        data: {
          'text': text,
          'maxLength': maxLength,
          'sourceType': 'text',
        },
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      return SummaryModel.fromJson(response);
    } catch (error) {
      throw ServerFailure(
        message: 'Failed to summarize text',
        cause: error,
      );
    }
  }

  @override
  Future<SummaryModel> summarizePdf({
    required String pdfUrl,
    int maxLength = 200,
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.summarize,
        data: {
          'pdfUrl': pdfUrl,
          'maxLength': maxLength,
          'sourceType': 'pdf',
        },
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      return SummaryModel.fromJson(response);
    } catch (error) {
      throw ServerFailure(
        message: 'Failed to summarize PDF',
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
    } catch (error) {
      throw ServerFailure(
        message: 'Failed to fetch summary',
        cause: error,
      );
    }
  }
}
