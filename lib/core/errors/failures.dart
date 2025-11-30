import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  const Failure({this.message, this.cause});

  final String? message;
  final Object? cause;

  @override
  List<Object?> get props => [message, cause];
}

class ServerFailure extends Failure {
  const ServerFailure({super.message, super.cause});
}

class CacheFailure extends Failure {
  const CacheFailure({super.message, super.cause});
}

class NetworkFailure extends Failure {
  const NetworkFailure({super.message, super.cause});
}

class LocalFailure extends Failure {
  const LocalFailure({super.message, super.cause});
}
