import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svga/flutter_svga.dart';

class MyImageWidget extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool isFullScreenAnimation;
  final VoidCallback? onAnimationComplete;
  final Duration? displayDuration; // How long to show after loading
  final bool playAudio; // Controls SVGA sound

  static const String _baseUrl = 'https://pub-a84b75c9c456460f9aadb5a9bc90b348.r2.dev/';

  const MyImageWidget({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.contain, // Changed default to contain
    this.placeholder,
    this.errorWidget,
    this.isFullScreenAnimation = false,
    this.onAnimationComplete,
    this.displayDuration = const Duration(seconds: 10),
    this.playAudio = false, // Default to muted
  });

  @override
  State<MyImageWidget> createState() => _MyImageWidgetState();
}

class _MyImageWidgetState extends State<MyImageWidget> with SingleTickerProviderStateMixin {
  bool _isLoaded = false;
  bool _hasStartedTimer = false;

  MovieEntity? _videoItem;
  SVGAAnimationController? _animationController;

  String get _fullImageUrl {
    if (widget.imageUrl.startsWith('http://') || widget.imageUrl.startsWith('https://')) {
      return widget.imageUrl;
    }
    return '${MyImageWidget._baseUrl}${widget.imageUrl}';
  }

  bool get _isSvgaFile => _fullImageUrl.toLowerCase().endsWith('.svga');

  @override
  void initState() {
    super.initState();
    if (_isSvgaFile) {
      _animationController = SVGAAnimationController(vsync: this);
      _loadSvga();
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  Future<void> _loadSvga() async {
    try {
      final videoItem = await SVGAParser.shared.decodeFromURL(_fullImageUrl);

      if (mounted) {
        // Strip out the audio if we want it muted
        if (!widget.playAudio) {
          videoItem.audios.clear();
        }

        setState(() {
          _videoItem = videoItem;
          _isLoaded = true;
        });

        _animationController?.videoItem = videoItem;
        _animationController?.repeat();

        // Handle full screen timer logic
        if (widget.isFullScreenAnimation && !_hasStartedTimer && widget.onAnimationComplete != null) {
          _hasStartedTimer = true;
          Future.delayed(widget.displayDuration!, widget.onAnimationComplete!);
        }
      }
    } catch (e) {
      debugPrint('Error loading SVGA: $e');
      if (mounted) {
        setState(() => _isLoaded = true); // Show placeholder/fallback
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSvgaFile) {
      if (!_isLoaded || _videoItem == null) {
        // Don't show anything while loading fullscreen, otherwise show placeholder
        return widget.isFullScreenAnimation
            ? const SizedBox.shrink()
            : (widget.placeholder ??
                  Center(child: CircularProgressIndicator(color: Colors.pink.withValues(alpha: 0.5), strokeWidth: 1.5)));
      }
      return SVGAImage(_animationController!, fit: widget.fit);
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
}
