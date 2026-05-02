import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import

// --- 1. DATA MODEL ---
class BigWinner {
  final String userId;
  final String name;
  final String photoUrl;
  final int amount;
  final String gameName;

  BigWinner({
    required this.userId,
    required this.name,
    required this.photoUrl,
    required this.amount,
    required this.gameName,
  });
}

// --- 2. QUEUE MANAGER (CONTROLLER) ---
class BigWinnerQueue extends ChangeNotifier {
  final List<BigWinner> _queue = [];
  BigWinner? currentWinner;
  StreamSubscription? _subscription;
  Timer? _displayTimer;

  bool _isInitialized = false; // Prevents multiple initializations

  static const int _displayDurationSeconds = 4;
  static const int _historyFetchMinutes = 1;

  void init() {
    // Check if already listening
    if (_isInitialized) return;
    _isInitialized = true;

    final startAfter = Timestamp.fromDate(DateTime.now().subtract(const Duration(minutes: _historyFetchMinutes)));

    _subscription = FirebaseFirestore.instance
        .collection('bigWinners')
        .where('timestamp', isGreaterThan: startAfter)
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final data = change.doc.data() as Map<String, dynamic>;

              final int amount = data['amount'] ?? 0;

              // Only add to queue if amount is >= 29000
              if (amount >= 29000) {
                _addToQueue(
                  BigWinner(
                    userId: data['userId'] ?? '',
                    name: data['winnerName'] ?? 'Lucky Player',
                    photoUrl: data['winnerPhoto'] ?? '',
                    amount: amount,
                    gameName: data['gameName'] ?? 'Unknown Game',
                  ),
                );
              }
            }
          }
        });
  }

  void _addToQueue(BigWinner winner) {
    _queue.add(winner);
    if (currentWinner == null) {
      _showNextWinner();
    }
  }

  void _showNextWinner() {
    _displayTimer?.cancel();
    if (_queue.isEmpty) {
      currentWinner = null;
      notifyListeners();
      return;
    }
    currentWinner = _queue.removeAt(0);
    notifyListeners();
    _displayTimer = Timer(const Duration(seconds: _displayDurationSeconds), () {
      _showNextWinner();
    });
  }

  // Call this on Logout
  void clearAndStop() {
    _subscription?.cancel();
    _subscription = null;
    _displayTimer?.cancel();
    _queue.clear();
    currentWinner = null;
    _isInitialized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    clearAndStop();
    super.dispose();
  }
}

// --- 3. UI WIDGET ---
class BigWinnerOverlay extends StatelessWidget {
  const BigWinnerOverlay({super.key});

  static const bool _isTestMode = false;
  static const int _testAmount = 30000;

  static final BigWinner _testWinner = BigWinner(
    userId: 'test_001',
    name: 'Test Player',
    photoUrl: '',
    amount: _testAmount,
    gameName: 'Fruits King',
  );

  @override
  Widget build(BuildContext context) {
    final queueInstance = GetIt.I<BigWinnerQueue>();
    return AnimatedBuilder(
      animation: queueInstance,
      builder: (context, child) {
        final winner = _isTestMode ? _testWinner : queueInstance.currentWinner;

        final currentKey = winner?.userId ?? 'empty_placeholder';

        return Positioned(
          top: 80,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (Widget child, Animation<double> animation) {
                final childKey = (child.key as ValueKey).value;
                final isEntering = childKey == currentKey;

                if (isEntering) {
                  return SlideTransition(
                    position: Tween<Offset>(begin: const Offset(1.5, 0.0), end: Offset.zero).animate(animation),
                    child: child,
                  );
                } else {
                  return SlideTransition(
                    position: Tween<Offset>(begin: const Offset(-1.5, 0.0), end: Offset.zero).animate(animation),
                    child: child,
                  );
                }
              },
              child: winner == null || winner.amount < 29000
                  ? const SizedBox.shrink(key: ValueKey('empty_placeholder'))
                  : _buildModernCard(context, winner),
            ),
          ),
        );
      },
    );
  }

  String _truncateName(String name) {
    if (name.length > 8) {
      return "${name.substring(0, 8)}...";
    }
    return name;
  }

  // --- HELPER: GAME LOGO ---
  Widget _buildGameLogo(String gameName, {double size = 24}) {
    if (gameName == "Fruits King") {
      return Image.asset(
        "assets/spinner/fruits.jpeg",
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.videogame_asset, color: Colors.white, size: size * 0.6);
        },
      );
    } else if (gameName == "Teen Patti") {
      return Image.asset(
        "assets/icons/tin_patti_icon.png",
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.videogame_asset, color: Colors.white, size: size * 0.6);
        },
      );
    } else if (gameName == "Greedy") {
      return Image.asset(
        "assets/greedy/greedy.jpeg",
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Icon(Icons.videogame_asset, color: Colors.white, size: size * 0.6);
        },
      );
    }
    // Fallback Icon
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black26),
      child: Icon(Icons.videogame_asset, color: Colors.white, size: size * 0.6),
    );
  }

  // --- MODERN UNIFIED CARD ---
  Widget _buildModernCard(BuildContext context, BigWinner winner) {
    return Material(
      key: ValueKey(winner.userId),
      type: MaterialType.transparency,
      child: Container(
        width: 340,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)], // Sleek dark bluish-grey gradient
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.amberAccent.shade400, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.amberAccent.withValues(alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar with a glowing border and Active Frame
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.amberAccent.withValues(alpha: 0.4), blurRadius: 8)],
              ),
              child: SizedBox(
                width: 44, // radius 22 * 2
                height: 44,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage: winner.photoUrl.isNotEmpty ? NetworkImage(winner.photoUrl) : null,
                      child: winner.photoUrl.isEmpty ? const Icon(Icons.person, size: 22, color: Colors.white) : null,
                    ),
                    // Active Frame Overlay (44 * 1.3 = 57.2)
                    Positioned(
                      width: 57.2,
                      height: 57.2,
                      child: IgnorePointer(child: ActiveFrameWidget(userId: winner.userId, size: 57.2)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Name & Win Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _truncateName(winner.name),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Win 🤪",
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // Amount
            Text(
              "\$${winner.amount}",
              style: const TextStyle(
                color: Colors.amberAccent,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 2))],
              ),
            ),
            const SizedBox(width: 12),

            // Game Logo
            _buildGameLogo(winner.gameName, size: 38),
          ],
        ),
      ),
    );
  }
}
