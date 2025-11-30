import 'package:injectable/injectable.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/tts_job_model.dart';

abstract class TtsRemoteDataSource {
  Future<TtsJobModel> convertPdfToAudio({
    required String pdfUrl,
    String voice = 'en-US-Standard-B',
  });

  Future<TtsJobModel> convertTextToAudio({
    required String text,
    String voice = 'en-US-Standard-B',
  });

  Future<TtsJobModel> getTtsJob(String id);
}

@LazySingleton(as: TtsRemoteDataSource)
class TtsRemoteDataSourceImpl implements TtsRemoteDataSource {
  TtsRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<TtsJobModel> convertPdfToAudio({
    required String pdfUrl,
    String voice = 'en-US-Standard-B',
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.textToSpeech,
        data: {
          'sourceType': 'pdf',
          'sourceId': pdfUrl,
          'voice': voice,
        },
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      return TtsJobModel.fromJson(response);
    } catch (error) {
      throw ServerFailure(
        message: 'Failed to convert PDF to audio',
        cause: error,
      );
    }
  }

  @override
  Future<TtsJobModel> convertTextToAudio({
    required String text,
    String voice = 'en-US-Standard-B',
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.textToSpeech,
        data: {
          'sourceType': 'text',
          'sourceId': text,
          'voice': voice,
        },
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      return TtsJobModel.fromJson(response);
    } catch (error) {
      throw ServerFailure(
        message: 'Failed to convert text to audio',
        cause: error,
      );
    }
  }

  @override
  Future<TtsJobModel> getTtsJob(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConstants.textToSpeech}/$id',
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      return TtsJobModel.fromJson(response);
    } catch (error) {
      throw ServerFailure(
        message: 'Failed to fetch TTS job',
        cause: error,
      );
    }
  }
}

