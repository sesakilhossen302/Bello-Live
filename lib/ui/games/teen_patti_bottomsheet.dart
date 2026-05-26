import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../data/remote/firebase/profile_services.dart';
import '../../navigation/routes.dart';
import 'teen_patti/controllers/game_controller.dart';
import 'teen_patti/helpers/number_formatter.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'teen_patti/widgets/flip_card_widget.dart';

class TeenPattiBottomSheet extends StatefulWidget {
  const TeenPattiBottomSheet({super.key});

  @override
  State<TeenPattiBottomSheet> createState() => _TeenPattiBottomSheetState();
}

class _TeenPattiBottomSheetState extends State<TeenPattiBottomSheet> {
  late GameController controller;

  Widget _buildUserProfileHeader() {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: ProfileService.getUserProfileStream(currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String name = data['displayName'] ?? data['name'] ?? 'User';
        final String displayId = data['displayId'] ?? '';
        final String? avatarUrl = data['photoUrl'] ?? data['profilePic'];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.amber.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 10,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? const Icon(Icons.person, size: 10, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Text(
                      'ID: $displayId',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 8,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  context.push(Routes.topUp.path);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.amber, Colors.orange],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Top Up',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRankingBottomSheet(BuildContext context) {
    controller.fetchTodayRankings();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Today's Ranking",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(() {
                  if (controller.isLoadingRankings.value) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final rankings = controller.todayRankings;
                  if (rankings.isEmpty) {
                    return const Center(
                      child: Text(
                        "No game wins recorded today.",
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: rankings.length,
                    itemBuilder: (context, index) {
                      final user = rankings[index];
                      final displayName = user['displayName'] ?? 'User';
                      final photoUrl = user['photoUrl'] as String?;
                      final winAmount = user['winAmount'] as int;

                      Widget rankWidget;
                      if (index == 0) {
                        rankWidget = const Icon(Icons.emoji_events, color: Colors.amber, size: 24);
                      } else if (index == 1) {
                        rankWidget = const Icon(Icons.emoji_events, color: Colors.grey, size: 24);
                      } else if (index == 2) {
                        rankWidget = const Icon(Icons.emoji_events, color: Colors.brown, size: 24);
                      } else {
                        rankWidget = CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.grey.shade200,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.black87,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }

                      return ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: 30, child: Center(child: rankWidget)),
                            const SizedBox(width: 10),
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                                  ? NetworkImage(photoUrl)
                                  : null,
                              child: (photoUrl == null || photoUrl.isEmpty)
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                            ),
                          ],
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              'assets/coins/coin.png',
                              width: 16,
                              height: 16,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.monetization_on,
                                color: Colors.amber,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              NumberFormatter.format(winAmount),
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRankingButton() {
    return GestureDetector(
      onTap: () => _showRankingBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.purpleAccent, Colors.deepPurple],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 14),
            SizedBox(width: 4),
            Text(
              'Ranking',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    if (Get.isRegistered<GameController>()) {
      Get.delete<GameController>(force: true);
    }
    controller = Get.put(GameController());

    // Listen to game state changes to show SnackBar notifications
    controller.gameState.listen((state) {
      if (!mounted) return;
      if (state == GameState.winAnimation) {
        _showWinLoseNotification();
      }
    });
  }

  void _showWinLoseNotification() {
    final winningBlockLabel = controller.blockPositions[controller.winningPosition.value].label;

    int winAmount = 0;
    final winningBets = controller.blockBets[winningBlockLabel] ?? [];

    for (var bet in winningBets) {
      winAmount += (bet.value * 2.9).toInt(); // 2.9x payout
    }

    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          winAmount > 0
              ? '🎉 You Won! Block $winningBlockLabel won! You earned $winAmount coins!'
              : '😔 Better Luck Next Time. Block $winningBlockLabel won!',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: winAmount > 0 ? Colors.green[700] : Colors.amber[800],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<GameController>(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final sheetHeight = screenHeight * 0.54;

    return SafeArea(
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Stack(
            children: [
              // Background image
              Positioned.fill(
                child: Image.asset(
                  'assets/gameimages/bg.png',
                  fit: BoxFit.cover,
                ),
              ),
              // User Profile Header
              Positioned(
                top: 8,
                left: 12,
                child: _buildUserProfileHeader(),
              ),
              // Ranking Button
              Positioned(
                top: 8,
                right: 44,
                child: _buildRankingButton(),
              ),
              // Close button
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
              // Game content — responsive using LayoutBuilder
              LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  final w = constraints.maxWidth;

                  // Proportional sizes
                  final cardAreaH = h * 0.28;   // 28% for cards
                  final counterH  = h * 0.08;   // 8% for timer
                  final blockAreaH = h * 0.35;  // 35% for betting blocks
                  final coinAreaH  = h * 0.17;  // 17% for coin selector
                  // top padding ~12%

                  return Column(
                    children: [
                      SizedBox(height: h * 0.12),

                      // ── Cards ──
                      SizedBox(
                        height: cardAreaH,
                        child: _buildCards(w),
                      ),

                      // ── Timer counter ──
                      SizedBox(
                        height: counterH,
                        child: _buildCounter(),
                      ),

                      // ── Betting Blocks ──
                      SizedBox(
                        height: blockAreaH,
                        child: _buildBettingBlocks(blockAreaH),
                      ),

                      // ── Coin Selector ──
                      SizedBox(
                        height: coinAreaH,
                        child: _buildCoinSelector(w, coinAreaH),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalWinBannerOverlay() {
    final winData = controller.activeGameWin.value;
    final bool show = controller.showGameWinBanner.value && winData != null;

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

    Widget gameIcon = Image.asset(
      'assets/gameimages/card_back.png',
      width: 28,
      height: 28,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.style, color: Colors.amber, size: 28),
    );

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutBack,
      top: 50,
      left: show ? (MediaQuery.of(context).size.width - 320) / 2 : -340,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: show ? 1.0 : 0.0,
        child: Container(
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
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
                        border: Border.all(color: Colors.amber, width: 1.5),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? const Icon(Icons.person, size: 20, color: Colors.white)
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
                                Shadow(color: Colors.black, blurRadius: 4),
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
                                Shadow(color: Colors.black, blurRadius: 3),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: bannerType == 'red' ? Colors.redAccent : Colors.lightBlueAccent,
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
                            errorBuilder: (_, __, ___) => const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+$coinsText',
                            style: TextStyle(
                              color: bannerType == 'red' ? Colors.redAccent.shade100 : Colors.lightBlueAccent.shade100,
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
    );
  }

  // ─────────────────────────────────────────────
  // CARDS
  // ─────────────────────────────────────────────
  Widget _buildCards(double w) {
    return Obx(() {
      final ctrl = controller;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(3, (i) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: w * 0.01),
                child: Stack(
                  children: [
                    FlipCardWidget(
                      showFront: !ctrl.revealedCards[i],
                      frontImage: 'assets/gameimages/card_back.png',
                      backImage: ctrl.positionCards.length > i &&
                              ctrl.positionCards[i].isNotEmpty
                          ? ctrl.positionCards[i]
                          : 'assets/gameimages/card_back.png',
                    ),
                    if (ctrl.dimNonWinningCards[i])
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────
  // TIMER COUNTER
  // ─────────────────────────────────────────────
  Widget _buildCounter() {
    return Obx(() {
      if (controller.gameState.value != GameState.betting) {
        // Show phase label instead
        String label = '';
        if (controller.gameState.value == GameState.revealing ||
            controller.gameState.value == GameState.showingRevealText) {
          label = 'Card Reveal';
        } else if (controller.gameState.value == GameState.winAnimation) {
          label = '🎉 Result';
        }
        if (label.isEmpty) return const SizedBox.shrink();
        return Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      return Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.black87,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: Center(
            child: Text(
              '${controller.roundTimer.value}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    });
  }

  // ─────────────────────────────────────────────
  // BETTING BLOCKS
  // ─────────────────────────────────────────────
  Widget _buildBettingBlocks(double availH) {
    final chairH = availH * 0.42;   // chair takes 42% of block area
    final boxH   = availH * 0.50;   // info box takes rest

    return Obx(() {
      final positions = controller.blockPositions;
      if (positions.isEmpty) return const SizedBox();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(3, (i) {
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildBlock(positions[i].label, positions[i].chairImage,
                    i, chairH, boxH),
              ),
            );
          }),
        ),
      );
    });
  }

  Widget _buildBlock(String label, String chairImg, int idx,
      double chairH, double boxH) {
    return GestureDetector(
      onTap: () {
        if (controller.gameState.value == GameState.betting) {
          final error = controller.placeBet(label);
          if (error != null) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(error, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.red[700],
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      },
      child: Obx(() {
        final shouldDim = controller.gameState.value == GameState.winAnimation &&
            controller.winningPosition.value != idx;

        return Stack(
          children: [
            Column(
              children: [
                // Chair image — proportional
                Image.asset(
                  chairImg,
                  height: chairH,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => SizedBox(
                    height: chairH,
                    child: const Icon(Icons.chair, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(height: 4),
                // Info box
                Container(
                  height: boxH,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Obx(() {
                        final globalTotal = controller.globalBets[label] ?? 0;
                        return Text(
                          'Pot: ${NumberFormatter.format(globalTotal)}',
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                        );
                      }),
                      const Divider(height: 6, thickness: 0.8),
                      Obx(() {
                        final total = controller
                            .getBlockBets(label)
                            .fold(0, (s, b) => s + b.value);
                        return Text(
                          'You: ${NumberFormatter.format(total)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.purple,
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
            if (shouldDim)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }

  // ─────────────────────────────────────────────
  // COIN SELECTOR
  // ─────────────────────────────────────────────
  Widget _buildCoinSelector(double w, double areaH) {
    final coins = [
      {'value': 100, 'image': 'assets/gameimages/coin_100.png'},
      {'value': 1000, 'image': 'assets/gameimages/coin_1k.png'},
      {'value': 10000, 'image': 'assets/gameimages/coin_10k.png'},
      {'value': 50000, 'image': 'assets/gameimages/coin_50K.png'},
      {'value': 100000, 'image': 'assets/gameimages/coin_100k.png'},
    ];

    final coinSize = (w * 0.11).clamp(28.0, 40.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade900, Colors.red.shade800],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.yellow.shade700, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Balance display
          Obx(() => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/gameimages/coin.png',
                    width: 18,
                    height: 18,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.monetization_on, color: Colors.orange, size: 18),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    NumberFormatter.format(controller.totalCoins.value),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              )),

          // Coin chips
          ...coins.map((coin) {
            final value = coin['value'] as int;
            final image = coin['image'] as String;
            return Obx(() {
              final isSelected = controller.selectedCoinValue.value == value;
              return GestureDetector(
                onTap: () {
                  if (controller.gameState.value == GameState.betting) {
                    controller.selectCoin(value, image);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  padding: EdgeInsets.all(isSelected ? 2 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: Image.asset(
                    image,
                    width: coinSize,
                    height: coinSize,
                    errorBuilder: (_, __, ___) => Container(
                      width: coinSize,
                      height: coinSize,
                      decoration: const BoxDecoration(
                          color: Colors.orange, shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          value >= 1000 ? '${value ~/ 1000}K' : '$value',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            });
          }).toList(),

          // History Button
          GestureDetector(
            onTap: () => _showHistoryBottomSheet(context),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: coinSize,
              height: coinSize,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  void _showHistoryBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Game History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF3A73F),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.black12),
              const SizedBox(height: 12),

              // Chair Headers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Image.asset('assets/gameimages/chair_a.png', height: 44, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.chair, color: Colors.red, size: 40)),
                          const SizedBox(height: 4),
                          const Text('A', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Image.asset('assets/gameimages/chair_b.png', height: 44, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.chair, color: Colors.blue, size: 40)),
                          const SizedBox(height: 4),
                          const Text('B', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Image.asset('assets/gameimages/chair_c.png', height: 44, fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(Icons.chair, color: Colors.purple, size: 40)),
                          const SizedBox(height: 4),
                          const Text('C', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.black12),

              // History list
              Expanded(
                child: Obx(() {
                  final records = controller.gameRecords;
                  if (records.isEmpty) {
                    return const Center(
                      child: Text('No game history yet', style: TextStyle(color: Colors.grey)),
                    );
                  }
                  return ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.black12),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            Expanded(child: Center(child: _buildResultBadge(record.winningBlock == 'A'))),
                            Expanded(child: Center(child: _buildResultBadge(record.winningBlock == 'B'))),
                            Expanded(child: Center(child: _buildResultBadge(record.winningBlock == 'C'))),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResultBadge(bool isWin) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isWin ? const Color(0xFF1B9D32) : const Color(0xFFB0B0B0),
      ),
      child: Center(
        child: Text(
          isWin ? 'Win' : 'Fail',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

}

void showTeenPattiBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (context) {
      return const TeenPattiBottomSheet();
    },
  );
}
