import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/summary.dart';

abstract class SummaryRepository {
  /// Summarize text content
  Future<Either<Failure, Summary>> summarizeText({
    required String text,
    int maxLength = 200,
  });

  /// Summarize PDF from URL or file path
  Future<Either<Failure, Summary>> summarizePdf({
    required String pdfUrl,
    int maxLength = 200,
  });

  /// Get summary by ID
  Future<Either<Failure, Summary>> getSummary(String id);

  /// Get all summaries
  Future<Either<Failure, List<Summary>>> getAllSummaries();

  /// Delete summary
  Future<Either<Failure, Unit>> deleteSummary(String id);

  /// Process all pending queued summaries (internal use by sync service)
  Future<void> processQueuedSummaries();
}
