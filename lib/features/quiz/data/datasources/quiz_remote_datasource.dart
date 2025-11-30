import 'package:injectable/injectable.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/quiz_model.dart';

abstract class QuizRemoteDataSource {
  Future<QuizModel> generateQuiz({
    required String sourceId,
    required String sourceType,
    int numQuestions = 5,
    String difficulty = 'medium',
  });

  Future<QuizModel> getQuiz(String id);
}

@LazySingleton(as: QuizRemoteDataSource)
class QuizRemoteDataSourceImpl implements QuizRemoteDataSource {
  QuizRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<QuizModel> generateQuiz({
    required String sourceId,
    required String sourceType,
    int numQuestions = 5,
    String difficulty = 'medium',
  }) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        ApiConstants.quiz,
        data: {
          'sourceId': sourceId,
          'sourceType': sourceType,
          'numQuestions': numQuestions,
          'difficulty': difficulty,
        },
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      return QuizModel.fromJson(response);
    } catch (error) {
      throw ServerFailure(
        message: 'Failed to generate quiz',
        cause: error,
      );
    }
  }

  @override
  Future<QuizModel> getQuiz(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${ApiConstants.quiz}/$id',
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );
      return QuizModel.fromJson(response);
    } catch (error) {
      throw ServerFailure(
        message: 'Failed to fetch quiz',
        cause: error,
      );
    }
  }
}

