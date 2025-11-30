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

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Waveform(isActive: isRecording),
            const SizedBox(height: 12),
            _RecordingTimer(startedAt: startedAt),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                backgroundColor:
                    isRecording ? Colors.redAccent : Colors.blueAccent,
              ),
              onPressed: () {
                final bloc = context.read<TranscriptionBloc>();
                bloc.add(
                  isRecording ? const StopRecording() : const StartRecording(),
                );
              },
              icon: Icon(isRecording ? Icons.stop : Icons.mic),
              label: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
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
    return SizedBox(
      height: 60,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final bars = List.generate(12, (index) {
            final heightFactor = widget.isActive ? _controller.value : 0.2;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FractionallySizedBox(
                  heightFactor: heightFactor * (0.5 + (index % 4) * 0.2),
                  alignment: Alignment.bottomCenter,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: widget.isActive
                          ? Colors.redAccent
                          : Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            );
          });
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
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
    return Text(
      widget.startedAt == null ? '00:00' : '$minutes:$seconds',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: widget.startedAt == null ? Colors.grey : Colors.redAccent,
          ),
    );
  }
}
