import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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
      final rawValue = event.snapshot.value;
      if (rawValue == null) {
        setState(() {
          _currentVideoId = null;
        });
        _controller?.close();
        _controller = null;
        return;
      }

      String rawString = rawValue.toString();
      bool audioOnly = false;
      bool isPaused = false;
      String videoId = '';
      double startSeconds = 0.0;
      int? timestamp;

      // Check if format is: [PAUSE_][AUDIO_]videoId|timestamp|startSeconds
      if (rawString.contains('|')) {
        final parts = rawString.split('|');
        rawString = parts[0];
        if (parts.length > 1) {
          timestamp = int.tryParse(parts[1]);
        }
        if (parts.length > 2) {
          startSeconds = double.tryParse(parts[2]) ?? 0.0;
        }
      }

      if (rawString.startsWith('PAUSE_')) {
        isPaused = true;
        rawString = rawString.substring(6);
      }

      if (rawString.startsWith('AUDIO_')) {
        audioOnly = true;
        videoId = rawString.substring(6);
      } else {
        videoId = rawString;
      }

      if (videoId.isEmpty) {
        setState(() {
          _currentVideoId = null;
        });
        _controller?.close();
        _controller = null;
        return;
      }

      // Calculate the exact elapsed playback position in seconds for real-time synchronization
      double targetSeconds = startSeconds;
      if (!isPaused && timestamp != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsed = (now - timestamp) / 1000.0;
        if (elapsed > 0) {
          targetSeconds = startSeconds + elapsed;
        }
      }

      if (videoId != _currentVideoId || audioOnly != _isAudioOnly) {
        setState(() {
          _currentVideoId = videoId;
          _isAudioOnly = audioOnly;
        });

        if (_controller == null) {
          _controller = YoutubePlayerController.fromVideoId(
            videoId: videoId,
            autoPlay: !isPaused,
            startSeconds: targetSeconds > 0 ? targetSeconds : null,
            params: const YoutubePlayerParams(
              showControls: false,
              showFullscreenButton: false,
              mute: false,
              loop: false,
              strictRelatedVideos: true,
              pointerEvents: PointerEvents.none,
            ),
          );

          // Additional sync safety net if a new user joins midway through the track
          if (targetSeconds > 1.0) {
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted && _controller != null) {
                _controller!.seekTo(seconds: targetSeconds, allowSeekAhead: true);
                if (!isPaused) {
                  _controller!.playVideo();
                }
              }
            });
          }
        } else {
          _controller!.loadVideoById(
            videoId: videoId,
            startSeconds: targetSeconds > 0 ? targetSeconds : null,
          );
          if (isPaused) {
            _controller!.pauseVideo();
          } else {
            _controller!.playVideo();
          }
        }
      } else {
        // Video ID is the same, just play/pause or seek state changed
        if (_controller != null) {
          if (isPaused) {
            _controller!.pauseVideo();
          } else {
            _controller!.playVideo();
          }

          if (targetSeconds > 0) {
            _controller!.currentTime.then((curr) {
              if ((curr - targetSeconds).abs() > 3.0) {
                _controller!.seekTo(seconds: targetSeconds, allowSeekAhead: true);
              }
            }).catchError((_) {});
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
    const double videoHeight = 129.0; // 16:9 widescreen ratio
    const double headerHeight = 28.0;
    const double playerHeight = videoHeight + headerHeight;
    final double safeTop = mediaQuery.padding.top;
    final double safeBottom = mediaQuery.padding.bottom;

    // Freely draggable across the entire page (from top to bottom and left to right)
    final double minX = 0.0;
    final double maxX = (size.width - playerWidth).clamp(0.0, size.width);
    final double minY = safeTop;
    final double maxY = (size.height - safeBottom - playerHeight).clamp(minY, size.height);

    // Initial position: nicely on the upper right area
    _xOffset ??= (size.width - playerWidth - 10.0).clamp(minX, maxX);
    _yOffset ??= (safeTop + 60.0).clamp(minY, maxY);

    final currentX = _xOffset!.clamp(minX, maxX);
    final currentY = _yOffset!.clamp(minY, maxY);

    return Positioned(
      left: currentX,
      top: currentY,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onPointerMove: (event) {
          setState(() {
            _xOffset = ((_xOffset ?? currentX) + event.delta.dx).clamp(minX, maxX);
            _yOffset = ((_yOffset ?? currentY) + event.delta.dy).clamp(minY, maxY);
          });
        },
        onPointerUp: (_) {
          setState(() {
            _isDragging = false;
          });
        },
        onPointerCancel: (_) {
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
                blurRadius: _isDragging ? 20 : 12,
                spreadRadius: _isDragging ? 3 : 1.5,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: (_isDragging ? Colors.amberAccent : const Color(0xFFFF2D55))
                    .withValues(alpha: _isDragging ? 0.6 : 0.35),
                blurRadius: _isDragging ? 14 : 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top Drag Grip & Control Bar (100% Flutter touch surface)
                Container(
                  height: headerHeight,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: _isDragging
                        ? const Color(0xFFD97706)
                        : const Color(0xFF1E1E2C),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.drag_indicator,
                        color: _isDragging ? Colors.white : Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isDragging ? 'Moving...' : 'Drag anywhere',
                        style: TextStyle(
                          color: _isDragging ? Colors.white : Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
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
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. The Video Player Area
                SizedBox(
                  width: playerWidth,
                  height: videoHeight,
                  child: Stack(
                    children: [
                      IgnorePointer(
                        ignoring: true,
                        child: YoutubePlayer(
                          controller: _controller!,
                          enableFullScreenOnVerticalDrag: false,
                          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.01),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
