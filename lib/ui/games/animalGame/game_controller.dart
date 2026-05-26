import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../data/remote/firebase/profile_services.dart';
import '../../streaming/audio_room_page.dart';

class GameController extends ChangeNotifier {
  bool _isDisposed = false;
  int balance = 0;
  int selectedCoinValue = 100;
  int roundTimeRemaining = 8;

  Map<String, dynamic>? activeGameWin;
  bool showGameWinBanner = false;

  void _triggerLocalWinBanner(int winAmount) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    String displayName = 'User';
    String? photoUrl;
    try {
      final doc = await ProfileService.getUserProfile(currentUserId ?? '');
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        displayName = data['displayName'] ?? data['name'] ?? 'User';
        photoUrl = data['photoUrl'] ?? data['profilePic'];
      }
    } catch (e) {
      debugPrint("Error fetching profile for local banner: $e");
    }

    activeGameWin = {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'gameName': 'Animal Game',
      'winAmount': winAmount,
      'bannerType': winAmount >= 550000 ? 'red' : 'blue',
    };
    showGameWinBanner = true;
    notifyListeners();

    Future.delayed(const Duration(seconds: 5), () {
      if (_isDisposed) return;
      showGameWinBanner = false;
      notifyListeners();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_isDisposed) return;
        activeGameWin = null;
        notifyListeners();
      });
    });
  }

  final List<String> animals = ['lion', 'tiger', 'elephant', 'dragon', 'bear', 'hayena', 'deer', 'ocean'];
  final Map<String, int> animalBets = {
    'lion': 0,
    'tiger': 0,
    'elephant': 0,
    'dragon': 0,
    'bear': 0,
    'hayena': 0,
    'deer': 0,
    'ocean': 0,
  };

  final Map<String, int> globalBets = {
    'lion': 0,
    'tiger': 0,
    'elephant': 0,
    'dragon': 0,
    'bear': 0,
    'hayena': 0,
    'deer': 0,
    'ocean': 0,
  };

  final List<int> circularPath = [0, 1, 2, 4, 7, 6, 5, 3];

  GamePhase currentPhase = GamePhase.betting;
  int selectionTimeRemaining = 25;
  int currentHighlightIndex = 0;
  String? currentHighlightedAnimal;
  String? winningAnimal;
  int winAmount = 0;
  int totalBetAmount = 0;
  bool isWin = false;
  bool hasParticipated = false;

  List<String> winHistory = [];

  // Synchronization variables
  Timer? _timer;
  Timer? _animationTimer;
  int _targetIndex = 0;
  double _currentDelay = 500;
  int _roundStartTime = 0;
  int _serverOffset = 0;
  StreamSubscription? _offsetSubscription;
  StreamSubscription? _controlSubscription;
  StreamSubscription? _potsSubscription;
  String _forcedWin = 'AUTO';
  int _lastProcessedRoundId = -1;
  int _lastResultProcessedRoundId = -1;

  // Today's rankings for game wins
  List<Map<String, dynamic>> todayRankings = [];
  bool isLoadingRankings = false;

  GameController() {
    _loadInitialBalance();
    _syncServerTime();
    _listenToAdminControl();
    _startSyncTimer();
  }

  void _syncServerTime() {
    _offsetSubscription = FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((event) {
      if (event.snapshot.value != null) {
        _serverOffset = (event.snapshot.value as int?) ?? 0;
      }
    });
  }

  int getCorrectedTime() {
    return DateTime.now().millisecondsSinceEpoch + _serverOffset;
  }

  void _listenToAdminControl() {
    final ref = FirebaseDatabase.instance.ref('games/animal_game/control');
    ref.get().then((snap) {
      if (!snap.exists) {
        ref.set('AUTO');
      }
    });

    _controlSubscription = ref.onValue.listen((event) {
      final val = event.snapshot.value;
      if (val is String) {
        _forcedWin = val.trim().toUpperCase();
      } else {
        _forcedWin = 'AUTO';
      }

      // Instant win override during betting or gap phase
      if (_lastProcessedRoundId != -1 &&
          (currentPhase == GamePhase.betting || currentPhase == GamePhase.gap)) {
        final seedRandom = Random(_lastProcessedRoundId);
        int target = seedRandom.nextInt(8);

        if (_forcedWin == 'LION') target = _getPathIndexForAnimal('lion');
        else if (_forcedWin == 'TIGER') target = _getPathIndexForAnimal('tiger');
        else if (_forcedWin == 'ELEPHANT') target = _getPathIndexForAnimal('elephant');
        else if (_forcedWin == 'DRAGON') target = _getPathIndexForAnimal('dragon');
        else if (_forcedWin == 'BEAR') target = _getPathIndexForAnimal('bear');
        else if (_forcedWin == 'HAYENA' || _forcedWin == 'HYENA') target = _getPathIndexForAnimal('hayena');
        else if (_forcedWin == 'DEER') target = _getPathIndexForAnimal('deer');
        else if (_forcedWin == 'OCEAN') target = _getPathIndexForAnimal('ocean');

        _targetIndex = target;
      }
    }, onError: (e) {
      debugPrint("Error listening to admin control: $e");
    });
  }

  int _getPathIndexForAnimal(String animal) {
    final int animalIndex = animals.indexOf(animal);
    if (animalIndex == -1) return 0;
    return circularPath.indexOf(animalIndex);
  }

  void _startSyncTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_isDisposed) {
        timer.cancel();
        return;
      }
      _syncGameLoop();
    });
  }

  void _syncGameLoop() {
    final int correctedNow = getCorrectedTime();
    final int secondsIntoRound = (correctedNow ~/ 1000) % 40;
    final int currentRoundId = (correctedNow ~/ 1000) ~/ 40;

    // Detect if a new round has started
    if (currentRoundId != _lastProcessedRoundId) {
      _lastProcessedRoundId = currentRoundId;
      _onNewRoundStarted(currentRoundId);
    }

    if (secondsIntoRound < 25) {
      if (currentPhase != GamePhase.betting) {
        currentPhase = GamePhase.betting;
        winningAnimal = null;
        winAmount = 0;
        totalBetAmount = 0;
        isWin = false;
        hasParticipated = false;
        currentHighlightedAnimal = null;
        currentHighlightIndex = 0;
        animalBets.updateAll((key, value) => 0);
        notifyListeners();
      }
      selectionTimeRemaining = 25 - secondsIntoRound;
      notifyListeners();
    } 
    else if (secondsIntoRound == 25) {
      if (currentPhase != GamePhase.gap) {
        currentPhase = GamePhase.gap;
        notifyListeners();
      }
    } 
    else if (secondsIntoRound >= 26 && secondsIntoRound < 34) {
      if (currentPhase != GamePhase.round) {
        currentPhase = GamePhase.round;
        currentHighlightIndex = 0;
        _roundStartTime = correctedNow;

        // Deterministic target index
        final seedRandom = Random(currentRoundId);
        int target = seedRandom.nextInt(8);

        // Admin override
        if (_forcedWin == 'LION') target = _getPathIndexForAnimal('lion');
        else if (_forcedWin == 'TIGER') target = _getPathIndexForAnimal('tiger');
        else if (_forcedWin == 'ELEPHANT') target = _getPathIndexForAnimal('elephant');
        else if (_forcedWin == 'DRAGON') target = _getPathIndexForAnimal('dragon');
        else if (_forcedWin == 'BEAR') target = _getPathIndexForAnimal('bear');
        else if (_forcedWin == 'HAYENA' || _forcedWin == 'HYENA') target = _getPathIndexForAnimal('hayena');
        else if (_forcedWin == 'DEER') target = _getPathIndexForAnimal('deer');
        else if (_forcedWin == 'OCEAN') target = _getPathIndexForAnimal('ocean');

        _targetIndex = target;
        _currentDelay = 500;
        _startCircularHighlighting();
        notifyListeners();
      }

      int elapsed = correctedNow - _roundStartTime;
      roundTimeRemaining = 8 - (elapsed ~/ 1000);
      if (roundTimeRemaining < 1) roundTimeRemaining = 1;
      notifyListeners();
    } 
    else if (secondsIntoRound == 34) {
      if (currentPhase != GamePhase.result) {
        _animationTimer?.cancel();
        currentPhase = GamePhase.result;

        final int targetAnimalIndex = circularPath[_targetIndex];
        winningAnimal = animals[targetAnimalIndex];
        currentHighlightedAnimal = winningAnimal;

        if (winningAnimal != null && currentRoundId != _lastResultProcessedRoundId) {
          _lastResultProcessedRoundId = currentRoundId;
          winHistory.add(winningAnimal!);
          if (winHistory.length > 15) {
            winHistory.removeAt(0);
          }
        }
        notifyListeners();

        _calculateWinnings();
      }
    } 
    else {
      if (currentPhase != GamePhase.showingResult) {
        currentPhase = GamePhase.showingResult;
        notifyListeners();
      }
    }
  }

  void _onNewRoundStarted(int roundId) {
    selectedCoinValue = 100;
    animalBets.updateAll((key, value) => 0);
    globalBets.updateAll((key, value) => 0);
    winningAnimal = null;
    winAmount = 0;
    totalBetAmount = 0;
    isWin = false;
    hasParticipated = false;
    currentHighlightedAnimal = null;
    currentHighlightIndex = 0;

    _potsSubscription?.cancel();
    _potsSubscription = FirebaseDatabase.instance.ref('games/animal_game/rounds/$roundId/pots').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        for (var animal in animals) {
          globalBets[animal] = (data['pot_$animal'] as num?)?.toInt() ?? 0;
        }
        notifyListeners();
      }
    });

    notifyListeners();
  }

  void _startCircularHighlighting() {
    _animationTimer?.cancel();
    roundTimeRemaining = 8;
    void highlightNext() {
      if (currentPhase != GamePhase.round) return;

      int elapsed = getCorrectedTime() - _roundStartTime;
      roundTimeRemaining = 8 - (elapsed ~/ 1000);
      if (roundTimeRemaining < 1) roundTimeRemaining = 1;
      if (elapsed >= 8000) {
        return;
      }

      int pathIndex = currentHighlightIndex % 8;
      int animalIndex = circularPath[pathIndex];
      currentHighlightedAnimal = animals[animalIndex];
      notifyListeners();

      if (elapsed < 5000) {
        _currentDelay = 500 - (elapsed / 5000 * 200);
      } else {
        double speedUpFactor = (elapsed - 5000) / 3000;
        _currentDelay = 300 - (speedUpFactor * 250);

        if (elapsed > 7500) {
          int targetAnimalIndex = circularPath[_targetIndex];
          if (animalIndex == targetAnimalIndex) {
            return;
          }
        }
      }

      currentHighlightIndex++;
      _animationTimer = Timer(Duration(milliseconds: _currentDelay.toInt()), highlightNext);
    }

    highlightNext();
  }

  Future<void> _loadInitialBalance() async {
    try {
      balance = await ProfileService.getCurrentUserBalance();
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading initial balance: $e");
    }
  }

  void selectCoin(int value) {
    selectedCoinValue = value;
    notifyListeners();
  }

  void placeBet(String animal) {
    if (_isDisposed) return;
    if (currentPhase != GamePhase.betting) return;
    if (balance < selectedCoinValue) return;

    final betValue = selectedCoinValue;
    balance -= betValue;
    ProfileService.topUpBalance(-betValue).catchError((e) {
      debugPrint("Error updating balance on bet: $e");
    });
    animalBets[animal] = (animalBets[animal] ?? 0) + betValue;
    notifyListeners();

    // Increment global pot in RTDB for this round
    final int roundId = _lastProcessedRoundId;
    if (roundId != -1) {
      FirebaseDatabase.instance.ref('games/animal_game/rounds/$roundId/pots').update({
        'pot_$animal': ServerValue.increment(betValue),
      }).catchError((e) {
        debugPrint("Error updating global pot in RTDB: $e");
      });
    }
  }

  void _calculateWinnings() {
    if (_isDisposed) return;
    totalBetAmount = animalBets.values.fold(0, (sum, bet) => sum + bet);
    hasParticipated = totalBetAmount > 0;

    if (winningAnimal != null && hasParticipated) {
      int betAmount = animalBets[winningAnimal] ?? 0;
      if (betAmount > 0) {
        int multiplier = _getMultiplier(winningAnimal!);
        winAmount = betAmount * multiplier;
        balance += winAmount;
        ProfileService.topUpBalance(winAmount).catchError((e) {
          debugPrint("Error crediting winnings: $e");
        });
        isWin = true;
        if (winAmount >= 100000) {
          _triggerLocalWinBanner(winAmount);
          if (AudioRoomPage.currentRoomId != null) {
            ProfileService.recordGameWin(
              roomId: AudioRoomPage.currentRoomId!,
              gameName: 'Animal Game',
              winAmount: winAmount,
            );
          }
        }
      } else {
        winAmount = 0;
        isWin = false;
      }
    } else {
      winAmount = 0;
      isWin = false;
    }

    notifyListeners();
  }

  int _getMultiplier(String animal) {
    switch (animal) {
      case 'lion':
        return 40;
      case 'tiger':
        return 25;
      case 'elephant':
        return 15;
      case 'dragon':
        return 5;
      case 'bear':
        return 10;
      case 'hayena':
        return 5;
      case 'deer':
        return 5;
      case 'ocean':
        return 5;
      default:
        return 5;
    }
  }

  Future<void> fetchTodayRankings() async {
    isLoadingRankings = true;
    notifyListeners();
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final querySnap = await FirebaseFirestore.instance
          .collection('room_game_wins')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .get();

      final Map<String, Map<String, dynamic>> userAggregates = {};

      for (var doc in querySnap.docs) {
        final data = doc.data();
        final gameName = data['gameName'] as String?;
        if (gameName != 'Animal Game') continue;

        final userId = data['userId'] as String?;
        final winAmount = (data['winAmount'] as num?)?.toInt() ?? 0;
        final displayName = data['displayName'] as String? ?? 'User';
        final photoUrl = data['photoUrl'] as String?;

        if (userId == null) continue;

        if (userAggregates.containsKey(userId)) {
          userAggregates[userId]!['winAmount'] = (userAggregates[userId]!['winAmount'] as int) + winAmount;
        } else {
          userAggregates[userId] = {
            'userId': userId,
            'displayName': displayName,
            'photoUrl': photoUrl,
            'winAmount': winAmount,
          };
        }
      }

      final sortedList = userAggregates.values.toList()
        ..sort((a, b) => (b['winAmount'] as int).compareTo(a['winAmount'] as int));

      todayRankings = sortedList;
    } catch (e) {
      debugPrint("Error fetching today's rankings: $e");
    } finally {
      isLoadingRankings = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _animationTimer?.cancel();
    _offsetSubscription?.cancel();
    _controlSubscription?.cancel();
    _potsSubscription?.cancel();
    super.dispose();
  }
}

enum GamePhase {
  betting,
  gap,
  round,
  result,
  showingResult,
  finished,
}