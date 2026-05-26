import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  Timer? _timer;
  int _currentIndex = 0;
  List<String> _currentUrls = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1);
    _currentUrls = widget.imageUrls;
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer = Timer.periodic(widget.autoPlayDuration, (timer) {
      if (_currentUrls.isEmpty) {
        _timer?.cancel();
        return;
      }
      _currentIndex = (_currentIndex + 1) % _currentUrls.length;

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _onPageChanged(int index) {
    if (_currentUrls.isNotEmpty) {
      setState(() {
        _currentIndex = index % _currentUrls.length;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('banners')
          .doc('current')
          .snapshots(),
      builder: (context, snapshot) {
        List<String> urls = widget.imageUrls;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data();
          if (data != null && data['banner'] != null) {
            final bannerUrl = data['banner'] as String;
            if (bannerUrl.isNotEmpty) {
              urls = [bannerUrl];
            }
          }
        }

        if (urls.isEmpty) {
          return const SizedBox.shrink();
        }

        _currentUrls = urls;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: AspectRatio(
            aspectRatio: widget.aspectRatio,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemCount: urls.length,
              itemBuilder: (context, index) {
                final url = urls[index];
                final isNetwork = url.startsWith('http://') || url.startsWith('https://');

                return GestureDetector(
                  onTap: () => widget.onBannerTap?.call(index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isNetwork)
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Image.asset(
                                  'assets/banner/banner.png',
                                  fit: BoxFit.cover,
                                );
                              },
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  color: Colors.grey[900],
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.pink),
                                    ),
                                  ),
                                );
                              },
                            )
                          else
                            Image.asset(url, fit: BoxFit.cover),
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
      },
    );
  }
}

class BannerUrls {
  static const List<String> liveStreamingBanners = [
    'assets/banner/banner.png',
  ];
}
