import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../data/remote/firebase/live_streaming_services.dart';
import '../../streaming/bottomsheets/play_music_bottomsheet.dart';
import '../../streaming/bottomsheets/game_list_bottomsheet.dart';
import 'invite_pk_bottomsheet.dart';
import 'share_bottomsheet.dart';
import 'package:zego_express_engine/zego_express_engine.dart';

class _ToolItem {
  final String label;
  final IconData icon;
  final Color iconBgColor;

  _ToolItem({required this.label, required this.icon, required this.iconBgColor});
}

final List<_ToolItem> _hostTools = [
  _ToolItem(label: 'Share', icon: Icons.share, iconBgColor: Colors.blue.shade700),
  _ToolItem(label: 'Inbox', icon: CupertinoIcons.mail_solid, iconBgColor: Colors.red.shade700),
  _ToolItem(label: 'Invite PK', icon: Icons.people_outline, iconBgColor: Colors.orange.shade700),
  _ToolItem(label: 'Speaker', icon: CupertinoIcons.speaker_2_fill, iconBgColor: Colors.blue.shade600),
  _ToolItem(label: 'Funny voice', icon: Icons.tag_faces_outlined, iconBgColor: Colors.purple.shade600),
  _ToolItem(label: 'Room skin', icon: Icons.color_lens_outlined, iconBgColor: Colors.teal.shade600),
  _ToolItem(label: 'Notice', icon: Icons.campaign_outlined, iconBgColor: Colors.indigo.shade600),
  _ToolItem(label: 'Play music', icon: Icons.music_note_outlined, iconBgColor: Colors.pink.shade600),
  _ToolItem(label: 'Games', icon: Icons.games_outlined, iconBgColor: Colors.green.shade700),
  _ToolItem(label: 'Random PK', icon: Icons.shuffle, iconBgColor: Colors.deepOrange.shade600),
  _ToolItem(label: 'Block', icon: Icons.block, iconBgColor: Colors.grey.shade700),
  _ToolItem(label: 'Voice Control', icon: Icons.record_voice_over_outlined, iconBgColor: Colors.lightBlue.shade700),
];

final List<_ToolItem> _guestTools = [
  _ToolItem(label: 'Share', icon: Icons.share, iconBgColor: Colors.blue.shade700),
  _ToolItem(label: 'Inbox', icon: CupertinoIcons.mail_solid, iconBgColor: Colors.red.shade700),
  _ToolItem(label: 'Speaker', icon: CupertinoIcons.speaker_2_fill, iconBgColor: Colors.blue.shade600),
  _ToolItem(label: 'Games', icon: Icons.games_outlined, iconBgColor: Colors.green.shade700),
];

class LiveToolsBottomSheet extends StatefulWidget {
  final List<PKInvite> pendingInvites;
  final String currentRoomId;
  final bool isHost;
  final String hostName;
  final MusicPlayerManager musicManager;

  const LiveToolsBottomSheet({
    super.key,
    required this.pendingInvites,
    required this.currentRoomId,
    required this.isHost,
    this.hostName = "Host",
    required this.musicManager,
  });

  @override
  State<LiveToolsBottomSheet> createState() => _LiveToolsBottomSheetState();
}

class _LiveToolsBottomSheetState extends State<LiveToolsBottomSheet> {
  bool _isSpeakerMuted = false;
  ZegoVoiceChangerPreset _currentVoicePreset = ZegoVoiceChangerPreset.None;

  @override
  void initState() {
    super.initState();
    _loadSpeakerState();
  }

  Future<void> _loadSpeakerState() async {
    final isMuted = await ZegoExpressEngine.instance.isSpeakerMuted();
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
                  if (tool.label == 'Invite PK') {
                    onTapLogic = () {
                      Navigator.pop(context);
                      showInvitePKBottomSheet(
                        context,
                        pendingInvites: widget.pendingInvites,
                        currentRoomId: widget.currentRoomId,
                      );
                    };
                  } else if (tool.label == 'Play music') {
                    onTapLogic = () {
                      Navigator.pop(context);
                      showPlayMusicBottomSheet(context, musicManager: widget.musicManager, isHost: widget.isHost);
                    };
                  } else if (tool.label == 'Share') {
                    onTapLogic = () {
                      Navigator.pop(context);
                      showShareBottomSheet(context, widget.currentRoomId, widget.hostName, RoomType.live);
                    };
                  } else if (tool.label == 'Random PK') {
                    onTapLogic = () async {
                      final selectedMinutes = await _showRandomPKConfirmDialog(context);
                      if (selectedMinutes != null) {
                        await _sendRandomPKInvite(context, widget.currentRoomId, selectedMinutes);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    };
                  } else if (tool.label == 'Speaker') {
                    onTapLogic = () async {
                      setState(() {
                        _isSpeakerMuted = !_isSpeakerMuted;
                      });
                      await ZegoExpressEngine.instance.muteSpeaker(_isSpeakerMuted);
                    };
                  } else if (tool.label == 'Funny voice') {
                    onTapLogic = () {
                      _showVoiceChangerBottomSheet(context);
                    };
                  } else if (tool.label == 'Notice') {
                    onTapLogic = () {
                      Navigator.pop(context);
                      _showNoticeDialog(context);
                    };
                  } else if (tool.label == 'Games') {
                    onTapLogic = () {
                      Navigator.pop(context);
                      showGamesListBottomSheet(context);
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
                    iconBgColor: tool.iconBgColor,
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
    required Color iconBgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(10.5)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(shape: BoxShape.circle, color: iconBgColor),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showVoiceChangerBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2d1b2b),
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Text(
                      'Voice Changer',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Divider(color: Colors.white24, height: 1, thickness: 1),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          _buildVoiceOption(context, setModalState, 'None', ZegoVoiceChangerPreset.None),
                          _buildVoiceOption(context, setModalState, 'Male to Child', ZegoVoiceChangerPreset.MenToChild),
                          _buildVoiceOption(
                            context,
                            setModalState,
                            'Male to Female',
                            ZegoVoiceChangerPreset.MenToWomen,
                          ),
                          _buildVoiceOption(
                            context,
                            setModalState,
                            'Female to Child',
                            ZegoVoiceChangerPreset.WomenToChild,
                          ),
                          _buildVoiceOption(
                            context,
                            setModalState,
                            'Female to Male',
                            ZegoVoiceChangerPreset.WomenToMen,
                          ),
                          _buildVoiceOption(context, setModalState, 'Foreigner', ZegoVoiceChangerPreset.Foreigner),
                          _buildVoiceOption(
                            context,
                            setModalState,
                            'Optimus Prime',
                            ZegoVoiceChangerPreset.OptimusPrime,
                          ),
                          _buildVoiceOption(context, setModalState, 'Robot (Android)', ZegoVoiceChangerPreset.Android),
                          _buildVoiceOption(context, setModalState, 'Ethereal', ZegoVoiceChangerPreset.Ethereal),
                          _buildVoiceOption(
                            context,
                            setModalState,
                            'Male Magnetic',
                            ZegoVoiceChangerPreset.MaleMagnetic,
                          ),
                          _buildVoiceOption(context, setModalState, 'Female Fresh', ZegoVoiceChangerPreset.FemaleFresh),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVoiceOption(
    BuildContext context,
    StateSetter setModalState,
    String label,
    ZegoVoiceChangerPreset preset,
  ) {
    final bool isSelected = _currentVoicePreset == preset;

    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.pink : Colors.white,
          fontSize: 16,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.pink, size: 24) : null,
      onTap: () {
        ZegoExpressEngine.instance.setVoiceChangerPreset(preset);
        setState(() {
          _currentVoicePreset = preset;
        });
        setModalState(() {
          _currentVoicePreset = preset;
        });
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Voice changed to: $label'),
            backgroundColor: Colors.pink,
            duration: const Duration(seconds: 2),
          ),
        );
      },
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
                  await LiveStreamService.setRoomNotice(widget.currentRoomId, notice);
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

  Future<int?> _showRandomPKConfirmDialog(BuildContext context) {
    int selectedMinutes = 5;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2d1b2b),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Random PK',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Select PK duration:', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [5, 7, 10].map((minutes) {
                      final isSelected = selectedMinutes == minutes;
                      return GestureDetector(
                        onTap: () => setState(() => selectedMinutes = minutes),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.pink : Colors.transparent,
                            border: Border.all(color: Colors.pink, width: 2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$minutes min',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.pink,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(selectedMinutes),
                  child: const Text('Send', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _sendRandomPKInvite(BuildContext context, String roomId, int minutes) async {
    try {
      await LiveStreamService.sendGlobalRandomPKInvite(roomId, minutes);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Random PK invitation sent! Waiting for response...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.orange),
        );
      }
    }
  }
}

void showLiveToolsBottomSheet(
  BuildContext context, {
  required List<PKInvite> pendingInvites,
  required String currentRoomId,
  required bool isHost,
  String hostName = "Host",
  required MusicPlayerManager musicManager,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    isScrollControlled: true,
    builder: (context) {
      return LiveToolsBottomSheet(
        pendingInvites: pendingInvites,
        currentRoomId: currentRoomId,
        isHost: isHost,
        hostName: hostName,
        musicManager: musicManager,
      );
    },
  );
}
