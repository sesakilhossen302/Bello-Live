import 'package:flutter/material.dart';
import 'dart:async';

class CarouselBanner extends StatefulWidget {
  final List<String> imageUrls;
  final double aspectRatio;
  final Duration autoPlayDuration;
  final Function(int)? onBannerTap;

  const CarouselBanner({
    super.key,
    required this.imageUrls,
    this.aspectRatio = 1600 / 455,
    this.autoPlayDuration = const Duration(seconds: 4),
    this.onBannerTap,
  });

  @override
  State<CarouselBanner> createState() => _CarouselBannerState();
}

class _CarouselBannerState extends State<CarouselBanner> {
  late PageController _pageController;
  late Timer _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(widget.autoPlayDuration, (timer) {
      if (widget.imageUrls.isEmpty) {
        _timer.cancel();
        return;
      }
      _currentIndex = (_currentIndex + 1) % widget.imageUrls.length;

      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index % widget.imageUrls.length;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: widget.imageUrls.length,
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => widget.onBannerTap?.call(index),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  // CHANGE 2: Sharper corners - reduced from 20 to 10
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8)),
                  ],
                ),
                child: ClipRRect(
                  // CHANGE 2: Sharper corners - reduced from 20 to 10
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(widget.imageUrls[index], fit: BoxFit.cover),
                      Container(color: Colors.black.withValues(alpha: 0.1)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class BannerUrls {
  static const List<String> liveStreamingBanners = [
    'assets/banner/banner.png',
  ];
}
