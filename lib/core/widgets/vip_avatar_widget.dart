import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/vip_service.dart';
import 'active_frame_widget.dart';

/// Renders a user's avatar with VIP or VVIP frame badge if applicable.
/// Falls back to ActiveFrameWidget / custom frame if not VIP/VVIP.
class VipAvatarWidget extends StatefulWidget {
  final String userId;
  final String? userPicture;
  final double avatarSize;
  final String? directVipType; // If already known synchronously (e.g. from RTDB)
  final VoidCallback? onTap;

  const VipAvatarWidget({
    super.key,
    required this.userId,
    this.userPicture,
    this.avatarSize = 34.0,
    this.directVipType,
    this.onTap,
  });

  @override
  State<VipAvatarWidget> createState() => _VipAvatarWidgetState();
}

class _VipAvatarWidgetState extends State<VipAvatarWidget> {
  String? _vipType;

  @override
  void initState() {
    super.initState();
    _resolveVip();
  }

  @override
  void didUpdateWidget(covariant VipAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.directVipType != widget.directVipType) {
      _resolveVip();
    }
  }

  void _resolveVip() {
    if (widget.directVipType != null && widget.directVipType!.isNotEmpty) {
      _vipType = widget.directVipType!.toLowerCase();
      VipService.setVipType(widget.userId, _vipType);
      return;
    }

    final syncVip = VipService.getVipTypeSync(widget.userId);
    if (syncVip != null) {
      _vipType = syncVip;
      return;
    }

    VipService.getVipType(widget.userId).then((resolved) {
      if (mounted && resolved != null) {
        setState(() {
          _vipType = resolved;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isVvip = _vipType == 'vvip';
    final bool isVip = _vipType == 'vip';
    final bool hasVipBadge = isVvip || isVip;

    // Frame scale factor so the circular cutout matches the avatar size perfectly
    final double frameSize = widget.avatarSize * 1.88;

    Widget avatarCore = Container(
      width: widget.avatarSize,
      height: widget.avatarSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: hasVipBadge ? const Color(0xFFFFD700) : Colors.white24,
          width: hasVipBadge ? 1.5 : 1.0,
        ),
      ),
      child: ClipOval(
        child: widget.userPicture != null && widget.userPicture!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: widget.userPicture!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.white,
                ),
                errorWidget: (context, url, error) => const Icon(
                  Icons.person,
                  size: 16,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.person,
                size: 16,
                color: Colors.white,
              ),
      ),
    );

    Widget content = SizedBox(
      width: hasVipBadge ? frameSize : widget.avatarSize,
      height: hasVipBadge ? frameSize : widget.avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Base circular avatar
          avatarCore,

          // VIP / VVIP Golden Crest Frame
          if (isVvip)
            Positioned(
              width: frameSize,
              height: frameSize,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/VVIP PNG.png',
                  width: frameSize,
                  height: frameSize,
                  fit: BoxFit.contain,
                ),
              ),
            )
          else if (isVip)
            Positioned(
              width: frameSize,
              height: frameSize,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/VIP PNG.png',
                  width: frameSize,
                  height: frameSize,
                  fit: BoxFit.contain,
                ),
              ),
            )
          else
            // Fallback to active store frame if not VIP/VVIP
            Positioned(
              width: widget.avatarSize * 1.3,
              height: widget.avatarSize * 1.3,
              child: IgnorePointer(
                child: ActiveFrameWidget(
                  userId: widget.userId,
                  size: widget.avatarSize * 1.3,
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: content,
      );
    }

    return content;
  }
}
