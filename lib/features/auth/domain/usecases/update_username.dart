import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

@injectable
class UpdateUsername {
  UpdateUsername(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AppUser>> call({
    required String firstName,
    required String lastName,
  }) {
    return _repository.updateUsername(
      firstName: firstName,
      lastName: lastName,
    );
  }
}
