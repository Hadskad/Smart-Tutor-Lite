import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/logger.dart';
import '../../../../native_bridge/performance_bridge.dart';
import '../../domain/entities/summary.dart';
import '../../domain/repositories/summary_repository.dart';
import '../../domain/usecases/summarize_pdf.dart';
import '../../domain/usecases/summarize_text.dart';
import 'summary_event.dart';
import 'summary_state.dart';

@injectable
class SummaryBloc extends Bloc<SummaryEvent, SummaryState> {
  SummaryBloc(
    this._summarizeText,
    this._summarizePdf,
    this._repository,
    this._performanceBridge,
    this._logger,
  ) : super(const SummaryInitial()) {
    on<SummarizeTextEvent>(_onSummarizeText);
    on<SummarizePdfEvent>(_onSummarizePdf);
    on<LoadSummariesEvent>(_onLoadSummaries);
    on<DeleteSummaryEvent>(_onDeleteSummary);
    on<UpdateSummaryEvent>(_onUpdateSummary);
    on<CancelSummarizationEvent>(_onCancelSummarization);
  }

  final SummarizeText _summarizeText;
  final SummarizePdf _summarizePdf;
  final SummaryRepository _repository;
  final PerformanceBridge _performanceBridge;
  final AppLogger _logger;
  final List<Summary> _summaries = <Summary>[];

  /// Flag to track if a cancellation has been requested
  bool _isCancellationRequested = false;

  void _onCancelSummarization(
    CancelSummarizationEvent event,
    Emitter<SummaryState> emit,
  ) {
    _isCancellationRequested = true;
    emit(
      SummaryCancelled(
        message: 'Summarization cancelled',
        summaries: List.unmodifiable(_summaries),
      ),
    );
  }

  Future<void> _onSummarizeText(
    SummarizeTextEvent event,
    Emitter<SummaryState> emit,
  ) async {
    _isCancellationRequested = false;
    emit(SummaryLoading(summaries: List.unmodifiable(_summaries)));

    const segmentId = 'summarize_text';
    await _performanceBridge.startSegment(segmentId);
    try {
      final result = await _summarizeText(
        text: event.text,
      );

      // Check if cancelled during operation
      // Ensure cancelled state is emitted to avoid UI stuck in loading state
      if (_isCancellationRequested) {
        if (state is! SummaryCancelled) {
          emit(
            SummaryCancelled(
              message: 'Summarization cancelled',
              summaries: List.unmodifiable(_summaries),
            ),
          );
        }
        return;
      }

      result.fold(
        (failure) {
          final message = failure.message ?? 'Failed to summarize text';
          // Check if request was queued
          if (message.toLowerCase().contains('queued')) {
            emit(
              SummaryQueued(
                message: message,
                summaries: List.unmodifiable(_summaries),
              ),
            );
          } else {
            emit(
              SummaryError(
                message: message,
                summaries: List.unmodifiable(_summaries),
              ),
            );
          }
        },
        (summary) {
          _summaries.insert(0, summary);
          emit(
            SummarySuccess(
              summary: summary,
              summaries: List.unmodifiable(_summaries),
            ),
          );
        },
      );
    } finally {
      await _logMetrics(segmentId);
    }
  }

  Future<void> _onSummarizePdf(
    SummarizePdfEvent event,
    Emitter<SummaryState> emit,
  ) async {
    _isCancellationRequested = false;
    emit(SummaryLoading(summaries: List.unmodifiable(_summaries)));

    const segmentId = 'summarize_pdf';
    await _performanceBridge.startSegment(segmentId);
    try {
      final result = await _summarizePdf(
        pdfUrl: event.pdfUrl,
      );

      // Check if cancelled during operation
      // Ensure cancelled state is emitted to avoid UI stuck in loading state
      if (_isCancellationRequested) {
        if (state is! SummaryCancelled) {
          emit(
            SummaryCancelled(
              message: 'Summarization cancelled',
              summaries: List.unmodifiable(_summaries),
            ),
          );
        }
        return;
      }

      result.fold(
        (failure) {
          final message = failure.message ?? 'Failed to summarize PDF';
          // Check if request was queued
          if (message.contains('queued') || message.contains('Queued')) {
            emit(
              SummaryQueued(
                message: message,
                summaries: List.unmodifiable(_summaries),
              ),
            );
          } else {
            emit(
              SummaryError(
                message: message,
                summaries: List.unmodifiable(_summaries),
              ),
            );
          }
        },
        (summary) {
          _summaries.insert(0, summary);
          emit(
            SummarySuccess(
              summary: summary,
              summaries: List.unmodifiable(_summaries),
            ),
          );
        },
      );
    } finally {
      await _logMetrics(segmentId);
    }
  }

  Future<void> _onLoadSummaries(
    LoadSummariesEvent event,
    Emitter<SummaryState> emit,
  ) async {
    emit(SummaryLoading(summaries: List.unmodifiable(_summaries)));

    final result = await _repository.getAllSummaries();

    result.fold(
      (failure) => emit(
        SummaryError(
          message: failure.message ?? 'Failed to load summaries',
          summaries: List.unmodifiable(_summaries),
        ),
      ),
      (summaries) {
        _summaries.clear();
        _summaries.addAll(summaries);
        emit(SummaryInitial(summaries: List.unmodifiable(_summaries)));
      },
    );
  }

  Future<void> _onDeleteSummary(
    DeleteSummaryEvent event,
    Emitter<SummaryState> emit,
  ) async {
    final result = await _repository.deleteSummary(event.summaryId);

    result.fold(
      (failure) => emit(
        SummaryError(
          message: failure.message ?? 'Failed to delete summary',
          summaries: List.unmodifiable(_summaries),
        ),
      ),
      (_) {
        _summaries.removeWhere((s) => s.id == event.summaryId);
        emit(SummaryInitial(summaries: List.unmodifiable(_summaries)));
      },
    );
  }

  Future<void> _onUpdateSummary(
    UpdateSummaryEvent event,
    Emitter<SummaryState> emit,
  ) async {
    emit(SummaryLoading(summaries: List.unmodifiable(_summaries)));
    final result = await _repository.updateSummary(event.summary);

    result.fold(
      (failure) => emit(
        SummaryError(
          message: failure.message ?? 'Failed to update summary',
          summaries: List.unmodifiable(_summaries),
        ),
      ),
      (updatedSummary) {
        final index = _summaries.indexWhere((s) => s.id == updatedSummary.id);
        if (index != -1) {
          _summaries[index] = updatedSummary;
        }
        emit(SummaryInitial(summaries: List.unmodifiable(_summaries)));
      },
    );
  }

  Future<void> _logMetrics(String segmentId) async {
    final metrics = await _performanceBridge.endSegment(segmentId);
    _logger.info(
      'performance_segment_completed',
      {
        'segment': segmentId,
        'durationMs': metrics.durationMs,
        'batteryLevel': metrics.batteryLevel,
        'cpuUsage': metrics.cpuUsage,
        'memoryUsageMb': metrics.memoryUsageMb,
        if (metrics.notes != null) 'notes': metrics.notes,
      },
    );
  }
}
