import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../../../../data/remote/firebase/profile_services.dart';
import '../../../../data/remote/firebase/room_services.dart';
import '../../../../data/remote/firebase/live_streaming_services.dart';

class RocketConfigBottomSheet extends StatefulWidget {
  final String roomId;
  final String hostId;
  final bool isAudioRoom;

  const RocketConfigBottomSheet({
    super.key,
    required this.roomId,
    required this.hostId,
    required this.isAudioRoom,
  });

  @override
  State<RocketConfigBottomSheet> createState() => _RocketConfigBottomSheetState();
}

class _RocketConfigBottomSheetState extends State<RocketConfigBottomSheet> {
  bool _isSending = false;
  bool _isCustomConfig = false;

  final TextEditingController _coinController = TextEditingController(text: "10000");
  final TextEditingController _durationController = TextEditingController(text: "5");

  List<Map<dynamic, dynamic>> _roomAudience = [];
  Set<String> _selectedAudienceIds = {};

  @override
  void initState() {
    super.initState();
    _fetchRoomAudience();
  }

  Future<void> _fetchRoomAudience() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('room_participants/${widget.roomId}').get();
      if (snapshot.exists && snapshot.value is Map) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);
        final List<Map<dynamic, dynamic>> list = [];
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;

        data.forEach((key, value) {
          if (value is Map) {
            final userId = (value['userId'] ?? key) as String;
            if (userId != currentUserId) {
              list.add({
                'userId': userId,
                'userName': value['userName'] ?? 'User',
                'userPicture': value['userPicture'],
              });
            }
          }
        });

        if (mounted) {
          setState(() {
            _roomAudience = list;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching room audience: $e");
    }
  }

  @override
  void dispose() {
    _coinController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _sendRocket() async {
    FocusManager.instance.primaryFocus?.unfocus();

    final int coins = _isCustomConfig ? (int.tryParse(_coinController.text.trim()) ?? 10000) : 10000;
    final int duration = _isCustomConfig ? (int.tryParse(_durationController.text.trim()) ?? 5) : 5;

    if (coins <= 0 || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid positive values"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // Determine recipients for 50% distribution
      List<String> recipients;
      if (_selectedAudienceIds.isNotEmpty) {
        recipients = _selectedAudienceIds.toList();
      } else if (_roomAudience.isNotEmpty) {
        recipients = _roomAudience.take(10).map((u) => u['userId'] as String).toList();
      } else if (widget.hostId.isNotEmpty && widget.hostId != FirebaseAuth.instance.currentUser?.uid) {
        recipients = [widget.hostId];
      } else {
        recipients = [FirebaseAuth.instance.currentUser?.uid ?? ''];
      }

      final int personsCount = recipients.length;

      // 50% vanish, 50% distributed
      await ProfileService.sendRocketGift(
        totalCoins: coins,
        recipientIds: recipients,
      );

      const rocketAnimationUrl = 'assets/animations/gift_gif_31.svga';
      const rocketIconUrl = 'https://cdn-icons-png.flaticon.com/512/3253/3253113.png';

      if (widget.isAudioRoom) {
        await RoomService.sendGift(
          roomId: widget.roomId,
          giftAnimationUrl: rocketAnimationUrl,
          giftImageUrl: rocketIconUrl,
          giftValue: coins,
          category: 'Rocket',
          receiverId: recipients.isNotEmpty ? recipients.first : widget.hostId,
          receiverName: 'Audience ($personsCount)',
          duration: duration,
          person: personsCount,
        );
      } else {
        await LiveStreamService.sendGift(
          roomId: widget.roomId,
          giftAnimationUrl: rocketAnimationUrl,
          giftImageUrl: rocketIconUrl,
          giftValue: coins,
          category: 'Rocket',
          receiverId: recipients.isNotEmpty ? recipients.first : widget.hostId,
          receiverName: 'Audience ($personsCount)',
          duration: duration,
          person: personsCount,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rocket 🚀 sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAudienceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2d1b2b),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isAllSelected = _roomAudience.isNotEmpty && _selectedAudienceIds.length == _roomAudience.length;
            return FractionallySizedBox(
              heightFactor: 0.6,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Select Audience in Room",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              setState(() {
                                if (isAllSelected) {
                                  _selectedAudienceIds.clear();
                                } else {
                                  _selectedAudienceIds = _roomAudience.map((u) => u['userId'] as String).toSet();
                                }
                              });
                            });
                          },
                          child: Text(
                            isAllSelected ? "Deselect All" : "Select All",
                            style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24),
                    Expanded(
                      child: _roomAudience.isEmpty
                          ? Center(
                              child: Text(
                                "No other audience in this room",
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _roomAudience.length,
                              itemBuilder: (context, index) {
                                final user = _roomAudience[index];
                                final userId = user['userId'] as String;
                                final isSelected = _selectedAudienceIds.contains(userId);

                                return ListTile(
                                  onTap: () {
                                    setModalState(() {
                                      setState(() {
                                        if (isSelected) {
                                          _selectedAudienceIds.remove(userId);
                                        } else {
                                          _selectedAudienceIds.add(userId);
                                        }
                                      });
                                    });
                                  },
                                  leading: CircleAvatar(
                                    backgroundImage: user['userPicture'] != null ? NetworkImage(user['userPicture']) : null,
                                    child: user['userPicture'] == null ? const Icon(Icons.person, color: Colors.white) : null,
                                  ),
                                  title: Text(user['userName'] ?? 'User', style: const TextStyle(color: Colors.white)),
                                  trailing: Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSelected ? Colors.amber : Colors.white54,
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "Done (${_selectedAudienceIds.length} Selected)",
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomInput(String label, IconData icon, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.black54, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSelectPersonField() {
    final count = _selectedAudienceIds.length;
    final text = count == 0 ? "Select person (0 selected)" : "$count person(s) selected";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Select person",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
        ),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showAudienceModal,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.person, color: Colors.black54, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: count == 0 ? Colors.black54 : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, color: Colors.black54),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 16.0 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (!_isCustomConfig) ...[
              const Text(
                "Config rocket",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Select Coin amount for Rocket",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.amber, width: 2),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.amber.withValues(alpha: 0.2),
                      ),
                      child: const Icon(
                        Icons.monetization_on,
                        color: Colors.amber,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "10000",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "10 Person | 5 Sec",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isCustomConfig = true;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 2),
                          color: Colors.amber.withValues(alpha: 0.2),
                        ),
                        child: const Icon(Icons.edit, color: Colors.amber, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isCustomConfig = true;
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Custom config",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.8),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ] else ...[
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => setState(() => _isCustomConfig = false),
                  ),
                  const Expanded(
                    child: Column(
                      children: [
                        Text(
                          "Config rocket",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Configure custom amount for Rocket",
                          style: TextStyle(color: Colors.white60, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 24),
              _buildCustomInput("Enter coin quantity", Icons.monetization_on, _coinController),
              const SizedBox(height: 16),
              _buildSelectPersonField(),
              const SizedBox(height: 16),
              _buildCustomInput("Enter duration(Sec)", Icons.timer, _durationController),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFd4af37),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 4,
                ),
                onPressed: _isSending ? null : _sendRocket,
                child: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        "Send Rocket",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

void showRocketConfigBottomSheet(
  BuildContext context, {
  required String roomId,
  required String hostId,
  required bool isAudioRoom,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF2d1b2b),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return RocketConfigBottomSheet(
        roomId: roomId,
        hostId: hostId,
        isAudioRoom: isAudioRoom,
      );
    },
  );
}
