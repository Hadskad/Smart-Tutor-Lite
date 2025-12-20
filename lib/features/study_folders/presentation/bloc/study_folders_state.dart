import 'package:equatable/equatable.dart';

import '../../domain/entities/study_folder.dart';

abstract class StudyFoldersState extends Equatable {
  const StudyFoldersState({
    this.folders = const <StudyFolder>[],
  });

  final List<StudyFolder> folders;

  @override
  List<Object?> get props => [folders];
}

class StudyFoldersInitial extends StudyFoldersState {
  const StudyFoldersInitial({super.folders = const []});
}

class StudyFoldersLoading extends StudyFoldersState {
  const StudyFoldersLoading({super.folders = const []});
}

class StudyFoldersLoaded extends StudyFoldersState {
  const StudyFoldersLoaded({required super.folders});
}

class StudyFoldersError extends StudyFoldersState {
  const StudyFoldersError({
    required this.message,
    super.folders = const [],
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

