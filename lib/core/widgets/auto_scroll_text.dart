import 'package:flutter/material.dart';

// Constant for calculating scroll speed: 150ms per character is a good reading speed.
const int _kMillisecondsPerCharacter = 70;

class AutoScrollText extends StatefulWidget {
  final String text;
  final TextStyle? style;

  // Duration to wait at the start position
  final Duration delayBeforeStart;

  // Duration to wait at the end position before jumping back
  final Duration pauseAfterScroll;

  final TextAlign textAlign;

  // Alignment parameter for positioning the text when it's smaller than the container
  final AlignmentGeometry alignment;

  const AutoScrollText({
    super.key,
    required this.text,
    this.style,
    this.delayBeforeStart = const Duration(milliseconds: 1500),
    this.pauseAfterScroll = const Duration(milliseconds: 1000),
    this.textAlign = TextAlign.start,
    this.alignment = Alignment.center, // Default to center for backward compatibility
  });

  @override
  State<AutoScrollText> createState() => _AutoScrollTextState();
}

class _AutoScrollTextState extends State<AutoScrollText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  bool _shouldScroll = false;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    // We need to wait for the layout to determine if we need to scroll
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  @override
  void didUpdateWidget(covariant AutoScrollText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _isScrolling = false; // Stop current animation
      _scrollController.jumpTo(0); // Reset position
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
    }
  }

  @override
  void dispose() {
    _isScrolling = false;
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (!mounted || !_scrollController.hasClients) return;

    // Check if the max scroll extent is greater than 0
    if (_scrollController.position.maxScrollExtent > 0) {
      setState(() {
        _shouldScroll = true;
      });
      _startScrolling();
    } else {
      setState(() {
        _shouldScroll = false;
      });
    }
  }

  Future<void> _startScrolling() async {
    // Prevent starting if already scrolling or if conditions fail
    if (!mounted || !_shouldScroll || _isScrolling) return;

    _isScrolling = true;

    // Calculate dynamic duration based on text length
    final int dynamicDurationMs = widget.text.length * _kMillisecondsPerCharacter;
    final Duration calculatedDuration = Duration(milliseconds: dynamicDurationMs);

    while (mounted && _shouldScroll) {
      // 1. Wait at the start (to show the first part)
      await Future.delayed(widget.delayBeforeStart);
      if (!mounted || !_shouldScroll) break;

      // 2. Scroll to the end (left to right motion) using the calculated duration
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: calculatedDuration, // Dynamic duration used here
          curve: Curves.linear,
        );
      }
      if (!mounted || !_shouldScroll) break;

      // 2.5. Wait at the end for the configured duration
      await Future.delayed(widget.pauseAfterScroll);
      if (!mounted || !_shouldScroll) break;

      // 3. Jump back to the start position immediately
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
    _isScrolling = false;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.alignment, // Use the alignment parameter
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(widget.text, style: widget.style),
      ),
    );
  }
}