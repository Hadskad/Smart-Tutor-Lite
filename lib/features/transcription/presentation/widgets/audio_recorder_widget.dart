import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/transcription_bloc.dart';
import '../bloc/transcription_event.dart';
import '../bloc/transcription_state.dart';

// --- Color Palette (matching home dashboard) ---
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class AudioRecorderWidget extends StatelessWidget {
  const AudioRecorderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TranscriptionBloc, TranscriptionState>(
      builder: (context, state) {
        final isRecording = state is TranscriptionRecording;
        final isStopping = state is TranscriptionStopping;
        final startedAt = isRecording ? state.startedAt : null;
        final approxSizeBytes = isRecording ? state.estimatedSizeBytes : null;
        final isInputTooLow = isRecording ? state.isInputTooLow : false;
        
        // Check queue size - max is 10
        const maxQueueSize = 10;
        final queueLength = state.queue.length;
        final isQueueFull = queueLength >= maxQueueSize;
        final canStartRecording = !isQueueFull || isRecording;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Waveform(isActive: isRecording && !isStopping),
            const SizedBox(height: 20),
            _RecordingTimer(startedAt: startedAt),
            if (isRecording && approxSizeBytes != null) ...[
              const SizedBox(height: 8),
              _RecordingInfoChip(
                icon: Icons.sd_card_rounded,
                label: 'Approx. size: ${_formatBytes(approxSizeBytes)}',
              ),
            ],
            if (isRecording && isInputTooLow) ...[
              const SizedBox(height: 12),
              const _LowInputWarning(),
            ],
            if (!isRecording && isQueueFull) ...[
              const SizedBox(height: 12),
              const _QueueFullWarning(),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecording ? _kAccentCoral : _kAccentBlue,
                  foregroundColor: _kWhite,
                  elevation: isRecording ? 0 : 4,
                  shadowColor: _kAccentBlue.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  disabledBackgroundColor: _kDarkGray.withOpacity(0.5),
                  disabledForegroundColor: _kLightGray,
                ),
                onPressed: isStopping || (state is TranscriptionProcessing && isRecording) || !canStartRecording
                    ? null
                    : () {
                        final bloc = context.read<TranscriptionBloc>();
                        bloc.add(
                          isRecording
                              ? const StopRecording()
                              : const StartRecording(),
                        );
                      },
                icon: isStopping || (state is TranscriptionProcessing && isRecording)
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_kWhite),
                        ),
                      )
                    : Icon(
                        isRecording ? Icons.stop_rounded : Icons.mic_rounded),
                label: Text(
                  isStopping || (state is TranscriptionProcessing && isRecording)
                      ? 'Stopping...'
                      : (!canStartRecording
                          ? 'Queue Full ($queueLength/$maxQueueSize)'
                          : (isRecording
                              ? 'Stop Note Taking'
                              : 'Start Note Taking')),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _RecordingTip(),
          ],
        );
      },
    );
  }

  static String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '0 KB';
    }
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    double size = bytes.toDouble();
    var unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final precision = unitIndex <= 1 ? 0 : 1;
    return '${size.toStringAsFixed(precision)} ${units[unitIndex]}';
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
                          ? _kAccentBlue.withOpacity(0.8)
                          : _kDarkGray.withOpacity(0.3),
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
    final color = isRecording ? _kAccentCoral : _kLightGray;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
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
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontFeatures: [const FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingInfoChip extends StatelessWidget {
  const _RecordingInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kDarkGray.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _kLightGray),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _kLightGray,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LowInputWarning extends StatelessWidget {
  const _LowInputWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kAccentCoral.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccentCoral.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_mute_rounded, color: _kAccentCoral),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'We are hearing very little audio. Move closer or uncover the mic.',
              style: const TextStyle(
                color: _kAccentCoral,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueFullWarning extends StatelessWidget {
  const _QueueFullWarning();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kAccentCoral.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccentCoral.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.queue_music_rounded, color: _kAccentCoral),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You have 10 pending transcriptions. Please wait or cancel some items.',
              style: const TextStyle(
                color: _kAccentCoral,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingTip extends StatelessWidget {
  const _RecordingTip();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lightbulb_outline_rounded,
          size: 18,
          color: _kAccentBlue,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Tip: Keep the microphone unobstructed—do not cover the speaker while recording.',
            style: const TextStyle(
              color: _kLightGray,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
