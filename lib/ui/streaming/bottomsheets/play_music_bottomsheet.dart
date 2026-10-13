import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../../../data/remote/firebase/live_streaming_services.dart';
import '../../../theme/app_theme.dart';

class MusicTrack {
  final String id;
  final String name;
  final String filePath;
  final String? thumbnailUrl;
  final int durationSeconds;

  MusicTrack({
    required this.id,
    required this.name,
    required this.filePath,
    this.thumbnailUrl,
    this.durationSeconds = 0,
  });
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

  String? _roomId;

  // Getters
  List<MusicTrack> get playlist => _playlist;

  MusicTrack? get currentTrack => _currentTrack;

  bool get isPlaying => _isPlaying;

  int get currentTrackIndex => _currentTrackIndex;

  int get currentProgress => _currentProgress;

  int get totalDuration => _totalDuration;

  void initialize(String roomId) {
    _roomId = roomId;
    if (_isInitialized) return;
    _isInitialized = true;
  }

  void addTrack(MusicTrack track) {
    _playlist.add(track);
    notifyListeners();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isPlaying) {
        _currentProgress++;
        if (_totalDuration > 0 && _currentProgress >= _totalDuration) {
          playNext();
        } else {
          notifyListeners();
        }
      }
    });
  }

  void seekTo(int position) {
    _currentProgress = position;
    if (_roomId != null && _currentTrack != null) {
      String trackId = _currentTrack!.filePath;
      if (!_isPlaying) {
        trackId = 'PAUSE_$trackId';
      }
      LiveStreamService.setRoomMusic(
        _roomId!,
        trackId,
        startSeconds: position.toDouble(),
        isPaused: !_isPlaying,
      );
    }
    notifyListeners();
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
            // Copy file to a persistent location to ensure audio player can access it
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

  Future<List<Video>> searchYoutubeVideos(String query) async {
    final yt = YoutubeExplode();
    try {
      final searchResults = await yt.search.search(query);
      return searchResults.toList();
    } catch (e) {
      debugPrint('Error searching YouTube: $e');
      return [];
    } finally {
      yt.close();
    }
  }

  Future<void> addSpecificMusicFromYoutube(Video video, {bool playNow = false}) async {
    final track = MusicTrack(
      id: video.id.value,
      name: video.title,
      filePath: video.id.value, // We store the videoId in filePath for YouTube
      thumbnailUrl: video.thumbnails.lowResUrl,
      durationSeconds: video.duration?.inSeconds ?? 0,
    );
    
    _playlist.add(track);
    notifyListeners();

    if (playNow) {
      await playTrack(_playlist.length - 1);
    }
  }

  Future<void> playTrack(int index) async {
    try {
      final track = _playlist[index];

      _currentTrack = track;
      _currentTrackIndex = index;
      _currentProgress = 0;
      _totalDuration = track.durationSeconds;
      _isPlaying = true;

      // Update Firebase with synchronized start time
      if (_roomId != null) {
        await LiveStreamService.setRoomMusic(
          _roomId!,
          track.filePath,
          startSeconds: 0.0,
          isPaused: false,
        );
      }

      _startProgressTimer();
      notifyListeners();

      // If duration is unknown, fetch duration asynchronously and update!
      if (_totalDuration <= 0) {
        final cleanId = track.id.replaceFirst('AUDIO_', '');
        YoutubeExplode().videos.get(cleanId).then((v) {
          if (v.duration != null && v.duration!.inSeconds > 0) {
            _totalDuration = v.duration!.inSeconds;
            notifyListeners();
          }
        }).catchError((_) {});
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
      rethrow;
    }
  }

  Future<void> pauseResume() async {
    try {
      if (_roomId == null || _currentTrack == null) return;

      _isPlaying = !_isPlaying;

      if (_isPlaying) {
        _startProgressTimer();
      } else {
        _progressTimer?.cancel();
      }

      String trackId = _currentTrack!.filePath; // e.g. 'AUDIO_123' or '123'
      if (!_isPlaying) {
        trackId = 'PAUSE_$trackId';
      }

      await LiveStreamService.setRoomMusic(
        _roomId!,
        trackId,
        startSeconds: _currentProgress.toDouble(),
        isPaused: !_isPlaying,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error pause/resume: $e');
    }
  }

  Future<void> stopMusic() async {
    try {
      _progressTimer?.cancel();
      if (_roomId != null) {
        await LiveStreamService.setRoomMusic(_roomId!, null);
      }

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
  final TextEditingController _searchController = TextEditingController();
  List<Video> _searchResults = [];
  bool _isSearching = false;

  List<Video> _recommendedSongs = [];
  bool _isLoadingRecommendations = true;

  @override
  void initState() {
    super.initState();
    widget.musicManager.addListener(_onMusicStateChanged);
    _fetchRecommendedSongs();
  }

  Future<void> _fetchRecommendedSongs() async {
    final queries = [
      'bangla hindi hit songs mix',
      'new bangla hindi mashup',
      'trending bangla hindi music',
      'bangla hindi party songs'
    ];
    queries.shuffle();
    final query = queries.first;
    
    final results = await widget.musicManager.searchYoutubeVideos(query);
    if (mounted) {
      setState(() {
        _recommendedSongs = results.take(10).toList();
        _isLoadingRecommendations = false;
      });
    }
  }

  @override
  void dispose() {
    widget.musicManager.removeListener(_onMusicStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onMusicStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);
    
    final results = await widget.musicManager.searchYoutubeVideos(query);
    
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _addOrPlayYoutubeVideo(Video video, bool playNow, {bool audioOnly = false}) async {
    if (!widget.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the host can control music playback'), backgroundColor: Colors.orange),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(playNow ? 'Loading and playing...' : 'Adding to playlist...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // Modify the video ID slightly to indicate audio-only in our manager
      final trackId = audioOnly ? 'AUDIO_${video.id.value}' : video.id.value;
      
      final track = MusicTrack(
        id: trackId,
        name: video.title,
        filePath: trackId, // We store the trackId in filePath
        thumbnailUrl: video.thumbnails.lowResUrl,
        durationSeconds: video.duration?.inSeconds ?? 0,
      );
      
      widget.musicManager.addTrack(track);

      if (playNow) {
        await widget.musicManager.playTrack(widget.musicManager.playlist.length - 1);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(playNow ? 'Playing ${video.title}' : 'Added ${video.title}'), backgroundColor: Colors.green),
        );
        if (playNow) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Playlist actions
  Future<void> _playTrack(int index) async {
    if (!widget.isHost) return;
    try {
      await widget.musicManager.playTrack(index);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error playing track: $e');
    }
  }

  Future<void> _removeTrack(int index) async {
    if (!widget.isHost) return;
    try {
      await widget.musicManager.removeTrack(index);
    } catch (e) {
      debugPrint('Error removing track: $e');
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final sec = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$sec';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85, // taller for searching
        decoration: const BoxDecoration(
          gradient: AppGradients.backgroundGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle for drag
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [Colors.cyanAccent, Colors.purpleAccent],
                    ).createShader(bounds),
                    child: const Text(
                      'Live Music Center',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _performSearch(),
                  decoration: InputDecoration(
                    hintText: 'Search YouTube...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                    prefixIcon: const Icon(Icons.search, color: Colors.cyanAccent),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search, color: Colors.pinkAccent), // Changed to search icon
                      onPressed: _performSearch,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
            ),

            if (_searchResults.isEmpty && _searchController.text.trim().isEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Text(
                  widget.musicManager.playlist.isEmpty ? 'Recommended Music' : 'Current Playlist',
                  style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: widget.musicManager.playlist.isEmpty
                    ? _buildRecommendedSongsList()
                    : _buildPlaylist(widget.musicManager),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: Text(
                  'Select a track to start the party',
                  style: TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: _isSearching
                    ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
                    : _buildSearchResults(),
              ),
            ],

            // Player controls at the bottom if something is playing
            if (widget.musicManager.currentTrack != null)
              _buildMusicPlayer(widget.musicManager),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    return _buildVideoList(_searchResults);
  }

  Widget _buildRecommendedSongsList() {
    if (_isLoadingRecommendations) {
      return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
    }
    if (_recommendedSongs.isEmpty) {
      return Center(
        child: Text(
          'Could not load recommendations',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }
    return _buildVideoList(_recommendedSongs);
  }

  Widget _buildVideoList(List<Video> videos) {
    if (videos.isEmpty) {
      return Center(
        child: Text(
          'No results found',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  video.thumbnails.lowResUrl,
                  width: 80,
                  height: 45,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 45,
                    color: Colors.black26,
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title and Channel
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.author,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Actions
              if (widget.isHost) ...[
                IconButton(
                  icon: const Icon(Icons.music_note, color: Colors.purpleAccent),
                  onPressed: () => _addOrPlayYoutubeVideo(video, true, audioOnly: true), // play now audio only
                  tooltip: 'Play Audio Only',
                ),
                IconButton(
                  icon: const Icon(Icons.play_circle_fill, color: Colors.cyanAccent),
                  onPressed: () => _addOrPlayYoutubeVideo(video, true, audioOnly: false), // play now with video
                  tooltip: 'Play Video',
                ),
              ],
            ],
          ),
        );
      },
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
            color: isCurrentTrack ? Colors.pink.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: isCurrentTrack ? Border.all(color: Colors.pink.withValues(alpha: 0.5)) : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: track.thumbnailUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.network(
                      track.thumbnailUrl!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        isCurrentTrack ? Icons.multitrack_audio : Icons.music_note,
                        color: isCurrentTrack ? Colors.pink : Colors.white70,
                      ),
                    ),
                  )
                : Icon(
                    isCurrentTrack ? Icons.multitrack_audio : Icons.music_note,
                    color: isCurrentTrack ? Colors.pink : Colors.white70,
                  ),
            title: Text(
              track.name,
              style: TextStyle(
                color: isCurrentTrack ? Colors.pink : Colors.white,
                fontWeight: isCurrentTrack ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: widget.isHost
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isCurrentTrack)
                        IconButton(
                          icon: const Icon(Icons.play_arrow, color: Colors.white70),
                          onPressed: () => _playTrack(index),
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _removeTrack(index),
                      ),
                    ],
                  )
                : null,
            onTap: widget.isHost && !isCurrentTrack ? () => _playTrack(index) : null,
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
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1)),
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
                child: const Icon(Icons.music_note, color: Colors.pinkAccent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Now Playing', style: TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                    Text(
                      musicManager.currentTrack?.name ?? 'Unknown',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.isHost)
                IconButton(
                  icon: const Icon(Icons.power_settings_new, color: Colors.redAccent, size: 22),
                  tooltip: 'Turn off music',
                  onPressed: () {
                    musicManager.stopMusic();
                  },
                ),
            ],
          ),
          
          if (widget.isHost) ...[
            const SizedBox(height: 16),
            // Progress Bar
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                activeTrackColor: Colors.pinkAccent,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.pinkAccent,
              ),
              child: Slider(
                value: musicManager.currentProgress.toDouble().clamp(
                  0.0,
                  musicManager.totalDuration > 0
                      ? musicManager.totalDuration.toDouble()
                      : 1.0,
                ),
                max: musicManager.totalDuration > 0 ? musicManager.totalDuration.toDouble() : 1.0,
                onChanged: (value) {
                  musicManager.seekTo(value.toInt());
                },
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
            
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous, color: Colors.white, size: 32),
                  onPressed: musicManager.playlist.isNotEmpty ? musicManager.playPrevious : null,
                ),
                const SizedBox(width: 16),
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.pinkAccent,
                  ),
                  child: IconButton(
                    icon: Icon(
                      musicManager.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      musicManager.pauseResume();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 32),
                  onPressed: musicManager.playlist.isNotEmpty ? musicManager.playNext : null,
                ),
              ],
            ),
          ] else
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
