import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GlobalWinBanner extends StatefulWidget {
  const GlobalWinBanner({super.key});

  @override
  State<GlobalWinBanner> createState() => _GlobalWinBannerState();
}

class _GlobalWinBannerState extends State<GlobalWinBanner> {
  StreamSubscription? _gameWinsSubscription;
  final List<Map<String, dynamic>> _gameWinQueue = [];
  final Set<String> _processedWinDocIds = {};
  Map<String, dynamic>? _activeGameWin;
  bool _showGameWinBanner = false;

  @override
  void initState() {
    super.initState();
    _listenToGameWins();
  }

  @override
  void dispose() {
    _gameWinsSubscription?.cancel();
    super.dispose();
  }

  void _listenToGameWins() {
    final DateTime oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    bool isInitialLoad = true;
    final List<Map<String, dynamic>> initialWins = [];

    _gameWinsSubscription = FirebaseFirestore.instance
        .collection('room_game_wins')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(oneHourAgo))
        .orderBy('timestamp', descending: true)
        .limit(10) // Show up to the last 10 wins on app entry to avoid spam
        .snapshots()
        .listen((snapshot) {
          if (!mounted) return;

          final currentUserId = FirebaseAuth.instance.currentUser?.uid;

          if (isInitialLoad) {
            // Collect all initial wins
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final docId = change.doc.id;
                _processedWinDocIds.add(docId);
                final winData = change.doc.data();
                if (winData != null) {
                  // Do not show own win
                  if (currentUserId != null && winData['userId'] == currentUserId) {
                    continue;
                  }
                  initialWins.add(winData);
                }
              }
            }

            // Sort initial wins chronologically (oldest first)
            initialWins.sort((a, b) {
              final aTime = (a['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              final bTime = (b['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
              return aTime.compareTo(bTime);
            });

            // Add to queue and process
            setState(() {
              _gameWinQueue.addAll(initialWins);
            });
            _processGameWinQueue();

            isInitialLoad = false;
          } else {
            // Handle new additions after initial load
            for (var change in snapshot.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final docId = change.doc.id;
                if (!_processedWinDocIds.contains(docId)) {
                  _processedWinDocIds.add(docId);
                  final winData = change.doc.data();
                  if (winData != null) {
                    // Do not show own win
                    if (currentUserId != null && winData['userId'] == currentUserId) {
                      continue;
                    }
                    setState(() {
                      _gameWinQueue.add(winData);
                    });
                    _processGameWinQueue();
                  }
                }
              }
            }
          }
        });
  }

  void _processGameWinQueue() {
    if (_showGameWinBanner || _gameWinQueue.isEmpty) return;

    setState(() {
      _activeGameWin = _gameWinQueue.removeAt(0);
      _showGameWinBanner = true;
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _showGameWinBanner = false;
      });
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _activeGameWin = null;
        });
        _processGameWinQueue();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final winData = _activeGameWin;
    final bool show = _showGameWinBanner && winData != null;

    if (winData == null && !_showGameWinBanner) {
      return const SizedBox.shrink();
    }

    final String displayName = winData?['displayName'] ?? 'User';
    final String? photoUrl = winData?['photoUrl'];
    final String gameName = winData?['gameName'] ?? 'Game';
    final int winAmount = winData?['winAmount'] ?? 0;
    final String bannerType = winData?['bannerType'] ?? 'blue';

    final String assetPath = bannerType == 'red'
        ? 'assets/svga/gamebannerRED.svga'
        : 'assets/svga/gamebannerBlue.svga';

    String coinsText;
    if (winAmount >= 1000000) {
      coinsText = '${(winAmount / 1000000).toStringAsFixed(1)}M';
      if (coinsText.endsWith('.0M')) coinsText = '${(winAmount ~/ 1000000)}M';
    } else {
      coinsText = '${(winAmount / 1000).toStringAsFixed(0)}K';
    }

    Widget gameIcon;
    if (gameName == 'Tin Patti') {
      gameIcon = Image.asset(
        'assets/gameimages/card_back.png',
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.style, color: Colors.amber, size: 28),
      );
    } else {
      gameIcon = Image.asset(
        'assets/animalgame/bg.png',
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.pets, color: Colors.orange, size: 28),
      );
    }

    return Positioned(
      top: 180,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutBack,
          offset: show ? const Offset(0, 0) : const Offset(0, -1.5),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: show ? 1.0 : 0.0,
            child: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 320,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: SVGAEasyPlayer(
                          assetsName: assetPath,
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white24,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: gameIcon,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.amber,
                                width: 1.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundImage:
                                  photoUrl != null && photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: (photoUrl == null || photoUrl.isEmpty)
                                  ? const Icon(
                                      Icons.person,
                                      size: 20,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'Won in $gameName',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 9,
                                    shadows: const [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 3,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: bannerType == 'red'
                                    ? Colors.redAccent
                                    : Colors.lightBlueAccent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/coins/coin.png',
                                  width: 14,
                                  height: 14,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.monetization_on,
                                    color: Colors.amber,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+$coinsText',
                                  style: TextStyle(
                                    color: bannerType == 'red'
                                        ? Colors.redAccent.shade100
                                        : Colors.lightBlueAccent.shade100,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
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
          ),
        ),
      ),
    );
  }
}
