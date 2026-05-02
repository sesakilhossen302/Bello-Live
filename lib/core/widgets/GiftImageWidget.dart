import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svga/flutter_svga.dart';

class GiftImageWidget extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool isFullScreenAnimation;
  final VoidCallback? onAnimationComplete;
  final Duration? displayDuration; // How long to show after loading

  static const String _baseUrl = 'https://pub-a84b75c9c456460f9aadb5a9bc90b348.r2.dev/';

  const GiftImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
    this.isFullScreenAnimation = false,
    this.onAnimationComplete,
    this.displayDuration = const Duration(seconds: 10),
  });

  @override
  State<GiftImageWidget> createState() => _GiftImageWidgetState();
}

class _GiftImageWidgetState extends State<GiftImageWidget> {
  bool _isLoaded = false;
  bool _hasStartedTimer = false;
  Future<void>? _loadFuture;

  String get _fullImageUrl {
    if (widget.imageUrl.startsWith('http://') || widget.imageUrl.startsWith('https://')) {
      return widget.imageUrl;
    }
    return '${GiftImageWidget._baseUrl}${widget.imageUrl}';
  }

  bool get _isSvgaFile => _fullImageUrl.contains("svga");

  @override
  void initState() {
    super.initState();
    // Start loading immediately for fullscreen animations
    if (widget.isFullScreenAnimation && _isSvgaFile) {
      _loadFuture = _loadSvga();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSvgaFile) {
      if (widget.isFullScreenAnimation) {
        // For fullscreen: load first, then show
        return FutureBuilder(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (!_isLoaded) {
              // Don't show anything while loading
              return const SizedBox.shrink();
            }

            // Animation is loaded and showing - start timer ONCE
            if (!_hasStartedTimer && widget.onAnimationComplete != null) {
              _hasStartedTimer = true;
              Future.delayed(widget.displayDuration!, widget.onAnimationComplete!);
            }

            return SVGAEasyPlayer(resUrl: _fullImageUrl, fit: widget.fit);
          },
        );
      } else {
        // For regular (non-fullscreen): show immediately
        return SVGAEasyPlayer(resUrl: _fullImageUrl, fit: widget.fit);
      }
    }

    return CachedNetworkImage(
      imageUrl: _fullImageUrl,
      fit: widget.fit,
      placeholder: (context, url) =>
          widget.placeholder ??
          Center(child: CircularProgressIndicator(color: Colors.pink.withValues(alpha: 0.5), strokeWidth: 1.5)),
      errorWidget: (context, url, error) =>
          widget.errorWidget ?? const Icon(Icons.card_giftcard, color: Colors.white54, size: 24),
    );
  }

  Future<void> _loadSvga() async {
    if (_isLoaded) return;

    // Preload the SVGA file
    try {
      await SVGAParser.shared.decodeFromURL(_fullImageUrl);
      if (mounted) {
        setState(() {
          _isLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Error loading SVGA: $e');
      if (mounted) {
        setState(() {
          _isLoaded = true; // Show anyway to prevent infinite loading
        });
      }
    }
  }
}
