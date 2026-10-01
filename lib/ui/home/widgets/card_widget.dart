import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/utils/view_count.dart';
import '../../../core/widgets/gift_image_widget.dart';
import '../../../data/remote/firebase/profile_services.dart';
import '../../../navigation/routes.dart';
import '../home_page.dart';

class AnimatedStreamerCard extends StatefulWidget {
  final StreamerModel streamer;
  final String? animationFilePath;

  const AnimatedStreamerCard({
    super.key,
    required this.streamer,
    this.animationFilePath,
  });

  @override
  State<AnimatedStreamerCard> createState() => _AnimatedStreamerCardState();
}

class _AnimatedStreamerCardState extends State<AnimatedStreamerCard> {
  List<Widget> _buildCardBadges() {
    final List<Widget> badges = [];
    
    Widget buildMiniBadge(String text, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
        ),
      );
    }

    bool hasRole = false;

    if (widget.streamer.isHost) {
      badges.add(buildMiniBadge('Official host', const Color(0xFF9C27B0)));
      hasRole = true;
    }
    if (widget.streamer.isAgency) {
      badges.add(buildMiniBadge('Agency', const Color(0xFFF44336)));
      hasRole = true;
    }
    if (widget.streamer.isReseller) {
      badges.add(buildMiniBadge('Reseller', const Color(0xFF2196F3)));
      hasRole = true;
    }
    if (widget.streamer.isModerator) {
      badges.add(buildMiniBadge('Moderator', const Color(0xFFE91E63)));
      hasRole = true;
    }

    if (!hasRole) {
      badges.add(buildMiniBadge('General User', const Color(0xFF607D8B)));
    }

    return badges;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        final bool isHost = currentUserId != null && currentUserId == widget.streamer.hostId;
        final bool isModerator = currentUserId != null && await ProfileService.isUserModerator(currentUserId);

        if (widget.streamer.isLocked && !isHost && !isModerator) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Room is lock',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
          return;
        }

        if (!context.mounted) return;
        if (widget.streamer.isLiveStream) {
          context.push(
            Routes.liveStream.path,
            extra: {"roomId": widget.streamer.id, "isHost": false},
          );
        } else if (!widget.streamer.isVideo) {
          context.push(
            Routes.audioRoom.path,
            extra: {"roomId": widget.streamer.id, "isHost": false},
          );
        } else {
          context.push(
            Routes.videoRoom.path,
            extra: {"roomId": widget.streamer.id, "isHost": false},
          );
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Background Image
              CachedNetworkImage(
                imageUrl: widget.streamer.imageUrl ?? "",
                fit: BoxFit.cover,
                errorWidget: (context, url, error) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.grey.shade800,
                          Colors.grey.shade900,
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person,
                        color: Colors.white54,
                        size: 50,
                      ),
                    ),
                  );
                },
              ),

              // 2. SVGA / WebP Overlay Animation (if provided)
              if (widget.animationFilePath != null)
                if (widget.animationFilePath!.endsWith('.svga'))
                  Positioned.fill(
                    child: SVGAEasyPlayer(
                      assetsName: widget.animationFilePath!,
                      fit: BoxFit.cover,
                    ),
                  )
                else if (widget.animationFilePath!.endsWith('.webp'))
                  Positioned.fill(
                    child: Image.asset(
                      widget.animationFilePath!,
                      fit: BoxFit.cover,
                    ),
                  ),

              // 3. Top Section (Play Badge + Audience Count)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top-Left: Gradient Circular Play Badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8A004F), Color(0xFF5A189A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00D2FF),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Icon(
                            widget.streamer.isVideo
                                ? Icons.play_arrow_rounded
                                : Icons.headphones_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),

                    // Top-Right: Magenta Viewers Count Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB0124A).withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.groups_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatViewCount(widget.streamer.viewCount),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 4. Bottom Gradient Overlay for text readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 70,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // Big Lock Icon in the center if room is locked
              if (widget.streamer.isLocked)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.65),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                ),

              // 5. Bottom Section: Gold Ring GIF Avatar Circle + Host Name
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Row(
                  children: [
                    if (widget.streamer.packageBadgeUrl != null && widget.streamer.packageBadgeUrl!.isNotEmpty) ...[
                      // Corner Circle Shape with Orange/Gold Ring Border & Package Badge
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFF9800), width: 3.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: MyImageWidget(
                            imageUrl: widget.streamer.packageBadgeUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Host Name & Tags
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Badges
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2.0),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 2,
                              children: _buildCardBadges(),
                            ),
                          ),
                          Text(
                            widget.streamer.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4, offset: Offset(0, 1)),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
