import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

@injectable
class UpdateProfilePhoto {
  UpdateProfilePhoto(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, AppUser>> call({
    required String imagePath,
  }) {
    return _repository.updateProfilePhoto(imagePath: imagePath);
  }
}
