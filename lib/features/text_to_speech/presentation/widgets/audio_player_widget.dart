import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

// Color palette
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

/// Enhanced audio player widget with seek bar, duration, and speed controls
class AudioPlayerWidget extends StatefulWidget {
  const AudioPlayerWidget({
    super.key,
    required this.audioUrl,
    this.localPath,
    this.onPlaybackComplete,
  });

  /// Remote URL of the audio file
  final String audioUrl;

  /// Local file path for offline playback (if available)
  final String? localPath;

  /// Callback when playback completes
  final VoidCallback? onPlaybackComplete;

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isLoading = false;
  String? _errorMessage;

  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completeSubscription;

  static const List<double> _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  @override
  void didUpdateWidget(AudioPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.audioUrl != widget.audioUrl ||
        oldWidget.localPath != widget.localPath) {
      _resetPlayer();
    }
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _completeSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _initPlayer() async {
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen(
      (state) {
        if (mounted) {
          setState(() => _playerState = state);
        }
      },
    );

    _durationSubscription = _audioPlayer.onDurationChanged.listen(
      (duration) {
        if (mounted) {
          setState(() => _duration = duration);
        }
      },
    );

    _positionSubscription = _audioPlayer.onPositionChanged.listen(
      (position) {
        if (mounted) {
          setState(() => _position = position);
        }
      },
    );

    _completeSubscription = _audioPlayer.onPlayerComplete.listen(
      (_) {
        if (mounted) {
          setState(() {
            _position = Duration.zero;
            _playerState = PlayerState.stopped;
          });
          widget.onPlaybackComplete?.call();
        }
      },
    );
  }

  Future<void> _resetPlayer() async {
    await _audioPlayer.stop();
    setState(() {
      _duration = Duration.zero;
      _position = Duration.zero;
      _playerState = PlayerState.stopped;
      _errorMessage = null;
    });
  }

  Future<void> _togglePlayPause() async {
    try {
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });

      if (_playerState == PlayerState.playing) {
        await _audioPlayer.pause();
      } else {
        // Prefer local path over remote URL for offline support
        final source = widget.localPath != null
            ? DeviceFileSource(widget.localPath!)
            : UrlSource(widget.audioUrl);

        if (_playerState == PlayerState.paused) {
          await _audioPlayer.resume();
        } else {
          await _audioPlayer.play(source);
          await _audioPlayer.setPlaybackRate(_playbackSpeed);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to play audio';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _stop() async {
    await _audioPlayer.stop();
    setState(() {
      _position = Duration.zero;
    });
  }

  Future<void> _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> _setSpeed(double speed) async {
    await _audioPlayer.setPlaybackRate(speed);
    setState(() => _playbackSpeed = speed);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCardColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccentBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error message
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: _kAccentCoral, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: _kAccentCoral, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Progress bar
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(color: _kLightGray, fontSize: 12),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: _kAccentBlue,
                    inactiveTrackColor: _kDarkGray,
                    thumbColor: _kAccentBlue,
                    overlayColor: _kAccentBlue.withOpacity(0.2),
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                    value: _position.inMilliseconds.toDouble().clamp(
                          0,
                          _duration.inMilliseconds.toDouble().clamp(1, double.infinity),
                        ),
                    onChanged: (value) {
                      _seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(color: _kLightGray, fontSize: 12),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Speed control
              _buildSpeedControl(),

              // Play controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Skip backward 10s
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: _kLightGray),
                    iconSize: 28,
                    onPressed: () {
                      final newPosition = _position - const Duration(seconds: 10);
                      _seek(newPosition.isNegative ? Duration.zero : newPosition);
                    },
                  ),

                  // Play/Pause button
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kAccentBlue,
                    ),
                    child: IconButton(
                      icon: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _kWhite,
                              ),
                            )
                          : Icon(
                              _playerState == PlayerState.playing
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: _kWhite,
                            ),
                      iconSize: 32,
                      onPressed: _isLoading ? null : _togglePlayPause,
                    ),
                  ),

                  // Skip forward 10s
                  IconButton(
                    icon: const Icon(Icons.forward_10, color: _kLightGray),
                    iconSize: 28,
                    onPressed: () {
                      final newPosition = _position + const Duration(seconds: 10);
                      if (newPosition < _duration) {
                        _seek(newPosition);
                      }
                    },
                  ),
                ],
              ),

              // Stop button
              IconButton(
                icon: const Icon(Icons.stop, color: _kAccentCoral),
                iconSize: 24,
                onPressed: _playerState == PlayerState.stopped ? null : _stop,
              ),
            ],
          ),

          // Offline indicator
          if (widget.localPath != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.offline_pin,
                    color: _kAccentBlue.withOpacity(0.7),
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Available offline',
                    style: TextStyle(
                      color: _kLightGray.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSpeedControl() {
    return PopupMenuButton<double>(
      initialValue: _playbackSpeed,
      onSelected: _setSpeed,
      tooltip: 'Playback speed',
      color: _kCardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kDarkGray),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_playbackSpeed}x',
              style: const TextStyle(color: _kLightGray, fontSize: 12),
            ),
            const Icon(Icons.arrow_drop_down, color: _kLightGray, size: 16),
          ],
        ),
      ),
      itemBuilder: (context) => _speedOptions
          .map(
            (speed) => PopupMenuItem<double>(
              value: speed,
              child: Text(
                '${speed}x',
                style: TextStyle(
                  color: speed == _playbackSpeed ? _kAccentBlue : _kWhite,
                  fontWeight:
                      speed == _playbackSpeed ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

