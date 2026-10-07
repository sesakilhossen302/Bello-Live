import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/cubits/app_cubit.dart';
import '../../navigation/routes.dart';
import '../../navigation/my_router.dart';
import '../../data/remote/firebase/live_streaming_services.dart';
import '../../data/remote/firebase/room_services.dart';
import '../../core/services/streaming_service.dart';

class FloatingMinimizedRoom extends StatefulWidget {
  const FloatingMinimizedRoom({super.key});

  @override
  State<FloatingMinimizedRoom> createState() => _FloatingMinimizedRoomState();
}

class _FloatingMinimizedRoomState extends State<FloatingMinimizedRoom>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;
  Offset _offset = const Offset(-1, -1); // Initial position flag

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    if (_offset.dx == -1) {
      // Set initial position to bottom right
      _offset = Offset(screenSize.width - 130, screenSize.height - 200);
    }

    return BlocBuilder<AppCubit, AppState>(
      builder: (context, state) {
        final data = state.minimizedRoom;
        if (data == null) return const SizedBox.shrink();

        return Positioned(
          left: _offset.dx,
          top: _offset.dy,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _offset += details.delta;
                  // Clamp to screen boundaries
                  double x = _offset.dx.clamp(10, screenSize.width - 120);
                  double y = _offset.dy.clamp(50, screenSize.height - 150);
                  _offset = Offset(x, y);
                });
              },
              onTap: () {
                // Re-open the room
                if (data.isAudioRoom) {
                  MyRouter.router.push(Routes.audioRoom.path, extra: {
                    'roomId': data.roomId,
                    'isHost': data.isHost,
                  });
                } else {
                  MyRouter.router.push(Routes.liveStream.path, extra: {
                    'roomId': data.roomId,
                    'isHost': data.isHost,
                  });
                }
                context.read<AppCubit>().closeMinimizedRoom();
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.pink.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Rotating Profile
                    RotationTransition(
                      turns: _rotationController,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.pink, width: 2),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: data.hostPicture,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                            errorWidget: (context, url, error) => const Icon(Icons.person, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Close Button
                    GestureDetector(
                      onTap: () async {
                        // End room logic completely
                        try {
                          if (data.isAudioRoom) {
                            if (data.isHost) {
                              await RoomService.deleteRoom(data.roomId);
                            } else {
                              await RoomService.leaveRoom(data.roomId);
                            }
                          } else {
                            if (data.isHost) {
                              await LiveStreamService.deleteRoom(data.roomId);
                            } else {
                              await LiveStreamService.leaveRoom(data.roomId);
                            }
                          }
                        } catch (e) {
                          debugPrint('Error closing room from floating widget: $e');
                        }
                        try {
                          await StreamingService.instance.disconnect();
                        } catch (_) {}
                        try {
                          await WakelockPlus.disable();
                        } catch (_) {}
                        if (context.mounted) {
                          context.read<AppCubit>().closeMinimizedRoom();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

