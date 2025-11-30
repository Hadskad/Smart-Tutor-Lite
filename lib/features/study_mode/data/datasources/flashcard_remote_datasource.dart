import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../models/flashcard_model.dart';

abstract class FlashcardRemoteDataSource {
  Future<List<FlashcardModel>> generateFlashcards({
    required String sourceId,
    required String sourceType,
    int? numFlashcards,
  });
}

@LazySingleton(as: FlashcardRemoteDataSource)
class FlashcardRemoteDataSourceImpl implements FlashcardRemoteDataSource {
  const FlashcardRemoteDataSourceImpl(this.apiClient);

  final ApiClient apiClient;

  @override
  Future<List<FlashcardModel>> generateFlashcards({
    required String sourceId,
    required String sourceType,
    int? numFlashcards,
  }) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        ApiConstants.flashcards,
        data: {
          'sourceId': sourceId,
          'sourceType': sourceType,
          if (numFlashcards != null) 'numFlashcards': numFlashcards,
        },
        parser: (data) => Map<String, dynamic>.from(data as Map),
      );

      final flashcardsData = response['flashcards'] as List<dynamic>;
      final flashcards = flashcardsData
          .map((item) {
            final fc = item as Map<String, dynamic>;
            return FlashcardModel(
              id: fc['id'] as String? ?? '${sourceId}_${fc['front']}'.hashCode.toString(),
              front: fc['front'] as String,
              back: fc['back'] as String,
              sourceId: sourceId,
              sourceType: sourceType,
              createdAt: DateTime.now(),
              metadata: {'remoteId': fc['id']},
            );
          })
          .toList();

      return flashcards;
    } on DioException catch (e) {
      throw ServerFailure(message: 'Failed to generate flashcards: ${e.message}');
    } catch (e) {
      throw ServerFailure(message: 'Unexpected error: ${e.toString()}');
    }
  }
}

