import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/transcription_bloc.dart';
import '../bloc/transcription_event.dart';
import '../bloc/transcription_state.dart';

class AudioRecorderWidget extends StatelessWidget {
  const AudioRecorderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionBloc, TranscriptionState>(
      builder: (context, state) {
        final isRecording = state is TranscriptionRecording;
        final startedAt = isRecording ? state.startedAt : null;
        final primaryColor = Theme.of(context).colorScheme.primary;
        final errorColor = Theme.of(context).colorScheme.error;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Waveform(isActive: isRecording),
            const SizedBox(height: 20),
            _RecordingTimer(startedAt: startedAt),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecording ? errorColor : primaryColor,
                  foregroundColor: Colors.white,
                  elevation: isRecording ? 0 : 4,
                  shadowColor: primaryColor.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  final bloc = context.read<TranscriptionBloc>();
                  bloc.add(
                    isRecording
                        ? const StopRecording()
                        : const StartRecording(),
                  );
                },
                icon:
                    Icon(isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                label: Text(
                  isRecording ? 'Stop Recording' : 'Start Recording',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Waveform extends StatefulWidget {
  const _Waveform({required this.isActive});

  final bool isActive;

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.2,
      upperBound: 1,
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Waveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 60,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final bars = List.generate(12, (index) {
            final heightFactor = widget.isActive ? _controller.value : 0.2;
            // Add some randomness or variation based on index for a more organic look
            final variation = 0.5 + (index % 4) * 0.2;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FractionallySizedBox(
                  heightFactor: heightFactor * variation,
                  alignment: Alignment.center,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.isActive
                          ? primaryColor.withValues(alpha: 0.8)
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            );
          });
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: bars,
          );
        },
      ),
    );
  }
}

class _RecordingTimer extends StatefulWidget {
  const _RecordingTimer({this.startedAt});

  final DateTime? startedAt;

  @override
  State<_RecordingTimer> createState() => _RecordingTimerState();
}

class _RecordingTimerState extends State<_RecordingTimer> {
  StreamSubscription<int>? _ticker;
  int _seconds = 0;

  @override
  void didUpdateWidget(covariant _RecordingTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startedAt == null) {
      _ticker?.cancel();
      if (_seconds != 0) {
        setState(() => _seconds = 0);
      }
    } else if (oldWidget.startedAt != widget.startedAt) {
      _ticker?.cancel();
      _ticker = Stream<int>.periodic(
        const Duration(seconds: 1),
        (index) => index,
      ).listen((_) {
        final startedAt = widget.startedAt!;
        final elapsed = DateTime.now().difference(startedAt);
        setState(() => _seconds = elapsed.inSeconds);
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = Duration(seconds: _seconds);
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    final isRecording = widget.startedAt != null;
    final color = isRecording
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isRecording) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            widget.startedAt == null ? '00:00' : '$minutes:$seconds',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
