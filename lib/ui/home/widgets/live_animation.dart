import 'dart:math';
import 'package:flutter/material.dart';

class LiveWaveWidget extends StatefulWidget {
  const LiveWaveWidget({super.key});

  @override
  _LiveWaveWidgetState createState() => _LiveWaveWidgetState();
}

class _LiveWaveWidgetState extends State<LiveWaveWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _randomPhases = [];
  final int _numberOfBars = 5;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000), // Keep the original duration for "speed"
    )..repeat();

    final random = Random();
    for (int i = 0; i < _numberOfBars; i++) {
      _randomPhases.add(random.nextDouble() * 2 * pi);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        const int steps = 20;
        double steppedValue = (_controller.value * steps).floorToDouble() / steps;

        return CustomPaint(
          size: const Size(18, 10),
          painter: PulsingWavePainter(
            animationValue: steppedValue,
            randomPhases: _randomPhases,
          ),
        );
      },
    );
  }
}

class PulsingWavePainter extends CustomPainter {
  final double animationValue;
  final int numberOfBars = 5;
  final List<double> randomPhases;

  PulsingWavePainter({required this.animationValue, required this.randomPhases});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    final double barGap = size.width / (numberOfBars - 1);
    final double maxBarHeight = size.height;

    for (int i = 0; i < numberOfBars; i++) {
      double waveHeight = (sin(animationValue * 2 * pi + randomPhases[i]) + 1) / 2;
      double barHeight = maxBarHeight * waveHeight * 0.8 + 2;

      final double x = i * barGap;
      final double startY = (size.height - barHeight) / 2;
      final double endY = startY + barHeight;

      canvas.drawLine(Offset(x, startY), Offset(x, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant PulsingWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
