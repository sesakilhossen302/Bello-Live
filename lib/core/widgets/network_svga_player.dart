import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

class NetworkSVGAPlayer extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final VoidCallback? onFinished;

  const NetworkSVGAPlayer({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.onFinished,
  });

  @override
  State<NetworkSVGAPlayer> createState() => _NetworkSVGAPlayerState();
}

class _NetworkSVGAPlayerState extends State<NetworkSVGAPlayer> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  MovieEntity? _videoItem;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _loadSvga();
  }

  Future<void> _loadSvga() async {
    try {
      final videoItem = await SVGAParser.shared.decodeFromURL(widget.imageUrl);
      if (mounted) {
        videoItem.audios.clear();
        setState(() => _videoItem = videoItem);
        _controller?.videoItem = videoItem;
        
        _controller?.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            widget.onFinished?.call();
          }
        });
        
        _controller?.forward();
      }
    } catch (e) {
      debugPrint('Error loading network SVGA: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoItem == null || _controller == null) {
      return const SizedBox.shrink(); // or a loading indicator
    }
    return SVGAImage(
      _controller!,
      fit: widget.fit,
    );
  }
}
