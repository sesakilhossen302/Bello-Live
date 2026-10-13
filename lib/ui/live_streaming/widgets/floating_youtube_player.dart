import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../data/remote/firebase/live_streaming_services.dart';

class FloatingYoutubePlayer extends StatefulWidget {
  final String roomId;
  final bool isHost;

  const FloatingYoutubePlayer({super.key, required this.roomId, this.isHost = false});

  @override
  State<FloatingYoutubePlayer> createState() => _FloatingYoutubePlayerState();
}

class _FloatingYoutubePlayerState extends State<FloatingYoutubePlayer> {
  YoutubePlayerController? _controller;
  String? _currentVideoId;
  bool _isAudioOnly = false;
  double? _xOffset;
  double? _yOffset;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _listenToRoomMusic();
  }

  void _listenToRoomMusic() {
    LiveStreamService.getRoomMusicStream(widget.roomId).listen((event) {
      if (!mounted) return;
      String? rawVideoId = event.snapshot.value as String?;
      bool audioOnly = false;
      bool isPaused = false;
      String? videoId;
      
      if (rawVideoId != null) {
        if (rawVideoId.startsWith('PAUSE_')) {
          isPaused = true;
          rawVideoId = rawVideoId.substring(6);
        }
        
        if (rawVideoId.startsWith('AUDIO_')) {
          audioOnly = true;
          videoId = rawVideoId.substring(6);
        } else {
          videoId = rawVideoId;
        }
      }
      
      if (videoId != _currentVideoId || audioOnly != _isAudioOnly) {
        setState(() {
          _currentVideoId = videoId;
          _isAudioOnly = audioOnly;
        });
        
        if (videoId != null) {
          if (_controller == null) {
            _controller = YoutubePlayerController.fromVideoId(
              videoId: videoId,
              autoPlay: !isPaused,
              params: const YoutubePlayerParams(
                showControls: false,
                showFullscreenButton: false,
                mute: false,
                loop: false,
                strictRelatedVideos: true,
              ),
            );
          } else {
            _controller!.loadVideoById(videoId: videoId);
            if (isPaused) {
              _controller!.pauseVideo();
            }
          }
        } else {
          _controller?.close();
          _controller = null;
        }
      } else {
        // Video ID is the same, just play/pause state changed
        if (videoId != null && _controller != null) {
          if (isPaused) {
            _controller!.pauseVideo();
          } else {
            _controller!.playVideo();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentVideoId == null || _controller == null) {
      return const SizedBox.shrink();
    }

    if (_isAudioOnly) {
      return Positioned(
        left: -100, // Hide off-screen
        top: -100,
        child: SizedBox(
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0.01,
            child: YoutubePlayer(controller: _controller!),
          ),
        ),
      );
    }

    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    const double playerWidth = 230.0;
    const double playerHeight = 129.0; // 16:9 widescreen ratio
    final double safeTop = mediaQuery.padding.top;
    final double safeBottom = mediaQuery.padding.bottom;

    // Freely draggable across the entire page (from top to bottom and left to right)
    final double minX = 0.0;
    final double maxX = (size.width - playerWidth).clamp(0.0, size.width);
    final double minY = safeTop;
    final double maxY = (size.height - safeBottom - playerHeight).clamp(minY, size.height);

    // Initial position: nicely on the upper right area
    _xOffset ??= (size.width - playerWidth - 10.0).clamp(minX, maxX);
    _yOffset ??= (safeTop + 80.0).clamp(minY, maxY);

    final currentX = _xOffset!.clamp(minX, maxX);
    final currentY = _yOffset!.clamp(minY, maxY);

    return Positioned(
      left: currentX,
      top: currentY,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Draggable Player Widget
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {
              setState(() {
                _isDragging = true;
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _xOffset = ((_xOffset ?? currentX) + details.delta.dx).clamp(minX, maxX);
                _yOffset = ((_yOffset ?? currentY) + details.delta.dy).clamp(minY, maxY);
              });
            },
            onPanEnd: (_) {
              setState(() {
                _isDragging = false;
              });
            },
            onPanCancel: () {
              setState(() {
                _isDragging = false;
              });
            },
            child: Container(
              width: playerWidth,
              height: playerHeight,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isDragging ? Colors.amberAccent : const Color(0xFFFF2D55),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: _isDragging ? 18 : 12,
                    spreadRadius: _isDragging ? 3 : 1.5,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: (_isDragging ? Colors.amberAccent : const Color(0xFFFF2D55))
                        .withValues(alpha: _isDragging ? 0.55 : 0.35),
                    blurRadius: _isDragging ? 12 : 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // YouTube Player: IgnorePointer prevents Android WebView from intercepting drag gestures
                    IgnorePointer(
                      ignoring: true,
                      child: SizedBox(
                        width: playerWidth,
                        height: playerHeight,
                        child: YoutubePlayer(
                          controller: _controller!,
                        ),
                      ),
                    ),

                    // Active gesture target overlay with alpha > 0 to guarantee Flutter hit test capture
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.01),
                      ),
                    ),

                    // Subtle drag handle icon at top-left
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.open_with,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Close button: separated from drag detector so tap always triggers immediately
          Positioned(
            top: -10,
            right: -10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (widget.isHost) {
                  LiveStreamService.setRoomMusic(widget.roomId, null);
                }
                setState(() {
                  _currentVideoId = null;
                  _controller?.pauseVideo();
                });
              },
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.white, width: 1.5),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
