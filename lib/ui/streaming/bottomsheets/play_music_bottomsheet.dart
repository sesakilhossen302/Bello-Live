import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

class MusicTrack {
  final String id;
  final String name;
  final String filePath;

  MusicTrack({required this.id, required this.name, required this.filePath});
}

class MusicPlayerManager extends ChangeNotifier {
  final List<MusicTrack> _playlist = [];
  MusicTrack? _currentTrack;
  bool _isPlaying = false;
  int _currentTrackIndex = -1;
  int _currentProgress = 0;
  int _totalDuration = 0;

  Timer? _progressTimer;
  bool _isInitialized = false;

  // Getters
  List<MusicTrack> get playlist => _playlist;

  MusicTrack? get currentTrack => _currentTrack;

  bool get isPlaying => _isPlaying;

  int get currentTrackIndex => _currentTrackIndex;

  int get currentProgress => _currentProgress;

  int get totalDuration => _totalDuration;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Listen to play state changes
    ZegoUIKit().getMediaPlayStateNotifier().addListener(_onPlayStateChanged);

    // Listen to progress updates with a timer
    _progressTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isPlaying) {
        _currentProgress = ZegoUIKit().getMediaCurrentProgress();
        _totalDuration = ZegoUIKit().getMediaTotalDuration();
        notifyListeners();
      }
    });
  }

  void _onPlayStateChanged() {
    final state = ZegoUIKit().getMediaPlayStateNotifier().value;
    _isPlaying = state == ZegoUIKitMediaPlayState.playing;
    notifyListeners();

    // Auto play next when current track ends
    if (state == ZegoUIKitMediaPlayState.playEnded) {
      playNext();
    }
  }

  Future<void> addMusicFromDevice() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final musicDir = Directory('${appDocDir.path}/music');
        if (!await musicDir.exists()) {
          await musicDir.create(recursive: true);
        }

        for (var file in result.files) {
          if (file.path != null) {
            // Copy file to a persistent location to ensure Zego can access it
            final fileName = file.name;
            final targetFile = File('${musicDir.path}/$fileName');
            await File(file.path!).copy(targetFile.path);

            final track = MusicTrack(
              id: '${DateTime.now().millisecondsSinceEpoch}_$fileName',
              name: fileName,
              filePath: targetFile.path,
            );
            _playlist.add(track);
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error adding music: $e');
      rethrow;
    }
  }

  Future<void> playTrack(int index) async {
    try {
      final track = _playlist[index];
      final file = File(track.filePath);
      
      if (!await file.exists()) {
        throw Exception('Music file not found at ${track.filePath}');
      }

      // Stop current music if playing
      if (_isPlaying) {
        await ZegoUIKit().stopMedia();
      }

      // Play new track
      final playResult = await ZegoUIKit().playMedia(
        filePathOrURL: track.filePath,
        enableRepeat: false,
        autoStart: true,
      );

      if (playResult.errorCode == 0) { // Zego success code is 0
        // Set volume to sync with remote (so everyone can hear)
        await ZegoUIKit().setMediaVolume(60, isSyncToRemote: true);

        _currentTrack = track;
        _currentTrackIndex = index;
        _isPlaying = true;
        notifyListeners();
      } else {
        throw Exception('Zego Media Error ${playResult.errorCode}: ${playResult.message}');
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
      rethrow;
    }
  }

  Future<void> pauseResume() async {
    try {
      if (_isPlaying) {
        await ZegoUIKit().pauseMedia();
      } else {
        await ZegoUIKit().resumeMedia();
      }
    } catch (e) {
      debugPrint('Error pause/resume: $e');
    }
  }

  Future<void> stopMusic() async {
    try {
      await ZegoUIKit().stopMedia();

      _isPlaying = false;
      _currentTrack = null;
      _currentTrackIndex = -1;
      _currentProgress = 0;
      _totalDuration = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error stopping music: $e');
    }
  }

  Future<void> playNext() async {
    if (_playlist.isEmpty) return;

    final nextIndex = (_currentTrackIndex + 1) % _playlist.length;
    await playTrack(nextIndex);
  }

  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;

    final prevIndex = _currentTrackIndex <= 0 ? _playlist.length - 1 : _currentTrackIndex - 1;
    await playTrack(prevIndex);
  }

  Future<void> removeTrack(int index) async {
    try {
      // If currently playing track is being removed, stop it
      if (_currentTrackIndex == index) {
        await stopMusic();
      }

      _playlist.removeAt(index);

      // Update current track index if needed
      if (_currentTrackIndex > index) {
        _currentTrackIndex--;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error removing track: $e');
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    ZegoUIKit().getMediaPlayStateNotifier().removeListener(_onPlayStateChanged);
    super.dispose();
  }
}

class PlayMusicBottomSheet extends StatefulWidget {
  final bool isHost;
  final MusicPlayerManager musicManager;

  const PlayMusicBottomSheet({super.key, required this.isHost, required this.musicManager});

  @override
  State<PlayMusicBottomSheet> createState() => _PlayMusicBottomSheetState();
}

class _PlayMusicBottomSheetState extends State<PlayMusicBottomSheet> {
  @override
  void initState() {
    super.initState();
    // Listen to music manager changes
    widget.musicManager.addListener(_onMusicStateChanged);
  }

  @override
  void dispose() {
    widget.musicManager.removeListener(_onMusicStateChanged);
    super.dispose();
  }

  void _onMusicStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _addMusicFromDevice() async {
    if (!widget.isHost) return;

    try {
      await widget.musicManager.addMusicFromDevice();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Music added to playlist'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding music: $e')));
      }
    }
  }

  Future<void> _playTrack(int index) async {
    if (!widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the host can control music playback'), backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      await widget.musicManager.playTrack(index);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error playing track: $e')));
      }
    }
  }

  Future<void> _removeTrack(int index) async {
    if (!widget.isHost) return;

    try {
      await widget.musicManager.removeTrack(index);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Track removed from playlist'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('Error removing track: $e');
    }
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final musicManager = widget.musicManager;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFF2d1b2b),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              child: Row(
                children: [
                  const Text(
                    'Playlist',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (widget.isHost)
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.pink, size: 28),
                      onPressed: _addMusicFromDevice,
                      tooltip: 'Add Music',
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1, thickness: 1),

            // Playlist
            Expanded(child: musicManager.playlist.isEmpty ? _buildEmptyState() : _buildPlaylist(musicManager)),

            // Music Player Controls
            if (musicManager.currentTrack != null) _buildMusicPlayer(musicManager),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_outlined, size: 80, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No music in playlist', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 18)),
          if (widget.isHost) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _addMusicFromDevice,
              icon: const Icon(Icons.add),
              label: const Text('Add Music'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlaylist(MusicPlayerManager musicManager) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: musicManager.playlist.length,
      itemBuilder: (context, index) {
        final track = musicManager.playlist[index];
        final isCurrentTrack = musicManager.currentTrackIndex == index;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isCurrentTrack ? Colors.pink.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
            border: isCurrentTrack ? Border.all(color: Colors.pink, width: 2) : null,
          ),
          child: ListTile(
            leading: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: isCurrentTrack ? Colors.pink : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCurrentTrack && musicManager.isPlaying ? Icons.music_note : Icons.music_note_outlined,
                color: Colors.white,
              ),
            ),
            title: Text(
              track.name,
              style: TextStyle(
                color: isCurrentTrack ? Colors.pink : Colors.white,
                fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: widget.isHost
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCurrentTrack || !musicManager.isPlaying)
                        IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.white),
                          onPressed: () => _playTrack(index),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _removeTrack(index),
                      ),
                    ],
                  )
                : null,
            onTap: widget.isHost ? () => _playTrack(index) : null,
          ),
        );
      },
    );
  }

  Widget _buildMusicPlayer(MusicPlayerManager musicManager) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.pink.withValues(alpha: 0.3), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Now Playing
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.pink.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.music_note, color: Colors.pink, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Now Playing', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(
                      musicManager.currentTrack?.name ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress Bar
          Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: musicManager.totalDuration > 0
                      ? musicManager.currentProgress.toDouble().clamp(0.0, musicManager.totalDuration.toDouble())
                      : 0,
                  max: musicManager.totalDuration > 0 ? musicManager.totalDuration.toDouble() : 1.0,
                  activeColor: Colors.pink,
                  inactiveColor: Colors.white24,
                  onChanged: widget.isHost
                      ? (value) async {
                          await ZegoUIKit().seekTo(value.toInt());
                        }
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(musicManager.currentProgress),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(musicManager.totalDuration),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Controls
          if (widget.isHost)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                  onPressed: () => widget.musicManager.playPrevious(),
                ),
                const SizedBox(width: 20),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Colors.pink.shade400, Colors.pink.shade600]),
                  ),
                  child: IconButton(
                    icon: Icon(musicManager.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 32),
                    onPressed: () => widget.musicManager.pauseResume(),
                  ),
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                  onPressed: () => widget.musicManager.playNext(),
                ),
                const SizedBox(width: 20),
                IconButton(
                  icon: const Icon(Icons.stop, color: Colors.white, size: 28),
                  onPressed: () => widget.musicManager.stopMusic(),
                ),
              ],
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Only host can control playback', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

void showPlayMusicBottomSheet(BuildContext context, {required bool isHost, required MusicPlayerManager musicManager}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return PlayMusicBottomSheet(isHost: isHost, musicManager: musicManager);
    },
  );
}
