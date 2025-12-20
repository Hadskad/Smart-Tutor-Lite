import 'package:equatable/equatable.dart';

abstract class StudyFoldersEvent extends Equatable {
  const StudyFoldersEvent();

  @override
  List<Object?> get props => [];
}

class LoadFoldersEvent extends StudyFoldersEvent {
  const LoadFoldersEvent();
}

class CreateFolderEvent extends StudyFoldersEvent {
  const CreateFolderEvent({required this.name});

  final String name;

  @override
  List<Object?> get props => [name];
}

class DeleteFolderEvent extends StudyFoldersEvent {
  const DeleteFolderEvent({required this.folderId});

  final String folderId;

  @override
  List<Object?> get props => [folderId];
}

