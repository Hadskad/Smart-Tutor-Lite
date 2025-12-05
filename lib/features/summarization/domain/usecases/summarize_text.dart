import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/summary.dart';
import '../repositories/summary_repository.dart';

@lazySingleton
class SummarizeText {
  SummarizeText(this._repository);

  final SummaryRepository _repository;

  Future<Either<Failure, Summary>> call({
    required String text,
  }) async {
    return _repository.summarizeText(text: text);
  }
}
