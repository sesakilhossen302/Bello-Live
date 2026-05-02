// lib/ui/host/host_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/remote/firebase/live_streaming_services.dart';
import '../../data/remote/firebase/room_services.dart';
import '../../data/remote/firebase/video_room_services.dart';
import '../../navigation/routes.dart';
import '../../theme/app_theme.dart';

// Enum to manage the selected party type
enum PartyType { voice, video, stream }

class HostPage extends StatefulWidget {
  const HostPage({super.key});

  @override
  State<HostPage> createState() => _HostPageState();
}

class _HostPageState extends State<HostPage> {
  // Default to voice (Mic)
  PartyType _selectedPartyType = PartyType.voice;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildTransparentAppBar(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
          image: DecorationImage(
            image: AssetImage('assets/images/host_bg.png'),
            fit: BoxFit.contain,
            alignment: Alignment(0.0, -0.3),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Pushes content down. Adjusted flex to push it lower.
              const Spacer(flex: 3),

              // --- 1. Circular Selectors (Video vs Voice) ---
              _buildPartyTypeSelector(),

              // --- 2. Fixed 80px Spacing ---
              const SizedBox(height: 80),

              // --- 3. Start Live Button ---
              _buildStartLiveButton(),

              const SizedBox(height: 50), // Bottom spacing
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTransparentAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 24),
        onPressed: () => context.go(Routes.home.path),
      ),
      title: Text("Start live", style: TextStyle(color: Colors.white)),
    );
  }

  // --- Selector Logic ---
  Widget _buildPartyTypeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Video / Stream Button (Left)
          _buildCircleButton(
            icon: Icons.videocam_rounded,
            isSelected: _selectedPartyType == PartyType.stream,
            onTap: () => setState(() => _selectedPartyType = PartyType.stream),
          ),

          const SizedBox(width: 60), // Space between buttons
          // Mic / Voice Button (Right)
          _buildCircleButton(
            icon: Icons.mic_rounded,
            isSelected: _selectedPartyType == PartyType.voice,
            onTap: () => setState(() => _selectedPartyType = PartyType.voice),
          ),
        ],
      ),
    );
  }

  // --- Custom Circular Button Widget ---
  Widget _buildCircleButton({required IconData icon, required bool isSelected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // FIX 1: Both are purple gradient now.
          gradient: LinearGradient(
            colors: isSelected
                ? [const Color(0xFFD96FF8), const Color(0xFF9F42F5)] // Bright when selected
                : [const Color(0xFFD96FF8).withValues(alpha: 0.3), const Color(0xFF9F42F5).withValues(alpha: 0.3)],
            // Dimmed when not
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          // FIX 1: Glow only when selected
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF9F42F5).withValues(alpha: 0.6), blurRadius: 15, spreadRadius: 2)]
              : null,
          border: Border.all(
            color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.white.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          // Icon is white when selected, dimmed white when not
          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
          size: 32,
        ),
      ),
    );
  }

  // --- Start Live Button Widget ---
  Widget _buildStartLiveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: GestureDetector(
        onTap: _isLoading ? null : _startLive,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          height: 55,
          decoration: BoxDecoration(
            // FIX 3: More rectangular (smaller radius)
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Color(0xFFE48AFF), Color(0xFF9152FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xFF9152FF).withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: _isLoading
              ? const Center(
                  child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                )
              : const Center(
                  child: Text(
                    'Start Live',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _startLive() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      switch (_selectedPartyType) {
        case PartyType.voice:
          String roomId = await RoomService.createRoom();
          if (!mounted) return;
          context.pushReplacement(Routes.audioRoom.path, extra: {"roomId": roomId, "isHost": true});
          break;
        case PartyType.video:
          String roomId = await VideoRoomService.createRoom();
          if (!mounted) return;
          context.pushReplacement(Routes.videoRoom.path, extra: {"roomId": roomId, "isHost": true});
          break;
        case PartyType.stream:
          String roomId = await LiveStreamService.createRoom();
          if (!mounted) return;
          context.pushReplacement(Routes.liveStream.path, extra: {"roomId": roomId, "isHost": true});
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error creating room: ${e.toString()}")));
      setState(() {
        _isLoading = false;
      });
    }
  }
}
