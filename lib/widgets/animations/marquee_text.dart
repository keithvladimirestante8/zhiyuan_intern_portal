import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

/// A widget that displays text with a smooth marquee (scrolling) animation.
/// Useful for displaying long text in constrained spaces.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final double? velocity;
  final Duration? startAfter;
  final Duration? pauseAfter;
  final Duration? scrollDuration;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.left,
    this.textDirection = TextDirection.ltr,
    this.velocity,
    this.startAfter,
    this.pauseAfter,
    this.scrollDuration,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late ScrollController _scrollController;
  Timer? _scrollTimer;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _startMarquee();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startMarquee() {
    final startAfter = widget.startAfter ?? const Duration(seconds: 2);
    final pauseAfter = widget.pauseAfter ?? const Duration(seconds: 2);
    final scrollDuration = widget.scrollDuration ?? const Duration(seconds: 3);

    // Wait before starting the first scroll
    Future.delayed(startAfter, () {
      if (!mounted) return;
      _scrollToEnd(scrollDuration, pauseAfter);
    });
  }

  void _scrollToEnd(Duration duration, Duration pauseAfter) {
    if (!mounted) return;

    _isScrolling = true;
    _scrollController
        .animateTo(
          _scrollController.position.maxScrollExtent,
          duration: duration,
          curve: Curves.easeInOut,
        )
        .then((_) {
      if (!mounted) return;
      _isScrolling = false;

      // Pause at the end, then scroll back to start
      Future.delayed(pauseAfter, () {
        if (!mounted) return;
        _scrollToStart(duration, pauseAfter);
      });
    });
  }

  void _scrollToStart(Duration duration, Duration pauseAfter) {
    if (!mounted) return;

    _isScrolling = true;
    _scrollController
        .animateTo(
          0.0,
          duration: duration,
          curve: Curves.easeInOut,
        )
        .then((_) {
      if (!mounted) return;
      _isScrolling = false;

      // Pause at the start, then scroll to end again (loop)
      Future.delayed(pauseAfter, () {
        if (!mounted) return;
        _scrollToEnd(duration, pauseAfter);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Text(
        widget.text,
        style: widget.style,
        textAlign: widget.textAlign,
        textDirection: widget.textDirection,
      ),
    );
  }
}
