import 'package:equatable/equatable.dart';

import '../../domain/entities/summary.dart';

abstract class SummaryState extends Equatable {
  const SummaryState({
    this.summaries = const <Summary>[],
  });

  final List<Summary> summaries;

  @override
  List<Object?> get props => [summaries];
}

class SummaryInitial extends SummaryState {
  const SummaryInitial({super.summaries = const []});
}

class SummaryLoading extends SummaryState {
  const SummaryLoading({super.summaries = const []});
}

class SummarySuccess extends SummaryState {
  const SummarySuccess({
    required this.summary,
    required super.summaries,
  });

  final Summary summary;

  @override
  List<Object?> get props => [...super.props, summary];
}

class SummaryError extends SummaryState {
  const SummaryError({
    required this.message,
    super.summaries = const [],
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

class SummaryQueued extends SummaryState {
  const SummaryQueued({
    required this.message,
    super.summaries = const [],
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

class SummaryCancelled extends SummaryState {
  const SummaryCancelled({
    required this.message,
    super.summaries = const [],
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}
