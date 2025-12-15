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
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final item = entry.value;
            final fc = item as Map<String, dynamic>;
            
            // Validate required fields
            if (fc['front'] == null || fc['back'] == null) {
              throw ServerFailure(
                message: 'Flashcard at index $index is missing required fields (front/back)',
              );
            }
            
            final front = fc['front'] as String;
            final back = fc['back'] as String;
            
            if (front.trim().isEmpty || back.trim().isEmpty) {
              throw ServerFailure(
                message: 'Flashcard at index $index has empty front or back',
              );
            }
            
            // Generate ID if not provided, using UUID-like format for uniqueness
            final providedId = fc['id'] as String?;
            final id = providedId?.isNotEmpty == true
                ? providedId!
                : '${sourceId}_fc${index}_${front.hashCode}_${back.hashCode}';
            
            return FlashcardModel(
              id: id,
              front: front,
              back: back,
              sourceId: sourceId,
              sourceType: sourceType,
              createdAt: DateTime.now(),
              metadata: {
                if (providedId != null) 'remoteId': providedId,
                'generatedId': providedId == null,
              },
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

