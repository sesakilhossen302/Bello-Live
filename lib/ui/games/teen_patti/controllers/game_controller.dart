import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../data/remote/firebase/profile_services.dart';
import '../../../streaming/audio_room_page.dart';

enum GameState { betting, waitingBeforeReveal, showingRevealText, revealing, waitingBeforeAnimation, winAnimation, result }

class CoinBet {
  final int value;
  final String image;

  CoinBet(this.value, this.image);
}

class BlockPosition {
  final String label;
  final String chairImage;
  final String blockImage;

  BlockPosition(this.label, this.chairImage, this.blockImage);
}

class GameRecord {
  final String winningBlock;
  final DateTime timestamp;

  GameRecord(this.winningBlock, this.timestamp);
}

class GameController extends GetxController {
  // Game state
  var gameState = GameState.betting.obs;
  var roundTimer = 25.obs; // ✅ 25 seconds selection time
  var totalCoins = 0.obs;

  var activeGameWin = Rxn<Map<String, dynamic>>();
  var showGameWinBanner = false.obs;

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

    activeGameWin.value = {
      'displayName': displayName,
      'photoUrl': photoUrl,
      'gameName': 'Tin Patti',
      'winAmount': winAmount,
      'bannerType': winAmount >= 550000 ? 'red' : 'blue',
    };
    showGameWinBanner.value = true;

    Future.delayed(const Duration(seconds: 5), () {
      showGameWinBanner.value = false;
      Future.delayed(const Duration(milliseconds: 500), () {
        activeGameWin.value = null;
      });
    });
  }

  // Selected coin - ✅ Default to 100
  var selectedCoinValue = 100.obs;
  var selectedCoinImage = 'assets/gameimages/coin_100.png'.obs;

  // ✅ Block positions (NO SHUFFLE - always serial A, B, C)
  var blockPositions = <BlockPosition>[].obs;

  // Bets on each block by label
  var blockBets = <String, List<CoinBet>>{}.obs;

  // Cards for reveal by position (0, 1, 2)
  var positionCards = <String>[].obs;

  var winningPosition = 0.obs;

  // Animation states
  var showCards = false.obs;
  var isFlipping = false.obs;
  var revealedCards = <bool>[false, false, false].obs;

  // ✅ Win animation states
  var showWinAnimation = false.obs;
  var dimNonWinningCards = <bool>[false, false, false].obs;

  // ✅ Selection time text (shows for 2 seconds)
  var showSelectionTimeText = false.obs;

  // ✅ Card Revealing text (shows for 1 second before cards flip)
  var showCardRevealingText = false.obs;

  // ✅ Game records for history
  var gameRecords = <GameRecord>[].obs;

  // Global bets on each block by label
  var globalBets = <String, int>{'A': 0, 'B': 0, 'C': 0}.obs;

  // ✅ Today's rankings for game wins
  var todayRankings = <Map<String, dynamic>>[].obs;
  var isLoadingRankings = false.obs;

  Timer? _timer;
  StreamSubscription? _profileSubscription;
  StreamSubscription? _offsetSubscription;
  StreamSubscription? _potsSubscription;
  StreamSubscription? _controlSubscription;
  int _serverOffset = 0;
  String _forcedWin = 'AUTO';

  // Track synchronization states
  int _lastProcessedRoundId = -1;
  int _lastResultProcessedRoundId = -1;
  Map<String, int> _myCurrentRoundBets = {'A': 0, 'B': 0, 'C': 0};

  @override
  void onInit() {
    super.onInit();
    _syncServerTime();
    _listenToAdminControl();
    _loadInitialBalance();
    _subscribeToProfile();
    _startGameSyncTimer();
  }

  void _syncServerTime() {
    _offsetSubscription = FirebaseDatabase.instance.ref('.info/serverTimeOffset').onValue.listen((event) {
      if (event.snapshot.value != null) {
        _serverOffset = (event.snapshot.value as int?) ?? 0;
      }
    });
  }

  void _listenToAdminControl() {
    final ref = FirebaseDatabase.instance.ref('games/teen_patti/control');
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

      // If we are in betting/waiting phases of the current round, instantly update the winner and cards!
      if (_lastProcessedRoundId != -1 &&
          (gameState.value == GameState.betting ||
           gameState.value == GameState.waitingBeforeReveal ||
           gameState.value == GameState.showingRevealText)) {
        _updateCardsAndWinner(_lastProcessedRoundId);
      }
    }, onError: (e) {
      debugPrint("Error listening to admin control: $e");
    });
  }

  int getCorrectedTime() {
    return DateTime.now().millisecondsSinceEpoch + _serverOffset;
  }

  void _subscribeToProfile() {
    final String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _profileSubscription = ProfileService.getUserProfileStream(uid).listen((profileSnap) {
        if (profileSnap.exists) {
          final data = profileSnap.data() as Map<String, dynamic>;
          final int newBalance = data['balance'] ?? 0;
          totalCoins.value = newBalance;
        }
      });
    }
  }

  Future<void> _loadInitialBalance() async {
    try {
      final bal = await ProfileService.getCurrentUserBalance();
      totalCoins.value = bal;
    } catch (e) {
      debugPrint("Error loading initial balance: $e");
    }
  }

  @override
  void onClose() {
    _timer?.cancel();
    _profileSubscription?.cancel();
    _offsetSubscription?.cancel();
    _potsSubscription?.cancel();
    _controlSubscription?.cancel();
    super.onClose();
  }

  void _startGameSyncTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
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

    // Determine current phase and remaining seconds based on secondsIntoRound (0 to 39)
    if (secondsIntoRound < 25) {
      // 0 to 24: Betting phase (25s)
      gameState.value = GameState.betting;
      roundTimer.value = 25 - secondsIntoRound;
      
      // Auto-play text "Selection Time" shows for first 2 seconds of the betting phase
      showSelectionTimeText.value = (secondsIntoRound < 2);
      
      // Ensure cards are hidden and other states reset
      showCards.value = false;
      isFlipping.value = false;
      revealedCards.value = [false, false, false];
      showWinAnimation.value = false;
      dimNonWinningCards.value = [false, false, false];
      showCardRevealingText.value = false;
    } 
    else if (secondsIntoRound == 25) {
      // 25: 1 second gap before reveal
      gameState.value = GameState.waitingBeforeReveal;
      roundTimer.value = 0;
      showSelectionTimeText.value = false;
      showCardRevealingText.value = false;
    } 
    else if (secondsIntoRound == 26) {
      // 26: 1 second showing card revealing text
      gameState.value = GameState.showingRevealText;
      showCardRevealingText.value = true;
      roundTimer.value = 0;
    } 
    else if (secondsIntoRound >= 27 && secondsIntoRound < 30) {
      // 27 to 29: Revealing phase (3 seconds)
      gameState.value = GameState.revealing;
      showCardRevealingText.value = false;
      
      // Flip cards one by one based on seconds
      final elapsed = secondsIntoRound - 27; // 0, 1, 2
      final currentRevealed = [...revealedCards];
      for (int i = 0; i <= elapsed; i++) {
        if (i < 3) currentRevealed[i] = true;
      }
      revealedCards.value = currentRevealed;
      
      if (secondsIntoRound == 29) {
        showCards.value = true;
      }
    } 
    else if (secondsIntoRound >= 30 && secondsIntoRound < 38) {
      // 30 to 37: Win animation & dimming (8 seconds)
      gameState.value = GameState.winAnimation;
      showCards.value = true;
      revealedCards.value = [true, true, true];
      showWinAnimation.value = true;
      
      // Dim non-winning cards
      final dimList = [false, false, false];
      for (int i = 0; i < 3; i++) {
        if (i != winningPosition.value) {
          dimList[i] = true;
        }
      }
      dimNonWinningCards.value = dimList;
    } 
    else {
      // 38 to 39: Result phase (2 seconds)
      gameState.value = GameState.result;
      
      // Trigger result calculation once per round
      if (_lastResultProcessedRoundId != currentRoundId) {
        _lastResultProcessedRoundId = currentRoundId;
        _calculateSynchronizedResults(currentRoundId);
      }
    }
  }

  void _updateCardsAndWinner(int roundId) {
    // Deterministically generate cards using the roundId as seed
    final seedRandom = Random(roundId);
    
    final winCardIndex = seedRandom.nextInt(26) + 1;
    final normalCard1Index = seedRandom.nextInt(53) + 1;
    var normalCard2Index = seedRandom.nextInt(53) + 1;
    while (normalCard2Index == normalCard1Index) {
      normalCard2Index = seedRandom.nextInt(53) + 1;
    }

    final winCard = 'assets/gameimages/win_card/wc$winCardIndex.png';
    final normalCard1 = 'assets/gameimages/normal_card/nc$normalCard1Index.png';
    final normalCard2 = 'assets/gameimages/normal_card/nc$normalCard2Index.png';

    int winPos = seedRandom.nextInt(3);
    if (_forcedWin == 'A') {
      winPos = 0;
    } else if (_forcedWin == 'B') {
      winPos = 1;
    } else if (_forcedWin == 'C') {
      winPos = 2;
    }
    winningPosition.value = winPos;

    final cards = [normalCard1, normalCard2, normalCard2];
    cards[winningPosition.value] = winCard;

    // Shuffle normal cards deterministically
    if (winningPosition.value == 0) {
      if (seedRandom.nextBool()) {
        cards[1] = normalCard2;
        cards[2] = normalCard1;
      } else {
        cards[1] = normalCard1;
        cards[2] = normalCard2;
      }
    } else if (winningPosition.value == 1) {
      if (seedRandom.nextBool()) {
        cards[0] = normalCard2;
        cards[2] = normalCard1;
      } else {
        cards[0] = normalCard1;
        cards[2] = normalCard2;
      }
    } else {
      if (seedRandom.nextBool()) {
        cards[0] = normalCard2;
        cards[1] = normalCard1;
      } else {
        cards[0] = normalCard1;
        cards[1] = normalCard2;
      }
    }

    positionCards.value = cards;
  }

  void _onNewRoundStarted(int roundId) {
    // Reset selection defaults
    selectedCoinValue.value = 100;
    selectedCoinImage.value = 'assets/gameimages/coin_100.png';

    // Clear local bets for this new round
    _myCurrentRoundBets = {'A': 0, 'B': 0, 'C': 0};

    // Reset global bets
    globalBets.value = {'A': 0, 'B': 0, 'C': 0};

    // Setup RTDB pots listener for this new round
    _potsSubscription?.cancel();
    _potsSubscription = FirebaseDatabase.instance.ref('games/teen_patti/rounds/$roundId/pots').onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        globalBets.value = {
          'A': (data['pot_A'] as num?)?.toInt() ?? 0,
          'B': (data['pot_B'] as num?)?.toInt() ?? 0,
          'C': (data['pot_C'] as num?)?.toInt() ?? 0,
        };
      }
    });

    // Ensure block positions are Serial (A, B, C)
    final blocks = [
      BlockPosition('A', 'assets/gameimages/chair_a.png', 'assets/gameimages/block_a.png'),
      BlockPosition('B', 'assets/gameimages/chair_b.png', 'assets/gameimages/block_b.png'),
      BlockPosition('C', 'assets/gameimages/chair_c.png', 'assets/gameimages/block_c.png'),
    ];
    blockPositions.value = blocks;

    // Reset UI bets
    blockBets.value = {
      'A': <CoinBet>[],
      'B': <CoinBet>[],
      'C': <CoinBet>[],
    };

    _updateCardsAndWinner(roundId);

    // Deterministically populate last 15 rounds history
    _populateSynchronizedHistory(roundId);
  }

  void _populateSynchronizedHistory(int currentRoundId) {
    final List<GameRecord> records = [];
    final labels = ['A', 'B', 'C'];
    for (int i = 0; i < 15; i++) {
      final int histRoundId = currentRoundId - i - 1;
      final histRandom = Random(histRoundId);
      final int histWinningPos = histRandom.nextInt(3);
      final String histLabel = labels[histWinningPos];
      final DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(histRoundId * 40 * 1000);
      records.add(GameRecord(histLabel, timestamp));
    }
    gameRecords.value = records;
  }

  void selectCoin(int value, String image) {
    if (gameState.value != GameState.betting) return;
    selectedCoinValue.value = value;
    selectedCoinImage.value = image;
  }

  String? placeBet(String blockLabel) {
    if (gameState.value != GameState.betting) return null;
    if (selectedCoinValue.value == 0) {
      return 'Please select a coin first!';
    }
    if (totalCoins.value < selectedCoinValue.value) {
      return 'You don\'t have enough coins!';
    }

    final betValue = selectedCoinValue.value;
    totalCoins.value -= betValue;
    ProfileService.topUpBalance(-betValue).catchError((e) {
      debugPrint("Error updating balance on bet: $e");
    });

    final bet = CoinBet(betValue, selectedCoinImage.value);

    blockBets[blockLabel]!.add(bet);
    blockBets.refresh();

    // Track user's own bet for payout calculations
    _myCurrentRoundBets[blockLabel] = (_myCurrentRoundBets[blockLabel] ?? 0) + betValue;

    // Increment global pot in RTDB
    final int roundId = _lastProcessedRoundId;
    if (roundId != -1) {
      FirebaseDatabase.instance.ref('games/teen_patti/rounds/$roundId/pots').update({
        'pot_$blockLabel': ServerValue.increment(betValue),
      }).catchError((e) {
        debugPrint("Error updating global pot: $e");
      });
    }

    return null;
  }

  void _calculateSynchronizedResults(int roundId) {
    final winningBlockLabel = blockPositions[winningPosition.value].label;

    // Calculate winnings based on user's own bets on the winning block
    final userBetOnWinningBlock = _myCurrentRoundBets[winningBlockLabel] ?? 0;
    int winAmount = 0;
    if (userBetOnWinningBlock > 0) {
      winAmount = (userBetOnWinningBlock * 2.9).toInt(); // 2.9x payout
    }

    if (winAmount > 0) {
      totalCoins.value += winAmount;
      ProfileService.topUpBalance(winAmount).catchError((e) {
        debugPrint("Error crediting winnings: $e");
      });
      if (winAmount >= 100000) {
        _triggerLocalWinBanner(winAmount);
        if (AudioRoomPage.currentRoomId != null) {
          ProfileService.recordGameWin(
            roomId: AudioRoomPage.currentRoomId!,
            gameName: 'Tin Patti',
            winAmount: winAmount,
          );
        }
      }
    }
  }

  int getBlockTotal(String blockLabel) {
    final bets = blockBets[blockLabel] ?? [];
    return bets.fold(0, (sum, bet) => sum + bet.value);
  }

  List<CoinBet> getBlockBets(String blockLabel) {
    return blockBets[blockLabel] ?? [];
  }

  Future<void> fetchTodayRankings() async {
    isLoadingRankings.value = true;
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final querySnap = await FirebaseFirestore.instance
          .collection('room_game_wins')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .get();

      // Aggregate by userId
      final Map<String, Map<String, dynamic>> userAggregates = {};

      for (var doc in querySnap.docs) {
        final data = doc.data();
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

      // Sort by winAmount descending
      final sortedList = userAggregates.values.toList()
        ..sort((a, b) => (b['winAmount'] as int).compareTo(a['winAmount'] as int));

      todayRankings.value = sortedList;
    } catch (e) {
      debugPrint("Error fetching today's rankings: $e");
    } finally {
      isLoadingRankings.value = false;
    }
  }
}
