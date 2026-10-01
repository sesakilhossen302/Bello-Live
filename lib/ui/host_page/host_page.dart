import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/remote/firebase/live_streaming_services.dart';
import '../../data/remote/firebase/room_services.dart';
import '../../data/remote/firebase/video_room_services.dart';
import '../../data/remote/firebase/profile_services.dart';
import '../../navigation/routes.dart';
import '../../core/localization/app_localizations.dart';
import '../../theme/app_theme.dart';

enum PartyType { voice, video, stream }

class HostPage extends StatefulWidget {
  const HostPage({super.key});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  PartyType _selectedPartyType = PartyType.stream;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5A189A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, size: 26, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          AppLocalizations.of(context).startLive,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 1),
            // App Logo
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 60,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logo/pigo live.png',
                height: 260, // Increased from 160
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.live_tv_rounded,
                  size: 140,
                  color: Colors.white,
                ),
              ),
            ),
            const Spacer(flex: 2),

            // Selectors
            _buildPartyTypeSelector(),

            const SizedBox(height: 60),

            // Start Live Button
            _buildStartLiveButton(),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildPartyTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Video Live Option
          _buildSelectorTile(
            title: 'Video Live',
            icon: CupertinoIcons.videocam_fill,
            isSelected: _selectedPartyType == PartyType.stream,
            onTap: () => setState(() => _selectedPartyType = PartyType.stream),
          ),
          const SizedBox(width: 20),
          // Audio Live Option
          _buildSelectorTile(
            title: 'Audio Live',
            icon: CupertinoIcons.music_mic,
            isSelected: _selectedPartyType == PartyType.voice,
            onTap: () => setState(() => _selectedPartyType = PartyType.voice),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF5A189A) : Colors.white,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF5A189A) : Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartLiveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _startLive,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Color(0xFF5A189A), strokeWidth: 2.5),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.play_circle_fill, size: 28, color: Color(0xFF5A189A)),
                    SizedBox(width: 12),
                    Text(
                      'Start Live',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Color(0xFF5A189A),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _startLive() async {
    setState(() => _isLoading = true);

    try {
      if (_selectedPartyType == PartyType.voice) {
        final roomId = await RoomService.createRoom();
        if (mounted) {
          // Because we pushed this page, we should replace it with the room to prevent stacking
          context.pushReplacement(
            '${Routes.audioRoom.path}?roomId=$roomId&isHost=true',
            extra: {'roomId': roomId, 'isHost': true},
          );
        }
      } else if (_selectedPartyType == PartyType.stream) {
        final roomId = await LiveStreamService.createRoom();
        if (mounted) {
          context.pushReplacement(
            '${Routes.liveStream.path}?roomId=$roomId&isHost=true',
            extra: {'roomId': roomId, 'isHost': true},
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting live: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start live: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
