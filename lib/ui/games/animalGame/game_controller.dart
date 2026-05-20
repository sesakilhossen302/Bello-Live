import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

class GameController extends ChangeNotifier {
  int balance = 1000000;
  int selectedCoinValue = 100;
  int roundTimeRemaining = 8;

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

  Timer? _timer;
  final Random _random = Random();
  int _targetIndex = 0;
  double _currentDelay = 500;
  int _roundStartTime = 0;

  void selectCoin(int value) {
    selectedCoinValue = value;
    notifyListeners();
  }

  void placeBet(String animal) {
    if (currentPhase != GamePhase.betting) return;
    if (balance < selectedCoinValue) return;

    balance -= selectedCoinValue;
    animalBets[animal] = (animalBets[animal] ?? 0) + selectedCoinValue;
    notifyListeners();
  }

  void startGame() {
    currentPhase = GamePhase.betting;
    selectionTimeRemaining = 25;
    selectedCoinValue = 100;
    _startBettingTimer();
  }

  void _startBettingTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (selectionTimeRemaining > 0) {
        selectionTimeRemaining--;
        notifyListeners();
      } else {
        timer.cancel();
        _startGapPhase();
      }
    });
  }

  void _startGapPhase() {
    currentPhase = GamePhase.gap;
    notifyListeners();

    Future.delayed(const Duration(seconds: 1), () {
      _startRoundPhase();
    });
  }

  void _startRoundPhase() {
    currentPhase = GamePhase.round;
    currentHighlightIndex = 0;
    _roundStartTime = DateTime.now().millisecondsSinceEpoch;
    _targetIndex = _random.nextInt(8);
    _currentDelay = 500;
    _startCircularHighlighting();
  }

  void _startCircularHighlighting() {
    _timer?.cancel();
    roundTimeRemaining = 8;
    void highlightNext() {
      if (currentPhase != GamePhase.round) return;

      int elapsed = DateTime.now().millisecondsSinceEpoch - _roundStartTime;
      roundTimeRemaining = 8 - (elapsed ~/ 1000);
      if (roundTimeRemaining < 1) roundTimeRemaining = 1;
      if (elapsed >= 8000) {
        _endRound();
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
            _endRound();
            return;
          }
        }
      }

      currentHighlightIndex++;
      _timer = Timer(Duration(milliseconds: _currentDelay.toInt()), highlightNext);
    }

    highlightNext();
  }

  void _endRound() {
    _timer?.cancel();
    winningAnimal = currentHighlightedAnimal;
    if (winningAnimal != null) {
      winHistory.add(winningAnimal!);
    }
    currentPhase = GamePhase.result;
    notifyListeners();

    Future.delayed(const Duration(seconds: 1), () {
      _calculateWinnings();
    });
  }

  void _calculateWinnings() {
    totalBetAmount = animalBets.values.fold(0, (sum, bet) => sum + bet);
    hasParticipated = totalBetAmount > 0;

    if (winningAnimal != null && hasParticipated) {
      int betAmount = animalBets[winningAnimal] ?? 0;
      if (betAmount > 0) {
        int multiplier = _getMultiplier(winningAnimal!);
        winAmount = betAmount * multiplier;
        balance += winAmount;
        isWin = true;
      } else {
        winAmount = 0;
        isWin = false;
      }
    } else {
      winAmount = 0;
      isWin = false;
    }

    currentPhase = GamePhase.showingResult;
    notifyListeners();

    Future.delayed(const Duration(seconds: 5), () {
      currentPhase = GamePhase.finished;
      notifyListeners();

      Future.delayed(const Duration(seconds: 1), () {
        _continueGame();
      });
    });
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

  void _continueGame() {
    animalBets.updateAll((key, value) => 0);
    winningAnimal = null;
    winAmount = 0;
    totalBetAmount = 0;
    isWin = false;
    hasParticipated = false;
    currentHighlightedAnimal = null;
    currentHighlightIndex = 0;

    startGame();
  }

  void resetGame() {
    currentPhase = GamePhase.betting;
    selectionTimeRemaining = 25;
    currentHighlightedAnimal = null;
    winningAnimal = null;
    winAmount = 0;
    totalBetAmount = 0;
    isWin = false;
    hasParticipated = false;
    currentHighlightIndex = 0;
    selectedCoinValue = 100;

    animalBets.updateAll((key, value) => 0);

    notifyListeners();
    startGame();
  }

  @override
  void dispose() {
    _timer?.cancel();
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