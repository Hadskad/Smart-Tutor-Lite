import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/transcription_model.dart';

abstract class TranscriptionRemoteDataSource {
  Future<TranscriptionModel> transcribeAudio(String audioPath);

  Future<TranscriptionModel> fetchTranscription(String id);

  Future<TranscriptionModel> formatNote(String id);

  Future<void> deleteTranscription(String id);
}

@LazySingleton(as: TranscriptionRemoteDataSource)
class TranscriptionRemoteDataSourceImpl
    implements TranscriptionRemoteDataSource {
  TranscriptionRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<TranscriptionModel> transcribeAudio(String audioPath) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          audioPath,
          filename: p.basename(audioPath),
        ),
      });
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.transcription,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      return TranscriptionModel.fromJson(response);
    } catch (error) {
      throw ServerFailure(
          message: 'Failed to transcribe using backend', cause: error);
    }
  }

  @override
  Future<TranscriptionModel> fetchTranscription(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConstants.transcription}/$id',
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      return TranscriptionModel.fromJson(response);
    } catch (error) {
      throw ServerFailure(
          message: 'Failed to fetch transcription', cause: error);
    }
  }

  @override
  Future<TranscriptionModel> formatNote(String id) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        '${ApiConstants.transcription}/$id/format',
        parser: (data) => Map<String, dynamic>.from(data as Map),
        maxRetries: 3,
      );
      // Extract transcription from response
      final transcriptionData =
          response['transcription'] as Map<String, dynamic>? ?? response;
      return TranscriptionModel.fromJson(transcriptionData);
    } catch (error) {
      throw ServerFailure(message: 'Failed to format note', cause: error);
    }
  }

  @override
  Future<void> deleteTranscription(String id) async {
    try {
      await _apiClient.delete<dynamic>(
        '${ApiConstants.transcription}/$id',
      );
    } catch (error) {
      throw ServerFailure(
          message: 'Failed to delete transcription', cause: error);
    }
  }
}
