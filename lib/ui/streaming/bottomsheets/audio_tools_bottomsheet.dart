import 'package:picture_live/ui/streaming/bottomsheets/room_skin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:picture_live/ui/streaming/bottomsheets/play_music_bottomsheet.dart';
import 'package:picture_live/core/services/livekit_service.dart';

import '../../../data/remote/firebase/room_services.dart';
import '../../live_streaming/bottomsheets/share_bottomsheet.dart';
import '../blocked_users_page.dart';

import 'rocket_config_bottomsheet.dart';

class _ToolItem {
  final String label;
  final IconData icon;
  final List<Color> gradientColors;

  _ToolItem({required this.label, required this.icon, required this.gradientColors});
}

final List<_ToolItem> _hostTools = [
  _ToolItem(label: 'Share', icon: Icons.ios_share_rounded, gradientColors: [const Color(0xFF3DA5FE), const Color(0xFF5682FE)]),
  _ToolItem(label: 'Inbox', icon: CupertinoIcons.envelope_fill, gradientColors: [const Color(0xFFFF5252), const Color(0xFFFF1744)]),
  _ToolItem(label: 'Speaker', icon: CupertinoIcons.speaker_2_fill, gradientColors: [const Color(0xFF00E5FF), const Color(0xFF00B0FF)]),
  _ToolItem(label: 'Coin Bag', icon: Icons.shopping_bag_rounded, gradientColors: [const Color(0xFFD500F9), const Color(0xFF651FFF)]),
  _ToolItem(label: 'Room skin', icon: Icons.palette_rounded, gradientColors: [const Color(0xFF1DE9B6), const Color(0xFF00BFA5)]),
  _ToolItem(label: 'Notice', icon: Icons.campaign_rounded, gradientColors: [const Color(0xFF5A5EF6), const Color(0xFF3D5AFE)]),
  _ToolItem(label: 'Play music', icon: CupertinoIcons.music_note_2, gradientColors: [const Color(0xFFFF4081), const Color(0xFFF50057)]),
  _ToolItem(label: 'Block', icon: CupertinoIcons.nosign, gradientColors: [const Color(0xFF9E9E9E), const Color(0xFF616161)]),
];

final List<_ToolItem> _guestTools = [
  _ToolItem(label: 'Share', icon: Icons.ios_share_rounded, gradientColors: [const Color(0xFF3DA5FE), const Color(0xFF5682FE)]),
  _ToolItem(label: 'Inbox', icon: CupertinoIcons.envelope_fill, gradientColors: [const Color(0xFFFF5252), const Color(0xFFFF1744)]),
  _ToolItem(label: 'Speaker', icon: CupertinoIcons.speaker_2_fill, gradientColors: [const Color(0xFF00E5FF), const Color(0xFF00B0FF)]),
  _ToolItem(label: 'Coin Bag', icon: Icons.shopping_bag_rounded, gradientColors: [const Color(0xFFD500F9), const Color(0xFF651FFF)]),
];

class AudioToolsBottomSheet extends StatefulWidget {
  final String currentRoomId;
  final bool isHost;
  final String hostName;
  final String hostId;
  final MusicPlayerManager musicManager;

  const AudioToolsBottomSheet({
    super.key,
    required this.currentRoomId,
    required this.isHost,
    required this.musicManager,
    required this.hostId,
    this.hostName = "Host",
  });

  @override
  State<AudioToolsBottomSheet> createState() => _AudioToolsBottomSheetState();
}
class _AudioToolsBottomSheetState extends State<AudioToolsBottomSheet> {
  bool _isSpeakerMuted = false;

  @override
  void initState() {
    super.initState();
    _loadSpeakerState();
  }

  Future<void> _loadSpeakerState() async {
    final isMuted = LiveKitService.instance.isSpeakerMuted;
    if (mounted) {
      setState(() {
        _isSpeakerMuted = isMuted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Text(
              'Tools',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(color: Colors.white24, height: 1, thickness: 1),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.isHost ? _hostTools.length : _guestTools.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 16.0,
                  mainAxisSpacing: 16.0,
                  childAspectRatio: 0.8,
                ),
                itemBuilder: (context, index) {
                  final tool = widget.isHost ? _hostTools[index] : _guestTools[index];

                  VoidCallback onTapLogic;
                  if (tool.label == 'Share') {
                    onTapLogic = () {
                      Navigator.pop(context);
                      showShareBottomSheet(context, widget.currentRoomId, widget.hostName, RoomType.audio);
                    };
                  } else if (tool.label == 'Play music') {
                    onTapLogic = () {
                      Navigator.pop(context);
                      showPlayMusicBottomSheet(context, musicManager: widget.musicManager, isHost: widget.isHost);
                    };
                  } else if (tool.label == 'Speaker') {
                    onTapLogic = () async {
                      setState(() {
                        _isSpeakerMuted = !_isSpeakerMuted;
                      });
                      await LiveKitService.instance.setSpeakerMuted(_isSpeakerMuted);
                    };
                  } else if (tool.label == 'Coin Bag') {
                    onTapLogic = () {
                      Navigator.pop(context);
                      showRocketConfigBottomSheet(
                        context,
                        roomId: widget.currentRoomId,
                        hostId: widget.hostId,
                        isAudioRoom: true,
                      );
                    };
                  } else if (tool.label == 'Notice') {
                    onTapLogic = () {
                      Navigator.pop(context);
                      _showNoticeDialog(context);
                    };
                  } else if (tool.label == 'Room skin') {
                    onTapLogic = () {
                      Navigator.pop(context); // Close tools sheet first
                      showRoomSkinSideSheet(context, widget.currentRoomId);
                    };
                  } else if (tool.label == 'Block') {
                    onTapLogic = () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlockedUsersPage(
                            roomId: widget.currentRoomId,
                            roomType: 'audio',
                          ),
                        ),
                      );
                    };
                  } else {
                    onTapLogic = () {
                      debugPrint("Tapped on ${tool.label}");
                      Navigator.pop(context);
                    };
                  }

                  // Update icon for speaker button based on state
                  IconData displayIcon = tool.icon;
                  if (tool.label == 'Speaker') {
                    displayIcon = _isSpeakerMuted ? CupertinoIcons.speaker_slash_fill : CupertinoIcons.speaker_2_fill;
                  }

                  return _buildToolButton(
                    icon: displayIcon,
                    label: tool.label,
                    gradientColors: tool.gradientColors,
                    onTap: onTapLogic,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: gradientColors.last.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }


  void _showNoticeDialog(BuildContext context) {
    final noticeController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2d1b2b),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Set Room Notice', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: noticeController,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter a notice for the room...",
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
              focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.pink)),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Set Notice', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                final notice = noticeController.text.trim();
                Navigator.of(dialogContext).pop();

                try {
                  await RoomService.setRoomNotice(widget.currentRoomId, notice);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notice has been set.'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error setting notice: $e')));
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}

void showAudioToolsBottomSheet(
  BuildContext context, {
  required String currentRoomId,
  required bool isHost,
  required MusicPlayerManager musicManager,
  required String hostId,
  String hostName = "Host",
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2d1b2b), Color(0xFF1a0a0a)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
          ),
        ),
        child: AudioToolsBottomSheet(
          currentRoomId: currentRoomId,
          isHost: isHost,
          musicManager: musicManager,
          hostId: hostId,
          hostName: hostName,
        ),
      );
    },
  );
}
