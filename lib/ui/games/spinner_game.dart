import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../theme/app_theme.dart';
import '../../data/remote/firebase/profile_services.dart';
import 'bottomsheets/participants_bottomsheet.dart';
import 'bottomsheets/result_bottomsheet.dart';
import '../../data/remote/firebase/fruits_king_service.dart';

class _FruitConfig {
  final String type;
  final String assetPath;

  _FruitConfig({required this.type, required this.assetPath});
}

class FruitsKingPage extends StatefulWidget {
  const FruitsKingPage({super.key});

  @override
  State<FruitsKingPage> createState() => _FruitsKingPageState();
}

class _FruitsKingPageState extends State<FruitsKingPage> {
  int _clockOffset = 0;
  bool _isClockSynced = false;

  final FruitsKingService _gameService = FruitsKingService();
  final String _userId = FirebaseAuth.instance.currentUser!.uid;
  int _myBalance = 0;
  int _todaysRevenue = 0;

  String _gameStatus = "loading";
  String _currentPhase = "waiting";
  String _currentRoundId = "0";
  int _serverWinningIndex = -1;
  String _lastKnownPhase = '';

  int _selectedCoinValue = 100;

  // Betting State
  final Map<String, int> _myBets = {}; // Local Source of Truth
  bool _hasUnsavedChanges = false; // Prevents server stream from overwriting local UI while typing

  // Spoiler Prevention State
  bool _isAnimatingResult = false;
  List<int>? _pendingHistory;

  Map<String, int> _totalBets = {};
  List<GameParticipant> _gameParticipants = [];
  Map<String, dynamic>? _myParticipantMap;
  List<int> _gameHistory = [];

  Timer? _countdownTimer;
  int _localCountdownSeconds = 0;
  Timer? _spinTimer;

  StreamSubscription? _controlsSubscription;
  StreamSubscription? _roundSubscription;
  StreamSubscription? _betsSubscription;
  StreamSubscription? _profileSubscription;
  StreamSubscription? _historySubscription;

  // Performance Optimization: Use ValueNotifier for extreme smoothness
  final ValueNotifier<double> _currentAngle = ValueNotifier<double>(0.0);

  // Simplified betting sync state
  Timer? _syncBetsTimer;
  bool _isSyncing = false;
  bool _isAutoStarting = false;

  final Map<String, _FruitConfig> _fruitConfigs = {
    'orange': _FruitConfig(type: 'orange', assetPath: 'assets/spinner/orange.png'),
    'mango': _FruitConfig(type: 'mango', assetPath: 'assets/spinner/mango.png'),
    'watermelon': _FruitConfig(type: 'watermelon', assetPath: 'assets/spinner/watermelon.png'),
  };

  final List<String> _wheelSegments = ['orange', 'mango', 'watermelon', 'orange', 'mango', 'watermelon'];

  final Map<String, int> _coinValues = {
    'assets/spinner/coin_100.png': 100,
    'assets/spinner/coin_1k.png': 1000,
    'assets/spinner/coin_10k.png': 10000,
    'assets/spinner/coin_50k.png': 50000,
    'assets/spinner/coin_100k.png': 100000,
  };

  final List<String> _resultImages = [
    'assets/spinner/orange.png',
    'assets/spinner/mango.png',
    'assets/spinner/watermelon.png',
    'assets/spinner/orange.png',
    'assets/spinner/mango.png',
    'assets/spinner/watermelon.png',
  ];

  Map<String, ui.Image> _fruitUiImages = {};

  @override
  void initState() {
    WakelockPlus.enable();
    super.initState();
    // Start syncing immediately
    _syncClock();

    _loadFruitImages().then((_) {
      if (mounted) {
        _initGameListeners();
      }
    });
  }

  Future<void> _syncClock() async {
    try {
      final startTime = DateTime.now().millisecondsSinceEpoch;

      // Call the Cloud Function
      final callable = FirebaseFunctions.instance.httpsCallable('getServerTime');
      final result = await callable.call();
      final int serverTime = result.data['time'];

      final endTime = DateTime.now().millisecondsSinceEpoch;

      // Calculate latency (ping) to get closer to "true" time
      // We assume the request took equal time to go up and come down
      final int latency = (endTime - startTime) ~/ 2;

      // The server time WHEN we received the response
      final int trueServerTime = serverTime + latency;

      // Calculate the difference
      setState(() {
        _clockOffset = trueServerTime - endTime;
        _isClockSynced = true;
      });

      debugPrint("Clock Synced! Device is off by: $_clockOffset ms");
    } catch (e) {
      debugPrint("Clock sync failed: $e");
      // Retry logic could go here
    }
  }

  Future<ui.Image> _loadImage(String assetPath) async {
    final ByteData data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Future<void> _loadFruitImages() async {
    Map<String, ui.Image> loadedImages = {};
    for (var entry in _fruitConfigs.entries) {
      final String fruitType = entry.key;
      final String assetPath = entry.value.assetPath;
      try {
        final image = await _loadImage(assetPath);
        loadedImages[fruitType] = image;
      } catch (e) {
        debugPrint('Error loading image $assetPath: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _fruitUiImages = loadedImages;
    });
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
            _hasUnsavedChanges = false; // New round, reset dirtiness

            // Reset spoiler prevention
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
          _gameService.joinGameRoom(_myParticipantMap!).catchError((e) => debugPrint("Error joining: $e"));
        }

        if (mounted) {
          setState(() {
            // Only update balance if we aren't actively betting/syncing
            if (!_hasUnsavedChanges && !_isSyncing) {
              _myBalance = data['balance'] ?? 0;
            }
            _todaysRevenue = data['todaysRevenue'] ?? 0;
          });
        }
      }
    });

    _historySubscription = _gameService.getGameHistoryStream().listen((historySnap) {
      // We get the list from Firestore (Usually newest first)
      final history = historySnap.docs.map((doc) => doc['winningIndex'] as int).toList();

      // [SPOILER PREVENTION]
      // If we are spinning or animating the result, hold the data in buffer.
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

      final String phase = roundData?['phase'] ?? 'waiting';
      final int serverCountdown = roundData?['countdown'] ?? 0;
      final Timestamp? serverTimestamp = roundData?['timestamp'];
      final int winningIndex = roundData?['winningIndex'] ?? -1;

      final Map<String, dynamic> totalBetsData = roundData?['totalBets'] ?? {};
      final newTotalBets = totalBetsData.map((key, value) => MapEntry(key, value as int));

      if (mounted) {
        setState(() {
          _totalBets = newTotalBets;
        });
      }

      if (_lastKnownPhase != phase) {
        _lastKnownPhase = phase;
        if (mounted) setState(() => _currentPhase = phase);

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

            if (_spinTimer == null) {
              _startConstantSpinAnimation();
            }
            break;

          case 'result':
            _countdownTimer?.cancel();
            _countdownTimer = null;
            if (mounted) setState(() => _localCountdownSeconds = 0);

            if (winningIndex != -1 && _serverWinningIndex != winningIndex) {
              _serverWinningIndex = winningIndex;

              // [LOCK] Lock the history updates so user doesn't see result before wheel stops
              _isAnimatingResult = true;

              _startLandingSpinAnimation(winningIndex);
            }
            break;
        }
      }
    });
  }

  void _listenToMyBets(String roundId) {
    _betsSubscription?.cancel();
    _betsSubscription = _gameService.getMyBetsStream(roundId).listen((betSnap) {
      // If we have local unsaved changes, ignore the server to prevent "unmarking" glitches.
      if (_hasUnsavedChanges || _isSyncing) {
        return;
      }

      final serverBets = (betSnap.data() as Map<String, dynamic>?) ?? {};

      _myBets.clear();
      serverBets.forEach((key, value) {
        _myBets[key] = value as int;
      });
      if (mounted) setState(() {});
    });
  }

  void _showResultBottomSheet(int winningIndex) async {
    if (!mounted) return;

    final String winningFruit = _wheelSegments[winningIndex];
    const double payoutMultiplier = 2.9;
    final int winningBet = _myBets[winningFruit] ?? 0;
    final int totalEarnings = (winningBet * payoutMultiplier).floor();
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
            earnings: (earner.winningBet * payoutMultiplier).floor(),
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

  void _startCountdownTimer(DateTime serverStartTime, int totalDuration) {
    _countdownTimer?.cancel();

    // Run faster (50ms) for smoother UI updates
    _countdownTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      // 1. Get Local Time
      final nowLocal = DateTime.now();

      // 2. APPLY THE OFFSET (The Magic Fix)
      // If device is 3s slow, this adds 3s to match server
      final nowCorrected = nowLocal.add(Duration(milliseconds: _clockOffset));

      // 3. Calculate difference using the CORRECTED time
      final difference = nowCorrected.difference(serverStartTime);

      final int secondsPassed = difference.inSeconds;
      int secondsRemaining = totalDuration - secondsPassed;

      // Clamp values (Visual safety)
      if (secondsRemaining < 0) secondsRemaining = 0;
      if (secondsRemaining > totalDuration) secondsRemaining = totalDuration;

      // Optimization: Only setState if the actual second value changed to prevent heavy UI jitter
      if (secondsRemaining != _localCountdownSeconds) {
        if (mounted) {
          setState(() {
            _localCountdownSeconds = secondsRemaining;
          });
        }
      }

      if (secondsRemaining == 0) {
        timer.cancel();
        _countdownTimer = null;
      }
    });
  }

  double _calculateLandingAngle(int winningIndex) {
    final int totalSegments = _wheelSegments.length;
    final double segmentAngle = 2 * math.pi / totalSegments;
    final double targetIndexAngle = (totalSegments - winningIndex) * segmentAngle;
    final double jitter = (math.Random().nextDouble() - 0.5) * segmentAngle * 0.8;

    double target = (targetIndexAngle + jitter) % (2 * math.pi);
    if (target < 0) target += 2 * math.pi;

    return target;
  }

  void _startConstantSpinAnimation() {
    _spinTimer?.cancel();
    // 16ms tick is ~60fps, giving a much smoother feel
    _spinTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      // Speed increased to 0.18 for a faster look
      _currentAngle.value += 0.10;
    });
  }

  void _startLandingSpinAnimation(int winningIndex) {
    _spinTimer?.cancel();

    const double currentVelocityPerTick = 0.10; // Increased and matched to constant spin
    const int tickDurationMs = 16; // 16ms aligns better with 60Hz displays

    final double startAngle = _currentAngle.value;
    final double targetAngleRaw = _calculateLandingAngle(winningIndex);

    final double currentNormalized = startAngle % (2 * math.pi);
    double distanceToTarget = targetAngleRaw - currentNormalized;
    if (distanceToTarget < 0) {
      distanceToTarget += 2 * math.pi;
    }

    double finalTotalDistance = distanceToTarget;
    double calculatedDurationTicks = (3 * finalTotalDistance) / currentVelocityPerTick;

    // Adjusted tick ceiling to account for faster speed
    while (calculatedDurationTicks < 150) {
      finalTotalDistance += 2 * math.pi;
      calculatedDurationTicks = (3 * finalTotalDistance) / currentVelocityPerTick;
    }

    final int totalTicks = calculatedDurationTicks.toInt();
    final double finalTargetAngle = startAngle + finalTotalDistance;
    int currentTick = 0;

    _spinTimer = Timer.periodic(Duration(milliseconds: tickDurationMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      currentTick++;

      if (currentTick >= totalTicks) {
        timer.cancel();
        _spinTimer = null;

        _currentAngle.value = finalTargetAngle;

        if (mounted) {
          setState(() {
            // [UNLOCK] Animation Finished. Apply buffered history now.
            _isAnimatingResult = false;
            if (_pendingHistory != null) {
              _gameHistory = _pendingHistory!;
              _pendingHistory = null;
            }
          });

          debugPrint("result: $winningIndex");
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _gameStatus == 'running_v4') {
              _showResultBottomSheet(winningIndex);
            }
          });
        }
      } else {
        final double t = currentTick / totalTicks;
        final double easeOut = 1 - math.pow(1 - t, 3).toDouble();

        _currentAngle.value = startAngle + (finalTotalDistance * easeOut);
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    if (_myParticipantMap != null) {
      _gameService.leaveGameRoom(_myParticipantMap!).catchError((e) => debugPrint("Error leaving room: $e"));
    }
    _currentAngle.dispose();
    _countdownTimer?.cancel();
    _spinTimer?.cancel();
    _syncBetsTimer?.cancel();
    _controlsSubscription?.cancel();
    _roundSubscription?.cancel();
    _betsSubscription?.cancel();
    _profileSubscription?.cancel();
    _historySubscription?.cancel();
    for (var image in _fruitUiImages.values) {
      image.dispose();
    }
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  //
  // --- ROBUST BETTING LOGIC ---
  //

  Future<void> _triggerAutoStart() async {
    if (_isAutoStarting) return;
    setState(() => _isAutoStarting = true);

    try {
      await _gameService.wakeUpGame();
      debugPrint("Auto-start signal sent successfully");
    } catch (e) {
      debugPrint("Error triggering auto-start: $e");
    } finally {
      // Cooldown to prevent spamming
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _isAutoStarting = false);
      });
    }
  }

  void _onBet(String fruitType) {
    if (_currentPhase != 'betting') {
      if (_gameStatus == 'auto-paused') {
        _showToast("Game is waking up...", isError: false);
      } else {
        _showToast("Betting time is over!", isError: true);
      }
      return;
    }
    if (_selectedCoinValue == 0) {
      _showToast("Select a coin!", isError: true);
      return;
    }
    if (_myBalance < _selectedCoinValue) {
      _showToast("Not enough balance!", isError: true);
      return;
    }

    setState(() {
      _hasUnsavedChanges = true;
      _myBalance -= _selectedCoinValue;
      _myBets[fruitType] = (_myBets[fruitType] ?? 0) + _selectedCoinValue;
    });

    _triggerDebouncedSync();
  }

  void _onRemoveBet(String fruitType) {
    if (_currentPhase != 'betting') return;

    final int currentBetOnFruit = _myBets[fruitType] ?? 0;
    if (currentBetOnFruit == 0) return;

    setState(() {
      _hasUnsavedChanges = true;
      _myBalance += currentBetOnFruit;
      _myBets.remove(fruitType);
    });

    _triggerDebouncedSync();
  }

  void _triggerDebouncedSync() {
    _syncBetsTimer?.cancel();
    _syncBetsTimer = Timer(const Duration(milliseconds: 300), () {
      _syncBetsToServer();
    });
  }

  Future<void> _syncBetsToServer() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    final betsSnapshot = Map<String, int>.from(_myBets);

    final betsToSend = {
      'orange': betsSnapshot['orange'] ?? 0,
      'mango': betsSnapshot['mango'] ?? 0,
      'watermelon': betsSnapshot['watermelon'] ?? 0,
    };

    try {
      debugPrint("[FRUITS_LOG] Syncing bets: $betsToSend");
      await _gameService.setBets(_currentRoundId, betsToSend);
      debugPrint("[FRUITS_LOG] Sync successful.");

      if (mounted) {
        // Recursion check: Did the user tap while we were uploading?
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
          debugPrint("[FRUITS_LOG] Data changed during upload. Retrying...");
          setState(() => _isSyncing = false);
          _triggerDebouncedSync();
        }
      }
    } catch (e) {
      debugPrint("[FRUITS_LOG] Sync failed: $e");
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _hasUnsavedChanges = false;
        });
        _showToast(e.toString().replaceFirst("Exception: ", ""), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLoading = _gameStatus == "loading" || _gameStatus == "auto-paused" || _fruitUiImages.isEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Fruits King',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1))],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: _buildGameContent(),
      ),
    );
  }

  Widget _buildGameContent() {
    if (_gameStatus == "loading" || _fruitUiImages.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_gameStatus == 'auto-paused') {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_gameStatus != 'running_v4') {
      return const Center(
        child: Text("Game is currently offline.", style: TextStyle(color: Colors.white, fontSize: 18)),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double boardSize = math.min(constraints.maxWidth, constraints.maxHeight) * 0.9;
                return _buildGameWheel(boardSize);
              },
            ),
          ),
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildBettingOptions(),
                  const SizedBox(height: 10),
                  _buildResultRow(),
                  const SizedBox(height: 10),
                  _buildCoinListRow(),
                  const SizedBox(height: 10),
                  _buildBalanceRow(),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
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

  Widget _buildGameWheel(double boardSize) {
    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Using ValueListenableBuilder isolates rotation state changes, avoiding lag
          ValueListenableBuilder<double>(
            valueListenable: _currentAngle,
            builder: (context, angle, child) {
              return Transform.rotate(angle: angle, child: _buildWheelBody(boardSize));
            },
          ),
          Align(alignment: Alignment.topCenter, child: _buildWheelPointer(boardSize)),
          _buildCenterDisplay(boardSize * 0.28),
        ],
      ),
    );
  }

  Widget _buildWheelPointer(double boardSize) {
    return Padding(
      padding: EdgeInsets.only(top: boardSize * 0.01),
      child: CustomPaint(size: Size(boardSize * 0.1, boardSize * 0.12), painter: _PointerPainter()),
    );
  }

  Widget _buildWheelBody(double boardSize) {
    return Container(
      width: boardSize,
      height: boardSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.blue.shade300, width: boardSize * 0.04),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 2)],
      ),
      child: CustomPaint(
        painter: _WheelPainter(
          segmentColors: [
            Colors.pinkAccent.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.8),
            Colors.pinkAccent.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.8),
            Colors.pinkAccent.withValues(alpha: 0.8),
            Colors.white.withValues(alpha: 0.8),
          ],
          fruitImages: _fruitUiImages,
          wheelSegments: _wheelSegments,
        ),
      ),
    );
  }

  Widget _buildCenterDisplay(double size) {
    String centerText = '';
    if (_currentPhase == 'betting') {
      centerText = '$_localCountdownSeconds';
    } else if (_currentPhase == 'spinning') {
      centerText = '...';
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.red.shade800,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Center(
        child: Text(
          centerText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4, offset: Offset(2, 2))],
          ),
        ),
      ),
    );
  }

  Widget _buildBettingOptions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _fruitConfigs.keys.map((fruitType) {
        return _buildBetItem(_fruitConfigs[fruitType]!);
      }).toList(),
    );
  }

  Widget _buildBetItem(_FruitConfig config) {
    final int betAmount = _myBets[config.type] ?? 0;
    final int totalBetAmount = _totalBets[config.type] ?? 0;
    final bool isBetting = betAmount > 0;

    return InkWell(
      onTap: () => _onBet(config.type),
      onLongPress: () => _onRemoveBet(config.type),
      child: Container(
        width: 110,
        padding: const EdgeInsets.only(bottom: 4, top: 2),
        decoration: BoxDecoration(
          color: isBetting ? Colors.pink.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            strokeAlign: BorderSide.strokeAlignOutside,
            color: isBetting ? Colors.amber : AppColors.pink.withValues(alpha: 0.3),
            width: isBetting ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Image.asset(
              config.assetPath,
              height: 60,
              errorBuilder: (ctx, err, stack) => const Icon(Icons.fastfood, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 8),
            Text(
              "you: ${_formatBetAmount(betAmount)}",
              style: TextStyle(
                color: isBetting ? Colors.amber : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              "total: ${_formatBetAmount(totalBetAmount)}",
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
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
              reverse: false,
              child: Row(
                children: _gameHistory.map((winningIndex) {
                  if (winningIndex < 0 || winningIndex >= _resultImages.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.0),
                      child: Icon(Icons.error, color: Colors.red, size: 30),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Image.asset(_resultImages[winningIndex], fit: BoxFit.contain, height: 30, width: 30),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinListRow() {
    final bool isBettingTime = (_currentPhase == 'betting');

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

class _WheelPainter extends CustomPainter {
  final List<Color> segmentColors;
  final Map<String, ui.Image> fruitImages;
  final List<String> wheelSegments;
  final int segmentCount;

  _WheelPainter({required this.segmentColors, required this.fruitImages, required this.wheelSegments})
      : segmentCount = segmentColors.length,
        assert(segmentColors.length == wheelSegments.length);

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = math.min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double segmentAngle = 2 * math.pi / segmentCount;

    final Paint paint = Paint();
    double startAngle = -math.pi / 2 - segmentAngle / 2;

    for (int i = 0; i < segmentCount; i++) {
      paint.color = segmentColors[i];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, segmentAngle, true, paint);

      final String fruitType = wheelSegments[i];
      final ui.Image? fruitImage = fruitImages[fruitType];

      if (fruitImage != null) {
        _drawImage(canvas, center, startAngle + segmentAngle / 2, radius, fruitImage);
      }

      startAngle += segmentAngle;
    }
  }

  void _drawImage(Canvas canvas, Offset center, double angle, double radius, ui.Image image) {
    final double imageRadius = radius * 0.7;
    final double imageSize = radius * 0.4;
    final double x = center.dx + imageRadius * math.cos(angle);
    final double y = center.dy + imageRadius * math.sin(angle);
    final Offset imageCenter = Offset(x, y);

    canvas.save();
    canvas.translate(imageCenter.dx, imageCenter.dy);
    canvas.rotate(angle + math.pi / 2);
    final Rect destRect = Rect.fromCenter(center: Offset.zero, width: imageSize, height: imageSize);
    final Rect srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    canvas.drawImageRect(image, srcRect, destRect, Paint());
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) {
    return oldDelegate.segmentColors != segmentColors ||
        oldDelegate.fruitImages != fruitImages ||
        oldDelegate.wheelSegments != wheelSegments;
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.blue.shade400
      ..style = PaintingStyle.fill;

    final Path path = Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);

    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}