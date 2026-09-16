import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../data/remote/firebase/live_streaming_services.dart';

class FloatingYoutubePlayer extends StatefulWidget {
  final String roomId;
  final bool isHost;

  const FloatingYoutubePlayer({Key? key, required this.roomId, this.isHost = false}) : super(key: key);

  @override
  State<FloatingYoutubePlayer> createState() => _FloatingYoutubePlayerState();
}

class _FloatingYoutubePlayerState extends State<FloatingYoutubePlayer> {
  YoutubePlayerController? _controller;
  String? _currentVideoId;
  bool _isAudioOnly = false;
  double? _xOffset;
  double _yOffset = 100;

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

    // Make initial position above the emojis on the right side
    _xOffset ??= MediaQuery.of(context).size.width - 180; 
    
    // In live_room_page, the emojis are usually in the bottom right.
    // Bottom area has a text field, then emojis above it.
    // We'll set the initial yOffset higher up based on user request.
    double screenHeight = MediaQuery.of(context).size.height;
    if (_yOffset == 100) {
      _yOffset = screenHeight - 450; // moved higher up
    }

    return Positioned(
      left: _xOffset!,
      top: _yOffset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 160,
            height: 90, // 16:9 aspect ratio, smaller size
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
              border: Border.all(color: Colors.pink, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  // The actual YouTube player
                  AbsorbPointer(
                    child: YoutubePlayer(
                      controller: _controller!,
                    ),
                  ),
                  // The drag interceptor: MUST be on top of the YoutubePlayer in the Stack
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (details) {
                        setState(() {
                          _xOffset = (_xOffset ?? 0) + details.delta.dx;
                          _yOffset += details.delta.dy;
                          
                          // Allow dragging anywhere on the screen
                          if (_xOffset! < -100) _xOffset = -100;
                          if (_yOffset < 0) _yOffset = 0;
                          if (_xOffset! > MediaQuery.of(context).size.width - 50) {
                            _xOffset = MediaQuery.of(context).size.width - 50;
                          }
                          if (_yOffset > MediaQuery.of(context).size.height - 50) {
                            _yOffset = MediaQuery.of(context).size.height - 50;
                          }
                        });
                      },
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.01),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Close button positioned OUTSIDE the clipped container so it's guaranteed to be visible
          Positioned(
            top: -10,
            right: -10,
            child: GestureDetector(
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
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: Colors.white, width: 1.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
