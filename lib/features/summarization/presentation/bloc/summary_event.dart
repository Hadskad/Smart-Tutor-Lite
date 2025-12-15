import 'package:equatable/equatable.dart';

import '../../domain/entities/summary.dart';

abstract class SummaryEvent extends Equatable {
  const SummaryEvent();

  @override
  List<Object?> get props => [];
}

class SummarizeTextEvent extends SummaryEvent {
  const SummarizeTextEvent({
    required this.text,
  });

  final String text;

  @override
  List<Object?> get props => [text];
}

class SummarizePdfEvent extends SummaryEvent {
  const SummarizePdfEvent({
    required this.pdfUrl,
  });

  final String pdfUrl;

  @override
  List<Object?> get props => [pdfUrl];
}

class LoadSummariesEvent extends SummaryEvent {
  const LoadSummariesEvent();
}

class DeleteSummaryEvent extends SummaryEvent {
  const DeleteSummaryEvent(this.summaryId);

  final String summaryId;

  @override
  List<Object?> get props => [summaryId];
}

class UpdateSummaryEvent extends SummaryEvent {
  const UpdateSummaryEvent(this.summary);

  final Summary summary;

  @override
  List<Object?> get props => [summary];
}

