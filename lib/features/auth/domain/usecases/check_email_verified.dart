import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/auth_repository.dart';

@injectable
class CheckEmailVerified {
  const CheckEmailVerified(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, bool>> call() {
    return _repository.checkEmailVerified();
  }
}
