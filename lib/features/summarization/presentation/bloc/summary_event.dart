import 'package:equatable/equatable.dart';

abstract class SummaryEvent extends Equatable {
  const SummaryEvent();

  @override
  List<Object?> get props => [];
}

class SummarizeTextEvent extends SummaryEvent {
  const SummarizeTextEvent({
    required this.text,
    this.maxLength = 200,
  });

  final String text;
  final int maxLength;

  @override
  List<Object?> get props => [text, maxLength];
}

class SummarizePdfEvent extends SummaryEvent {
  const SummarizePdfEvent({
    required this.pdfUrl,
    this.maxLength = 200,
  });

  final String pdfUrl;
  final int maxLength;

  @override
  List<Object?> get props => [pdfUrl, maxLength];
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

