import 'package:flutter/material.dart';
import 'game_controller.dart';

class AnimalGameScreen extends StatefulWidget {
  const AnimalGameScreen({super.key});

  @override
  State<AnimalGameScreen> createState() => _AnimalGameScreenState();
}

class _AnimalGameScreenState extends State<AnimalGameScreen> {
  late GameController controller;
  bool _isBottomSheetShown = false;

  @override
  void initState() {
    super.initState();
    controller = GameController();
    controller.startGame();
    controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.currentPhase == GamePhase.showingResult &&
        !_isBottomSheetShown) {
      _isBottomSheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showResultBottomSheet(context);
      });
    } else if (controller.currentPhase != GamePhase.showingResult) {
      _isBottomSheetShown = false;
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.fill,
            image: AssetImage("assets/animalgame/bg.png"),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0066FF), Color(0xFF0044CC)],
          ),
        ), 
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              const Spacer(),
              _buildAnimalGrid(),
              const SizedBox(height: 40),
              _buildAnimalsList(),
              const SizedBox(height: 20),
              _buildCoinsRow(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Text(
              'players',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1a1a2e),
              borderRadius: BorderRadius.circular(25),
            ),
            child: const Text(
              'Ranking',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimalGrid() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 6),
        borderRadius: BorderRadius.circular(30),
        color: const Color(0xFFc5c5d8).withOpacity(0.8),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1,
        ),
        itemCount: 9,
        itemBuilder: (context, index) {
          if (index == 4) {
            return _buildCenterCard();
          }

          int animalIndex = index > 4 ? index - 1 : index;
          String animal = controller.animals[animalIndex];

          return _buildAnimalCard(animal, animalIndex);
        },
      ),
    );
  }

  Widget _buildCenterCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber, width: 5),
        image: const DecorationImage(
          image: AssetImage('assets/animalgame/middle_icon.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child:
          (controller.currentPhase == GamePhase.betting ||
              controller.currentPhase == GamePhase.round)
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  controller.currentPhase == GamePhase.betting
                      ? '${controller.selectionTimeRemaining}'
                      : '${(controller.roundTimeRemaining).clamp(1, 8)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAnimalCard(String animal, int animalIndex) {
    final betAmount = controller.animalBets[animal] ?? 0;
    final isHighlighted =
        (controller.currentPhase == GamePhase.round ||
            controller.currentPhase == GamePhase.result ||
            controller.currentPhase == GamePhase.showingResult) &&
        controller.currentHighlightedAnimal == animal;

    int multiplier = _getMultiplier(animal);

    return GestureDetector(
      onTap: () => controller.placeBet(animal),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: isHighlighted
              ? Border.all(color: Colors.yellow, width: 5)
              : null,
          image: DecorationImage(
            image: AssetImage('assets/animalgame/${animal}_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'X$multiplier',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(color: Colors.white, blurRadius: 4)],
                  ),
                ),
              ),
            ),
            if (betAmount > 0)
              Positioned(
                top: 8,
                left: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber, width: 2),
                  ),
                  child: Text(
                    _formatBalance(betAmount),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimalsList() {
    return Container(
      height: 58,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: controller.winHistory.isEmpty
          ? const Center(
              child: Text('', style: TextStyle(color: Colors.black26)),
            )
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: controller.winHistory.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _buildSmallAnimal(controller.winHistory[index]),
                );
              },
            ),
    );
  }

  Widget _buildSmallAnimal(String animal) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.amber, width: 5),
      ),
      child: ClipOval(
        child: Image.asset('assets/animalgame/$animal.png', fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildCoinsRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2d2d44),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/animalgame/coin.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 3),
                Text(
                  _formatBalance(controller.balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCoinChip(100, 'coin_100.png'),
                _buildCoinChip(1000, 'coin_1k.png'),
                _buildCoinChip(10000, 'coin_10k.png'),
                _buildCoinChip(50000, 'coin_50K.png'),
                _buildCoinChip(100000, 'coin_100k.png'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinChip(int value, String assetName) {
    final isSelected = controller.selectedCoinValue == value;
    return GestureDetector(
      onTap: () => controller.selectCoin(value),
      child: Container(
        width: 35,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: isSelected ? Border.all(color: Colors.red, width: 5) : null,
        ),
        child: Image.asset('assets/animalgame/$assetName', fit: BoxFit.contain),
      ),
    );
  }

  String _formatBalance(int number) {
    if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(0)}K';
    }
    return number.toString();
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

  void _showResultBottomSheet(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        width: screenWidth,
        padding: const EdgeInsets.all(35),
        decoration: const BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!controller.hasParticipated) ...[
              const Icon(Icons.info_outline, color: Colors.orange, size: 80),
              const SizedBox(height: 25),
              const Text(
                'Not Participated',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'You did not bet in this round',
                style: TextStyle(color: Colors.white70, fontSize: 18),
              ),
              if (controller.winningAnimal != null) ...[
                const SizedBox(height: 25),
                const Text(
                  'Winning Animal:',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 15),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 5),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/animalgame/${controller.winningAnimal}.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 25),
            ] else if (controller.isWin) ...[
              Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.celebration, color: Colors.amber, size: 80),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Text('✨', style: TextStyle(fontSize: 30)),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Text('✨', style: TextStyle(fontSize: 30)),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 20,
                    child: Text('🎊', style: TextStyle(fontSize: 25)),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 20,
                    child: Text('🎊', style: TextStyle(fontSize: 25)),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Text(
                '🎉 Congratulations! 🎉',
                style: TextStyle(
                  color: Colors.amber,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'YOU WON!',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              if (controller.winningAnimal != null)
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 5),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/animalgame/${controller.winningAnimal}.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade900,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.green, width: 2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Bet:',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Row(
                          children: [
                            Image.asset(
                              'assets/animalgame/coin.png',
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatBalance(controller.totalBetAmount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'You Won:',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Row(
                          children: [
                            Image.asset(
                              'assets/animalgame/coin.png',
                              width: 24,
                              height: 24,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatBalance(controller.winAmount),
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white30, height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Net Gain:',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            const Text(
                              '+',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Image.asset(
                              'assets/animalgame/coin.png',
                              width: 22,
                              height: 22,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatBalance(
                                controller.winAmount -
                                    controller.totalBetAmount,
                              ),
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
            ] else ...[
              const Icon(
                Icons.sentiment_dissatisfied,
                color: Colors.red,
                size: 80,
              ),
              const SizedBox(height: 25),
              const Text(
                'Better Luck Next Time!',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              const Text(
                'YOU LOST',
                style: TextStyle(color: Colors.white70, fontSize: 24),
              ),
              const SizedBox(height: 25),
              if (controller.winningAnimal != null)
                Column(
                  children: [
                    const Text(
                      'Winning Animal:',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber, width: 5),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/animalgame/${controller.winningAnimal}.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 25),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.shade900,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Bet:',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Row(
                          children: [
                            Image.asset(
                              'assets/animalgame/coin.png',
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatBalance(controller.totalBetAmount),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white30, height: 25),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Net Loss:',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            const Text(
                              '-',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Image.asset(
                              'assets/animalgame/coin.png',
                              width: 22,
                              height: 22,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              _formatBalance(controller.totalBetAmount),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
            ],
          ],
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 4800), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }
}
