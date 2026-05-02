import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/remote/firebase/greedy_game_service.dart';
import '../../../data/remote/firebase/profile_services.dart';
import '../../../theme/app_theme.dart';
import 'bottomsheets/participants_bottomsheet.dart';
import 'bottomsheets/result_bottomsheet.dart';

class _LeafItemConfig {
  final String assetPath;
  final double sizeFactor;
  final double radiusFactor;
  final double angleDegrees;
  final int multiplier;

  _LeafItemConfig({
    required this.assetPath,
    required this.sizeFactor,
    required this.radiusFactor,
    required this.angleDegrees,
    required this.multiplier,
  });
}

class _CenterItemConfig {
  final String assetPath;
  final double sizeFactor;
  final double offsetXFactor;
  final double offsetYFactor;

  _CenterItemConfig({
    required this.assetPath,
    required this.sizeFactor,
    this.offsetXFactor = 0.0,
    this.offsetYFactor = 0.0,
  });
}

class GreedyGameBottomSheet extends StatefulWidget {
  const GreedyGameBottomSheet({super.key});

  @override
  State<GreedyGameBottomSheet> createState() => _GreedyGameBottomSheetState();
}

class _GreedyGameBottomSheetState extends State<GreedyGameBottomSheet> {
  // [NEW] Clock Sync variables
  int _clockOffset = 0;
  bool _isClockSynced = false;

  final GreedyGameService _gameService = GreedyGameService();
  final String _userId = FirebaseAuth.instance.currentUser!.uid;

  int _selectedCoinValue = 500;

  Timer? _spinTimer;
  int _animationLeafIndex = 0;
  int _serverWinningIndex = -1;
  String _lastKnownPhase = '';

  Timer? _countdownTimer;
  int _localCountdownSeconds = 0;
  String _currentRoundId = "0";

  int _myBalance = 0;
  final Map<int, int> _myBets = {};
  final Map<int, int> _totalBets = {}; // [NEW] Total bets tracker

  // [NEW] Robust Sync State
  bool _hasUnsavedChanges = false;

  // [NEW] Spoiler Prevention State
  bool _isAnimatingResult = false;
  List<int>? _pendingHistory;

  StreamSubscription? _controlsSubscription;
  StreamSubscription? _roundSubscription;
  StreamSubscription? _betsSubscription;
  StreamSubscription? _profileSubscription;
  StreamSubscription? _historySubscription;

  String _gameStatus = "loading";
  String _currentPhase = "waiting";
  List<int> _gameHistory = [];
  int _todaysRevenue = 0;
  List<GameParticipant> _gameParticipants = [];
  Map<String, dynamic>? _myParticipantMap;

  Timer? _syncBetsTimer;
  bool _isSyncing = false;
  bool _isAutoStarting = false;

  final String boardBackgroundImage = 'assets/greedy/board.png';
  final Map<String, int> _coinValues = {
    'assets/greedy/coin_500.png': 500,
    'assets/greedy/coin_1k.png': 1000,
    'assets/greedy/coin_10k.png': 10000,
    'assets/greedy/coin_50k.png': 50000,
  };

  final List<String> _resultImages = [
    'assets/greedy/bbq_result.png',
    'assets/greedy/pizza_result.png',
    'assets/greedy/drum_stick_result.png',
    'assets/greedy/burger_result.png',
    'assets/greedy/apple_result.png',
    'assets/greedy/corn_result.png',
    'assets/greedy/grapes_result.png',
    'assets/greedy/lemon_result.png',
  ];

  final String _saladImagePath = 'assets/greedy/salad.png';
  final String _pizzaImagePath = 'assets/greedy/pizza.png';
  final _CenterItemConfig _centerConfig = _CenterItemConfig(
    assetPath: 'assets/greedy/greedy_icon.jpeg',
    sizeFactor: 0.310,
    offsetXFactor: -0.005,
    offsetYFactor: -0.000,
  );

  List<_LeafItemConfig> _leafConfigs() => [
    _LeafItemConfig(
      assetPath: 'assets/greedy/bbq_45.png',
      sizeFactor: 0.26,
      radiusFactor: 0.368,
      angleDegrees: -90,
      multiplier: 45,
    ),
    _LeafItemConfig(
      assetPath: 'assets/greedy/pizza_25.png',
      sizeFactor: 0.265,
      radiusFactor: 0.369,
      angleDegrees: -45.4,
      multiplier: 25,
    ),
    _LeafItemConfig(
      assetPath: 'assets/greedy/drum_stick.png',
      sizeFactor: 0.26,
      radiusFactor: 0.368,
      angleDegrees: 0.7,
      multiplier: 15,
    ),
    _LeafItemConfig(
      assetPath: 'assets/greedy/burger.png',
      sizeFactor: 0.26,
      radiusFactor: 0.370,
      angleDegrees: 44.8,
      multiplier: 10,
    ),
    _LeafItemConfig(
      assetPath: 'assets/greedy/apple_5.png',
      sizeFactor: 0.26,
      radiusFactor: 0.37,
      angleDegrees: 90,
      multiplier: 5,
    ),
    _LeafItemConfig(
      assetPath: 'assets/greedy/carrot_5.png',
      sizeFactor: 0.26,
      radiusFactor: 0.37,
      angleDegrees: 135.5,
      multiplier: 5,
    ),
    _LeafItemConfig(
      assetPath: 'assets/greedy/grapes.png',
      sizeFactor: 0.26,
      radiusFactor: 0.37,
      angleDegrees: 180.5,
      multiplier: 5,
    ),
    _LeafItemConfig(
      assetPath: 'assets/greedy/lemon.png',
      sizeFactor: 0.26,
      radiusFactor: 0.372,
      angleDegrees: -135,
      multiplier: 5,
    ),
  ];

  @override
  void initState() {
    super.initState();
    // [NEW] Sync clock before initializing listeners
    _syncClock().then((_) {
      if (mounted) _initGameListeners();
    });
  }

  // [NEW] Server Time Sync Function
  Future<void> _syncClock() async {
    try {
      final startTime = DateTime.now().millisecondsSinceEpoch;
      final callable = FirebaseFunctions.instance.httpsCallable('getServerTime');
      final result = await callable.call();
      final int serverTime = result.data['time'];
      final endTime = DateTime.now().millisecondsSinceEpoch;

      final int latency = (endTime - startTime) ~/ 2;
      final int trueServerTime = serverTime + latency;

      setState(() {
        _clockOffset = trueServerTime - endTime;
        _isClockSynced = true;
      });
      debugPrint("[GREEDY_LOG] BottomSheet Clock Synced! Device is off by: $_clockOffset ms");
    } catch (e) {
      debugPrint("[GREEDY_LOG] BottomSheet Clock sync failed: $e");
    }
  }

  void _initGameListeners() {
    _controlsSubscription = _gameService.getGameControlsStream().listen((controlSnap) {
      if (!controlSnap.exists) {
        if (mounted) setState(() => _gameStatus = "stopped");
        return;
      }
      final controls = controlSnap.data() as Map<String, dynamic>;

      final String serverRoundId = (controls['currentRoundId'] ?? 0).toString();
      final String gameStatus = controls['status'] ?? 'stopped';

      final bool isAutoPaused = controls['isAutoPaused'] ?? false;
      if (gameStatus == 'stopped' && isAutoPaused) {
        if (mounted) setState(() => _gameStatus = "auto-paused");
        _triggerAutoStart();
      } else {
        if (mounted) setState(() => _gameStatus = gameStatus);
      }

      final List<dynamic> participantsList = controls['participants'] ?? [];
      final newParticipants = participantsList.map((p) => GameParticipant.fromMap(p as Map<String, dynamic>)).toList();

      if (mounted) {
        setState(() {
          _gameParticipants = newParticipants;
        });
      }

      if (_currentRoundId != serverRoundId) {
        if (mounted) {
          setState(() {
            _currentRoundId = serverRoundId;
            _myBets.clear();
            _totalBets.clear(); // [NEW] Clear total bets
            _hasUnsavedChanges = false; // [NEW] Reset dirtiness

            // [NEW] Reset spoiler prevention
            _isAnimatingResult = false;
            _pendingHistory = null;

            _localCountdownSeconds = 0;
            _lastKnownPhase = '';
            _serverWinningIndex = -1;
            _isAutoStarting = false;

            _syncBetsTimer?.cancel();
            _countdownTimer?.cancel();
            _spinTimer?.cancel();
            _spinTimer = null;
          });
        }

        _listenToRound(serverRoundId);
        _listenToMyBets(serverRoundId);
      }
    });

    _profileSubscription = ProfileService.getUserProfileStream(_userId).listen((profileSnap) {
      if (profileSnap.exists) {
        final data = profileSnap.data() as Map<String, dynamic>;

        if (_myParticipantMap == null) {
          _myParticipantMap = {
            'userId': _userId,
            'userName': data['displayName'] ?? 'Unknown',
            'userPicture': data['photoUrl'],
          };

          _gameService.joinGameRoom(_myParticipantMap!).catchError((e) => debugPrint("[GREEDY_LOG] Error joining room: $e"));
        }

        if (mounted) {
          setState(() {
            // [MODIFIED] Only update balance if we aren't actively betting/syncing
            if (!_hasUnsavedChanges && !_isSyncing) {
              _myBalance = data['balance'] ?? 0;
            }
            _todaysRevenue = data['todaysRevenue'] ?? 0;
          });
        }
      }
    });

    _historySubscription = _gameService.getGameHistoryStream().listen((historySnap) {
      final history = historySnap.docs.map((doc) => doc['winningIndex'] as int).toList().reversed.toList();

      // [NEW] SPOILER PREVENTION
      if (_currentPhase == 'spinning' || _isAnimatingResult) {
        _pendingHistory = history;
      } else {
        if (mounted) {
          setState(() {
            _gameHistory = history;
          });
        }
      }
    });
  }

  void _listenToRound(String roundId) {
    _roundSubscription?.cancel();
    _roundSubscription = _gameService.getGameRoundStream(roundId).listen((roundSnap) async {
      if (!roundSnap.exists) {
        if (mounted) setState(() => _currentPhase = "waiting");
        return;
      }

      final roundData = roundSnap.data() as Map<String, dynamic>?;

      // [NEW] Parse Total Bets
      if (roundData != null && roundData.containsKey('totalBets')) {
        final serverTotalBets = roundData['totalBets'] as Map<String, dynamic>? ?? {};
        final Map<int, int> newTotalBets = {};
        serverTotalBets.forEach((key, value) {
          if (key.startsWith('leaf_')) {
            final int leafIndex = int.parse(key.split('_')[1]);
            newTotalBets[leafIndex] = (value as num).toInt();
          }
        });

        if (mounted) {
          setState(() {
            _totalBets.clear();
            _totalBets.addAll(newTotalBets);
          });
        }
      }

      final String phase = roundData?['phase'] ?? 'waiting';
      final int serverCountdown = roundData?['countdown'] ?? 0;
      final Timestamp? serverTimestamp = roundData?['timestamp'];
      final int winningIndex = roundData?['winningIndex'] ?? -1;

      if (_lastKnownPhase != phase) {
        final String previousPhase = _lastKnownPhase;
        _lastKnownPhase = phase;

        if (mounted) {
          setState(() => _currentPhase = phase);
        }

        switch (phase) {
          case 'betting':
            _spinTimer?.cancel();
            _spinTimer = null;
            _serverWinningIndex = -1;
            if (serverTimestamp != null) {
              _startCountdownTimer(serverTimestamp.toDate(), serverCountdown);
            }
            break;

          case 'spinning':
            _countdownTimer?.cancel();
            _countdownTimer = null;
            if (mounted) setState(() => _localCountdownSeconds = 0);
            _syncBetsTimer?.cancel();

            if (_spinTimer == null) {
              _startConstantSpin();
            }
            break;

          case 'result':
            _countdownTimer?.cancel();
            _countdownTimer = null;
            if (mounted) setState(() => _localCountdownSeconds = 0);

            if (winningIndex != -1 && _serverWinningIndex != winningIndex) {
              _serverWinningIndex = winningIndex;

              // [NEW] Lock history updates
              _isAnimatingResult = true;

              _startLandingSpin(winningIndex);

              if (previousPhase == 'spinning') {
                await Future.delayed(const Duration(seconds: 1));
                _showResultBottomSheet(winningIndex);
              }
            }
            break;
        }
      }
    });
  }

  void _listenToMyBets(String roundId) {
    _betsSubscription?.cancel();
    _betsSubscription = _gameService.getMyBetsStream(roundId).listen((betSnap) {
      // [MODIFIED] Ignore server updates if user is tapping locally
      if (_hasUnsavedChanges || _isSyncing) {
        return;
      }

      if (betSnap.exists) {
        final serverBets = (betSnap.data() as Map<String, dynamic>?) ?? {};

        _myBets.clear();
        serverBets.forEach((key, value) {
          final int leafIndex = int.parse(key.split('_')[1]);
          _myBets[leafIndex] = value as int;
        });
        if (mounted) setState(() {});
      } else {
        _myBets.clear();
        if (mounted) setState(() {});
      }
    });
  }

  void _showResultBottomSheet(int winningIndex) async {
    if (!mounted) return;

    final leafConfig = _leafConfigs()[winningIndex];
    final int multiplier = leafConfig.multiplier;
    final int winningBet = _myBets[winningIndex] ?? 0;
    final int totalEarnings = winningBet * multiplier;
    final int totalBets = _myBets.values.fold(0, (prev, amount) => prev + amount);

    final List<TopEarner> topEarnersData = await _gameService.getTopEarners(_currentRoundId, winningIndex);

    final participantMap = <String, GameParticipant>{};
    for (var p in _gameParticipants) {
      participantMap[p.userId] = p;
    }

    final List<DisplayEarner> topEarnersList = [];
    for (var earner in topEarnersData) {
      final participant = participantMap[earner.userId];
      if (participant != null) {
        topEarnersList.add(
          DisplayEarner(
            userId: earner.userId,
            name: participant.userName,
            pictureUrl: participant.userPicture ?? "",
            earnings: earner.winningBet * multiplier,
          ),
        );
      }
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GameResultBottomSheet(
          roundId: _currentRoundId,
          winningIndex: winningIndex,
          resultImagePath: _resultImages[winningIndex],
          totalEarnings: totalEarnings,
          totalBets: totalBets,
          topEarners: topEarnersList,
        );
      },
    );
  }

  @override
  void dispose() {
    if (_myParticipantMap != null) {
      _gameService.leaveGameRoom(_myParticipantMap!).catchError((e) => debugPrint("Error leaving room: $e"));
    }
    _countdownTimer?.cancel();
    _spinTimer?.cancel();
    _syncBetsTimer?.cancel();
    _controlsSubscription?.cancel();
    _roundSubscription?.cancel();
    _betsSubscription?.cancel();
    _profileSubscription?.cancel();
    _historySubscription?.cancel();
    super.dispose();
  }

  String _formatCurrency(int amount) {
    return NumberFormat.decimalPattern().format(amount);
  }

  String _formatBetAmount(int amount) {
    if (amount >= 1000000) {
      double value = amount / 1000000.0;
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}m';
    }
    if (amount >= 1000) {
      double value = amount / 1000.0;
      return '${value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1)}k';
    }
    return amount.toString();
  }

  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: isError ? Colors.red[700] : Colors.amber[800],
        duration: const Duration(seconds: 2),
      ),
    );
  }

  //
  // --- ROBUST BETTING & AUTO-START LOGIC ---
  //

  Future<void> _triggerAutoStart() async {
    if (_isAutoStarting) return;
    setState(() => _isAutoStarting = true);

    try {
      // [NEW] Call the backend to safely wake the game
      await _gameService.wakeUpGame();
      debugPrint("[GREEDY_LOG] BottomSheet: Auto-start signal sent successfully");
    } catch (e) {
      debugPrint("[GREEDY_LOG] BottomSheet: Error triggering auto-start: $e");
    } finally {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _isAutoStarting = false);
        }
      });
    }
  }

  void _onBet(String currentRoundId, String phase, int leafIndex) {
    if (phase != 'betting') {
      if (_gameStatus == 'auto-paused') {
        _showToast("Game is waking up, please wait...", isError: false);
      } else {
        _showToast("Betting time is over!", isError: true);
      }
      return;
    }
    if (_myBalance < _selectedCoinValue) {
      _showToast("Not enough balance!", isError: true);
      return;
    }

    setState(() {
      _hasUnsavedChanges = true;
      _myBalance -= _selectedCoinValue;
      _myBets[leafIndex] = (_myBets[leafIndex] ?? 0) + _selectedCoinValue;
    });

    _triggerDebouncedSync();
  }

  void _onRemoveBet(String currentRoundId, String phase, int leafIndex) {
    if (phase != 'betting') return;

    final int currentBetOnLeaf = _myBets[leafIndex] ?? 0;
    if (currentBetOnLeaf == 0) return;

    setState(() {
      _hasUnsavedChanges = true;
      _myBalance += currentBetOnLeaf;
      _myBets.remove(leafIndex);
    });

    _triggerDebouncedSync();
  }

  void _triggerDebouncedSync() {
    _syncBetsTimer?.cancel();
    // [MODIFIED] Reduced to 300ms for snappier sync
    _syncBetsTimer = Timer(const Duration(milliseconds: 300), () {
      _syncBetsToServer();
    });
  }

  Future<void> _syncBetsToServer() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);

    final betsSnapshot = Map<int, int>.from(_myBets);

    try {
      await _gameService.setBets(_currentRoundId, betsSnapshot);

      if (mounted) {
        // [NEW] Recursion equality check
        bool isEqual = true;
        if (_myBets.length != betsSnapshot.length) {
          isEqual = false;
        } else {
          _myBets.forEach((key, value) {
            if (betsSnapshot[key] != value) isEqual = false;
          });
        }

        if (isEqual) {
          setState(() {
            _isSyncing = false;
            _hasUnsavedChanges = false;
          });
        } else {
          setState(() => _isSyncing = false);
          _triggerDebouncedSync();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _hasUnsavedChanges = false;
        });
        _showToast(e.toString().replaceFirst("Exception: ", ""), isError: true);
      }
    }
  }

  // --- ANIMATIONS & TIMERS ---

  void _startConstantSpin() {
    _spinTimer?.cancel();
    _spinTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _animationLeafIndex = (_animationLeafIndex + 1) % 8;
      });
    });
  }

  void _startLandingSpin(int finalIndex) {
    _spinTimer?.cancel();
    final int startIndex = _animationLeafIndex;
    final totalLeaves = _leafConfigs().length;
    final int ticksToWinner = (totalLeaves - startIndex + finalIndex) % totalLeaves;
    final int totalTicks = ticksToWinner + totalLeaves; // Smooth landing
    final Duration tickDuration = const Duration(milliseconds: 100);

    _spinTimer = Timer.periodic(tickDuration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final bool isDone = (timer.tick >= totalTicks);

      if (isDone) {
        timer.cancel();
        _spinTimer = null;
        setState(() {
          _animationLeafIndex = finalIndex;

          // [NEW] Animation Finished. Apply buffered history.
          _isAnimatingResult = false;
          if (_pendingHistory != null) {
            _gameHistory = _pendingHistory!;
            _pendingHistory = null;
          }
        });
      } else {
        setState(() {
          _animationLeafIndex = (startIndex + timer.tick) % totalLeaves;
        });
      }
    });
  }

  // [MODIFIED] Integrates offset for accurate UI clock
  void _startCountdownTimer(DateTime serverStartTime, int totalDuration) {
    _countdownTimer?.cancel();

    _countdownTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final nowLocal = DateTime.now();
      final nowCorrected = nowLocal.add(Duration(milliseconds: _clockOffset));
      final difference = nowCorrected.difference(serverStartTime);

      final int secondsPassed = difference.inSeconds;
      int secondsRemaining = totalDuration - secondsPassed;

      if (secondsRemaining < 0) secondsRemaining = 0;
      if (secondsRemaining > totalDuration) secondsRemaining = totalDuration;

      if (mounted) {
        setState(() {
          _localCountdownSeconds = secondsRemaining;
        });
      }

      if (secondsRemaining == 0) {
        timer.cancel();
        _countdownTimer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          // image: DecorationImage(image: const AssetImage("assets/greedy/greedy_bg.webp"), fit: BoxFit.cover),
          gradient: AppColors.backgroundGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(children: [Expanded(child: _buildGameContent())]),
        ),
      ),
    );
  }

  Widget _buildGameContent() {
    if (_gameStatus == "loading") {
      return const Center(child: CircularProgressIndicator());
    }

    if (_gameStatus == 'auto-paused') {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_gameStatus != 'running_v2') {
      return const Center(
        child: Text("Game is currently offline.", style: TextStyle(color: Colors.white, fontSize: 18)),
      );
    }

    return Column(
      children: [
        _buildTopBar(),
        Expanded(
          child: Stack(
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: _buildSaladPizzaRow()),
              ),
              // Game wheel centered
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double boardSize = constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth * 0.95
                        : constraints.maxHeight * 0.95;
                    return _buildGameWheel(
                      boardSize: boardSize,
                      phase: _currentPhase,
                      currentRoundId: _currentRoundId,
                      winningIndex: _serverWinningIndex,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                _buildRankingHistoryRow(),
                const SizedBox(height: 16),
                _buildResultRow(),
                const SizedBox(height: 16),
                _buildCoinListRow(_currentPhase),
                const SizedBox(height: 16),
                _buildBalanceRow(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 8, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [_buildRoundCounter(_currentRoundId), _buildParticipantCounter(_gameParticipants)],
      ),
    );
  }

  Widget _buildRoundCounter(String roundId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.pink.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Round: ${int.parse(roundId) + 1}',
        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.normal),
      ),
    );
  }

  Widget _buildParticipantCounter(List<GameParticipant> participants) {
    return GestureDetector(
      onTap: () {
        showGameParticipantsBottomSheet(context, participants: participants, currentUserId: _userId);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.pink.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.person_2_fill, color: Colors.amber, size: 18),
            const SizedBox(width: 6),
            Text(
              participants.length.toString(),
              style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameWheel({
    required double boardSize,
    required String phase,
    required String currentRoundId,
    required int winningIndex,
  }) {
    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(boardBackgroundImage, width: boardSize, height: boardSize, fit: BoxFit.contain),
          ..._leafConfigs().asMap().entries.map((entry) {
            final int index = entry.key;
            final _LeafItemConfig config = entry.value;

            final double angle = config.angleDegrees * (math.pi / 180);
            final double radius = boardSize * config.radiusFactor;
            final double size = boardSize * config.sizeFactor;

            bool isHighlighted;
            if (phase == 'betting') {
              isHighlighted = true;
            } else {
              isHighlighted = (index == _animationLeafIndex);
            }

            final int betAmount = _myBets[index] ?? 0;
            final int totalBetAmount = _totalBets[index] ?? 0; // [NEW] Fetch total bet amount

            return Transform(
              transform: Matrix4.translationValues(radius * math.cos(angle), radius * math.sin(angle), 0.0),
              // [UPDATED] Pass the totalBetAmount
              child: _buildGameItem(
                config,
                index,
                size,
                isHighlighted,
                betAmount,
                totalBetAmount,
                currentRoundId,
                phase,
              ),
            );
          }),
          Transform(
            transform: Matrix4.translationValues(
              boardSize * _centerConfig.offsetXFactor,
              boardSize * _centerConfig.offsetYFactor,
              0.0,
            ),
            child: _buildCenterDisplay(
              _centerConfig.assetPath,
              boardSize * _centerConfig.sizeFactor,
              phase,
              winningIndex,
              _localCountdownSeconds,
            ),
          ),
        ],
      ),
    );
  }

  // [UPDATED] Signature now requires totalBetAmount and implements conditional overlay
  Widget _buildGameItem(
    _LeafItemConfig config,
    int index,
    double size,
    bool isHighlighted,
    int betAmount,
    int totalBetAmount,
    String currentRoundId,
    String phase,
  ) {
    return InkWell(
      onTap: () => _onBet(currentRoundId, phase, index),
      onLongPress: () => _onRemoveBet(currentRoundId, phase, index),
      child: SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Image.asset(config.assetPath, fit: BoxFit.cover),

              // Spinning highlight animation layer
              AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                color: isHighlighted ? Colors.transparent : Colors.black.withValues(alpha: 0.5),
              ),

              // Text and Dark Overlay Logic
              if (betAmount > 0 || totalBetAmount > 0)
                Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    // ONLY show the dark overlay if YOU bet
                    color: betAmount > 0 ? Colors.black.withValues(alpha: 0.6) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'x${config.multiplier}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          height: 1.2,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
                        ),
                      ),
                      if (betAmount > 0)
                        Text(
                          'You: ${_formatBetAmount(betAmount)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            height: 1.2,
                            shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
                          ),
                        ),
                      if (totalBetAmount > 0)
                        Text(
                          'Total: ${_formatBetAmount(totalBetAmount)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            height: 1.2,
                            shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1))],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterDisplay(String assetPath, double size, String phase, int winningIndex, int localCountdown) {
    String centerText = '';
    if (phase == 'betting') {
      centerText = "$localCountdown";
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        image: DecorationImage(image: AssetImage(assetPath), fit: BoxFit.contain),
      ),
      child: Center(
        child: Text(
          centerText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))],
          ),
        ),
      ),
    );
  }

  Widget _buildSaladPizzaRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [_buildFoodImage(_saladImagePath, "SALAD"), _buildFoodImage(_pizzaImagePath, "PIZZA")],
    );
  }

  Widget _buildFoodImage(String assetPath, String label) {
    return Column(
      children: [
        Image.asset(
          assetPath,
          height: 50,
          errorBuilder: (ctx, err, stack) => const Icon(Icons.fastfood, color: Colors.white, size: 80),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildRankingHistoryRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.leaderboard, color: Colors.white),
              label: const Text(
                "Today Ranking",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.pinkLight.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.history, color: Colors.white),
              label: const Text(
                "Your History",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: AppColors.pink.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.pink.withValues(alpha: 0.3)),
      ),
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Result:",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: (_gameHistory.isEmpty)
                ? const Text("Game history will appear here.", style: TextStyle(color: Colors.white70, fontSize: 12))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _gameHistory.reversed.map((winningIndex) {
                        if (winningIndex < 0 || winningIndex >= _resultImages.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.0),
                            child: Icon(Icons.error, color: Colors.red, size: 40),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Image.asset(_resultImages[winningIndex], fit: BoxFit.contain, height: 40, width: 40),
                        );
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinListRow(String phase) {
    final bool isBettingTime = (phase == 'betting');

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 60.0),
      child: Row(
        children: _coinValues.entries.map((entry) {
          final String path = entry.key;
          final int value = entry.value;
          final bool isSelected = _selectedCoinValue == value;

          return Expanded(
            child: InkWell(
              onTap: isBettingTime
                  ? () {
                      setState(() {
                        _selectedCoinValue = value;
                      });
                    }
                  : null,
              child: Opacity(
                opacity: isBettingTime ? 1.0 : 0.5,
                child: Container(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.amber, width: 3) : null,
                    boxShadow: isSelected
                        ? [const BoxShadow(color: Colors.amber, blurRadius: 10, spreadRadius: 2)]
                        : [],
                  ),
                  child: Image.asset(
                    path,
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.monetization_on, color: Colors.white, size: 60),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBalanceRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _buildBalanceDisplay(title: "Balance", amount: _formatCurrency(_myBalance)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildBalanceDisplay(title: "Today's Revenue", amount: _formatCurrency(_todaysRevenue)),
        ),
      ],
    );
  }

  Widget _buildBalanceDisplay({required String title, required String amount}) {
    const String treasureIconPath = 'assets/greedy/treasure_icon.png';

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (title == "Balance")
          Image.asset(
            treasureIconPath,
            height: 44,
            width: 44,
            errorBuilder: (ctx, err, stack) => const Icon(Icons.monetization_on, color: Colors.white, size: 24),
          )
        else
          Text(
            '$title:',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            amount,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ],
    );
  }
}

void showGreedyGameBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: false,
    builder: (context) {
      return const GreedyGameBottomSheet();
    },
  );
}
