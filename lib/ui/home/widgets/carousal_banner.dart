import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/services/home_banner_cache_service.dart';

class CarouselBanner extends StatefulWidget {
  /// Pass an empty list — banners are loaded from cache/Firestore only.
  final List<String> imageUrls;
  final double aspectRatio;
  final Duration autoPlayDuration;
  final Function(int)? onBannerTap;

  const CarouselBanner({
    super.key,
    this.imageUrls = const [],
    this.aspectRatio = 1600 / 455,
    this.autoPlayDuration = const Duration(seconds: 4),
    this.onBannerTap,
  });

  @override
  State<CarouselBanner> createState() => _CarouselBannerState();
}

class _CarouselBannerState extends State<CarouselBanner> {
  static const int _kInitialPage = 5000;
  late PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;
  List<String> _currentUrls = [];

  @override
  void initState() {
    super.initState();
    // Instantly load from memory cache on frame 0
    _currentUrls = List.from(
      widget.imageUrls.isNotEmpty
          ? widget.imageUrls
          : HomeBannerCacheService.bannerUrls,
    );

    _pageController = PageController(
      initialPage: _kInitialPage,
      viewportFraction: 1,
    );

    HomeBannerCacheService.bannerNotifier.addListener(_onBannersChanged);

    if (_currentUrls.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_pageController.hasClients && _currentUrls.length > 1) {
          final int startPage = _kInitialPage - (_kInitialPage % _currentUrls.length);
          _pageController.jumpToPage(startPage);
        }
        _startAutoPlay();
      });
    }
  }

  void _onBannersChanged() {
    final newUrls = widget.imageUrls.isNotEmpty
        ? widget.imageUrls
        : HomeBannerCacheService.bannerUrls;
    if (newUrls.isNotEmpty && !listEquals(_currentUrls, newUrls)) {
      _updateUrls(newUrls);
    }
  }

  void _startAutoPlay() {
    _timer?.cancel();
    if (_currentUrls.length <= 1) return;
    _timer = Timer.periodic(widget.autoPlayDuration, (timer) {
      if (_currentUrls.isEmpty || !mounted || !_pageController.hasClients) return;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _resetAutoPlay() {
    _timer?.cancel();
    _startAutoPlay();
  }

  void _onPageChanged(int index) {
    if (_currentUrls.isNotEmpty) {
      final realIndex = index % _currentUrls.length;
      if (_currentIndex != realIndex) {
        setState(() {
          _currentIndex = realIndex;
        });
      }
    }
  }

  void _updateUrls(List<String> urls) {
    if (!listEquals(_currentUrls, urls)) {
      final bool firstLoad = _currentUrls.isEmpty;
      setState(() {
        _currentUrls = List.from(urls);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (firstLoad && _pageController.hasClients && urls.length > 1) {
          final int startPage = _kInitialPage - (_kInitialPage % urls.length);
          _pageController.jumpToPage(startPage);
        }
        _startAutoPlay();
      });
    }
  }

  @override
  void dispose() {
    HomeBannerCacheService.bannerNotifier.removeListener(_onBannersChanged);
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUrls.isEmpty) {
      return _BannerSkeleton(aspectRatio: widget.aspectRatio);
    }

    final bool isInfinite = _currentUrls.length > 1;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification) {
                  _timer?.cancel();
                } else if (notification is ScrollEndNotification) {
                  _resetAutoPlay();
                }
                return false;
              },
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: isInfinite ? 100000 : 1,
                itemBuilder: (context, index) {
                  final realIndex = index % _currentUrls.length;
                  final url = _currentUrls[realIndex];
                  return GestureDetector(
                    onTap: () => widget.onBannerTap?.call(realIndex),
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
                            CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              fadeInDuration: Duration.zero,
                              fadeOutDuration: Duration.zero,
                              placeholder: (context, url) => Container(
                                color: const Color(0xFF1E293B),
                              ),
                              errorWidget: (context, error, stackTrace) => Container(
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                            Container(
                              color: Colors.black.withValues(alpha: 0.08),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Dot indicators
            if (_currentUrls.length > 1)
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_currentUrls.length, (i) {
                    final active = i == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton for the whole banner slot ────────────────────────────────────────
class _BannerSkeleton extends StatelessWidget {
  final double aspectRatio;
  const _BannerSkeleton({required this.aspectRatio});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: _BannerSkeletonBox(),
        ),
      ),
    );
  }
}

// ─── Animated shimmer box ──────────────────────────────────────────────────────
class _BannerSkeletonBox extends StatefulWidget {
  @override
  State<_BannerSkeletonBox> createState() => _BannerSkeletonBoxState();
}

class _BannerSkeletonBoxState extends State<_BannerSkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey[850]!,
                Colors.grey[700]!.withValues(alpha: _anim.value),
                Colors.grey[850]!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ─── Static constant (empty — banners come from Firestore only) ────────────────
class BannerUrls {
  static const List<String> liveStreamingBanners = [];
}
