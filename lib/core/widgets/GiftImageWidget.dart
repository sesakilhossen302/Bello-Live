import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svga/flutter_svga.dart';

class _SvgaTask {
  final String url;
  final Completer<Uint8List> completer;
  _SvgaTask(this.url, this.completer);
}

class _SvgaLoader {
  // Store raw binary bytes in RAM so new controller instances get fresh MovieEntity objects
  static final Map<String, Uint8List> _byteCache = {};
  static final Map<String, Future<Uint8List>> _inFlight = {};
  static final List<_SvgaTask> _queue = [];
  static int _activeWorkers = 0;
  static const int _maxWorkers = 4; // Allow 4 concurrent workers for fast loading

  static Future<Uint8List> load(String url) {
    if (_byteCache.containsKey(url)) {
      return Future.value(_byteCache[url]!);
    }
    if (_inFlight.containsKey(url)) {
      return _inFlight[url]!;
    }

    final completer = Completer<Uint8List>();
    _inFlight[url] = completer.future;

    _queue.add(_SvgaTask(url, completer));
    _pump();

    return completer.future;
  }

  static void _pump() async {
    if (_activeWorkers >= _maxWorkers || _queue.isEmpty) return;

    _activeWorkers++;
    final task = _queue.removeAt(0);

    try {
      Uint8List bytes;
      if (task.url.startsWith('assets/')) {
        final byteData = await rootBundle.load(task.url);
        bytes = byteData.buffer.asUint8List();
      } else {
        // Lightning-fast Disk & RAM Caching using DefaultCacheManager
        final file = await DefaultCacheManager().getSingleFile(task.url);
        bytes = await file.readAsBytes();
      }

      _byteCache[task.url] = bytes;
      task.completer.complete(bytes);
    } catch (e) {
      task.completer.completeError(e);
    } finally {
      _inFlight.remove(task.url);
      _activeWorkers--;
      _pump();
    }
  }
}

class GiftImageWidget extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool isFullScreenAnimation;
  final VoidCallback? onAnimationComplete;
  final Duration? displayDuration;

  static const String _baseUrl =
      'https://pub-a84b75c9c456460f9aadb5a9bc90b348.r2.dev/';

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
  bool _hasStartedTimer = false;

  String get _fullImageUrl {
    if (widget.imageUrl.startsWith('http://') ||
        widget.imageUrl.startsWith('https://') ||
        widget.imageUrl.startsWith('assets/')) {
      return widget.imageUrl;
    }
    return '${GiftImageWidget._baseUrl}${widget.imageUrl}';
  }

  bool get _isSvgaFile => _fullImageUrl.contains("svga");

  @override
  Widget build(BuildContext context) {
    if (_isSvgaFile) {
      if (widget.isFullScreenAnimation) {
        if (!_hasStartedTimer && widget.onAnimationComplete != null) {
          _hasStartedTimer = true;
          Future.delayed(
            widget.displayDuration ?? const Duration(seconds: 10),
            () {
              if (mounted && widget.onAnimationComplete != null) {
                widget.onAnimationComplete!();
              }
            },
          );
        }

        return _SvgaBufferPlayer(
          url: _fullImageUrl,
          fit: widget.fit,
          isFullScreen: true,
          playAudio: true,
        );
      } else {
        return _SvgaBufferPlayer(
          url: _fullImageUrl,
          fit: widget.fit,
          isFullScreen: false,
          playAudio: false,
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: _fullImageUrl,
      fit: widget.fit,
      memCacheWidth: widget.isFullScreenAnimation ? null : 250,
      placeholder: (context, url) =>
          widget.placeholder ??
          Center(
            child: CircularProgressIndicator(
              color: Colors.pink.withValues(alpha: 0.5),
              strokeWidth: 1.5,
            ),
          ),
      errorWidget: (context, url, error) =>
          widget.errorWidget ??
          const Icon(Icons.card_giftcard, color: Colors.white54, size: 24),
    );
  }
}

class _SvgaBufferPlayer extends StatefulWidget {
  final String url;
  final BoxFit fit;
  final bool isFullScreen;
  final bool playAudio;

  const _SvgaBufferPlayer({
    required this.url,
    required this.fit,
    this.isFullScreen = false,
    this.playAudio = false,
  });

  @override
  State<_SvgaBufferPlayer> createState() => _SvgaBufferPlayerState();
}

class _SvgaBufferPlayerState extends State<_SvgaBufferPlayer> with SingleTickerProviderStateMixin {
  SVGAAnimationController? _controller;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _controller = SVGAAnimationController(vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await _SvgaLoader.load(widget.url);
      if (_isDisposed) return;
      
      final videoItem = await SVGAParser.shared.decodeFromBuffer(bytes);
      if (_isDisposed) return;

      if (mounted && _controller != null) {
        if (!widget.playAudio) {
          try {
            videoItem.audios.clear(); // Safely clear all audio tracks for grid thumbnails
          } catch (_) {}
        }
        _controller!.videoItem = videoItem;
        setState(() {});

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller != null && !_isDisposed) {
            _controller!.reset();
            _controller!.repeat(); // Keep the animation playing continuously
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading SVGA from buffer: $e");
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller?.videoItem == null) {
      if (widget.isFullScreen) {
        return const SizedBox.shrink();
      }
      return Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.pink.withValues(alpha: 0.5),
            strokeWidth: 1.5,
          ),
        ),
      );
    }
    return SVGAImage(_controller!, fit: widget.fit);
  }
}
