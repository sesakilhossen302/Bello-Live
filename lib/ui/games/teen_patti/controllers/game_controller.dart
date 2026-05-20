import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
  var totalCoins = 5000000.obs;

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

  Timer? _timer;
  final Random _random = Random();

  @override
  void onInit() {
    super.onInit();
    startNewRound();
  }

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  void startNewRound() {
    gameState.value = GameState.betting;
    roundTimer.value = 25; // ✅ 25 seconds selection time
    showCards.value = false;
    isFlipping.value = false;
    revealedCards.value = [false, false, false];
    showWinAnimation.value = false;
    dimNonWinningCards.value = [false, false, false];
    showCardRevealingText.value = false;

    // ✅ Show "Selection Time" text for 2 seconds only
    showSelectionTimeText.value = true;
    Future.delayed(const Duration(seconds: 2), () {
      showSelectionTimeText.value = false;
    });

    // ✅ Reset to default coin 100
    selectedCoinValue.value = 100;
    selectedCoinImage.value = 'assets/gameimages/coin_100.png';

    // ✅ NO SHUFFLE - Always serial A, B, C
    final blocks = [
      BlockPosition('A', 'assets/gameimages/chair_a.png', 'assets/gameimages/block_a.png'),
      BlockPosition('B', 'assets/gameimages/chair_b.png', 'assets/gameimages/block_b.png'),
      BlockPosition('C', 'assets/gameimages/chair_c.png', 'assets/gameimages/block_c.png'),
    ];
    blockPositions.value = blocks;

    // Clear bets
    blockBets.value = {
      'A': <CoinBet>[],
      'B': <CoinBet>[],
      'C': <CoinBet>[],
    };

    // Clear cards
    positionCards.value = ['', '', ''];
    winningPosition.value = 0;

    // Start countdown
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (roundTimer.value > 0) {
        roundTimer.value--;
      } else {
        timer.cancel();
        // ✅ Start 1 second gap before showing "Card Revealing" text
        startWaitingBeforeReveal();
      }
    });
  }

  // ✅ 1 second gap before showing "Card Revealing" text
  void startWaitingBeforeReveal() {
    gameState.value = GameState.waitingBeforeReveal;
    Future.delayed(const Duration(seconds: 1), () {
      showCardRevealingTextPhase();
    });
  }

  // ✅ Show "Card Revealing" text for 1 second
  void showCardRevealingTextPhase() {
    gameState.value = GameState.showingRevealText;
    showCardRevealingText.value = true;

    Future.delayed(const Duration(seconds: 1), () {
      showCardRevealingText.value = false;
      revealCards();
    });
  }

  void selectCoin(int value, String image) {
    if (gameState.value != GameState.betting) return;
    selectedCoinValue.value = value;
    selectedCoinImage.value = image;
  }

  void placeBet(String blockLabel) {
    if (gameState.value != GameState.betting) return;
    if (selectedCoinValue.value == 0) {
      Get.snackbar(
        'Select a Coin',
        'Please select a coin first!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.withOpacity(0.7),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }
    if (totalCoins.value < selectedCoinValue.value) {
      Get.snackbar(
        'Insufficient Coins',
        'You don\'t have enough coins!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red.withOpacity(0.7),
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
      return;
    }

    totalCoins.value -= selectedCoinValue.value;

    final bet = CoinBet(selectedCoinValue.value, selectedCoinImage.value);

    blockBets[blockLabel]!.add(bet);
    blockBets.refresh();
  }

  void revealCards() {
    gameState.value = GameState.revealing;

    // Generate random cards
    final winCardIndex = _random.nextInt(26) + 1;
    final normalCard1Index = _random.nextInt(53) + 1;
    var normalCard2Index = _random.nextInt(53) + 1;

    while (normalCard2Index == normalCard1Index) {
      normalCard2Index = _random.nextInt(53) + 1;
    }

    final winCard = 'assets/gameimages/win_card/wc$winCardIndex.png';
    final normalCard1 = 'assets/gameimages/normal_card/nc$normalCard1Index.png';
    final normalCard2 = 'assets/gameimages/normal_card/nc$normalCard2Index.png';

    winningPosition.value = _random.nextInt(3);

    final cards = [normalCard1, normalCard2, normalCard2];
    cards[winningPosition.value] = winCard;

    if (winningPosition.value == 0) {
      if (_random.nextBool()) {
        cards[1] = normalCard2;
        cards[2] = normalCard1;
      } else {
        cards[1] = normalCard1;
        cards[2] = normalCard2;
      }
    } else if (winningPosition.value == 1) {
      if (_random.nextBool()) {
        cards[0] = normalCard2;
        cards[2] = normalCard1;
      } else {
        cards[0] = normalCard1;
        cards[2] = normalCard2;
      }
    } else {
      if (_random.nextBool()) {
        cards[0] = normalCard2;
        cards[1] = normalCard1;
      } else {
        cards[0] = normalCard1;
        cards[1] = normalCard2;
      }
    }

    positionCards.value = cards;

    // ✅ Flip cards one by one with 1 second between each (total 3 seconds)
    Future.delayed(const Duration(seconds: 1), () {
      revealedCards[0] = true;
      revealedCards.refresh();
    });

    Future.delayed(const Duration(seconds: 2), () {
      revealedCards[1] = true;
      revealedCards.refresh();
    });

    Future.delayed(const Duration(seconds: 3), () {
      revealedCards[2] = true;
      revealedCards.refresh();
      showCards.value = true;

      // ✅ Show win/lose notification immediately after all cards revealed
      showWinNotification();
    });

    // ✅ After all cards revealed (3s), wait 1 second then show win animation
    Future.delayed(const Duration(seconds: 4), () {
      startWinAnimation();
    });
  }

  // ✅ Show win/lose notification (called right after cards are revealed)
  void showWinNotification() {
    final winningBlockLabel = blockPositions[winningPosition.value].label;

    int winAmount = 0;
    final winningBets = blockBets[winningBlockLabel] ?? [];

    for (var bet in winningBets) {
      winAmount += (bet.value * 2.9).toInt(); // ✅ 2.9x payout
    }

    if (winAmount > 0) {
      Get.snackbar(
        '🎉 You Won!',
        'Block $winningBlockLabel won! You earned $winAmount coins!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } else {
      Get.snackbar(
        '😔 Better Luck Next Time',
        'Block $winningBlockLabel won! Try again!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // ✅ Win animation - dim non-winning cards and blocks for 8 seconds
  void startWinAnimation() {
    gameState.value = GameState.winAnimation;
    showWinAnimation.value = true;

    // Dim the other 2 cards (not the winning one)
    for (int i = 0; i < 3; i++) {
      if (i != winningPosition.value) {
        dimNonWinningCards[i] = true;
      }
    }
    dimNonWinningCards.refresh();

    // ✅ Show animation for 8 seconds (7 seconds display + 1 second buffer)
    Future.delayed(const Duration(seconds: 8), () {
      calculateResults();
    });
  }

  void calculateResults() {
    gameState.value = GameState.result;

    final winningBlockLabel = blockPositions[winningPosition.value].label;

    // ✅ Add to game records
    gameRecords.insert(0, GameRecord(winningBlockLabel, DateTime.now()));

    int winAmount = 0;
    final winningBets = blockBets[winningBlockLabel] ?? [];

    for (var bet in winningBets) {
      winAmount += (bet.value * 2.9).toInt(); // ✅ 2.9x payout
    }

    if (winAmount > 0) {
      totalCoins.value += winAmount;
    }

    // ✅ Immediately start new round (no extra delay)
    startNewRound();
  }

  int getBlockTotal(String blockLabel) {
    final bets = blockBets[blockLabel] ?? [];
    return bets.fold(0, (sum, bet) => sum + bet.value);
  }

  List<CoinBet> getBlockBets(String blockLabel) {
    return blockBets[blockLabel] ?? [];
  }
}
