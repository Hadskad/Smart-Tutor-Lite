import 'dart:math';
import 'package:flutter/material.dart';

// Color Palette matching Home Dashboard
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class FlipCardWidget extends StatefulWidget {
  const FlipCardWidget({
    super.key,
    required this.front,
    required this.back,
    this.isFlipped = false,
    this.onTap,
    this.width,
    this.height,
    this.frontBackgroundColor,
    this.backBackgroundColor,
    this.textColor,
    this.elevation = 4.0,
    this.borderRadius = 16.0,
    this.animationDuration = const Duration(milliseconds: 600),
  });

  final Widget front;
  final Widget back;
  final bool isFlipped;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Color? frontBackgroundColor;
  final Color? backBackgroundColor;
  final Color? textColor;
  final double elevation;
  final double borderRadius;
  final Duration animationDuration;

  @override
  State<FlipCardWidget> createState() => _FlipCardWidgetState();
}

class _FlipCardWidgetState extends State<FlipCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Sync initial animation state with widget.isFlipped
    if (widget.isFlipped) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(FlipCardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync animation with prop changes
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Just notify parent - parent controls the state
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final frontColor = widget.frontBackgroundColor ?? _kCardColor;
    final backColor = widget.backBackgroundColor ?? _kCardColor;
    final textColor = widget.textColor ?? _kWhite;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final isBack = angle > pi / 2;

          return Transform(
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            alignment: Alignment.center,
            child: isBack
                ? Transform(
                    transform: Matrix4.identity()..rotateY(pi),
                    alignment: Alignment.center,
                    child: _buildCard(
                      widget.back,
                      backColor,
                      textColor,
                      isBack: true,
                    ),
                  )
                : _buildCard(
                    widget.front,
                    frontColor,
                    textColor,
                    isBack: false,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildCard(
    Widget content,
    Color backgroundColor,
    Color textColor, {
    required bool isBack,
  }) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: widget.elevation * 2,
            offset: Offset(0, widget.elevation),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Stack(
          children: [
            // Content
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: DefaultTextStyle(
                  style: TextStyle(color: textColor),
                  child: content,
                ),
              ),
            ),
            // Indicator badge
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isBack
                      ? _kAccentBlue.withOpacity(0.2)
                      : _kAccentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isBack ? 'Answer' : 'Question',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _kAccentBlue,
                  ),
                ),
              ),
            ),
            // Tap hint at bottom
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,
                        size: 14,
                        color: textColor.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Tap to flip',
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
