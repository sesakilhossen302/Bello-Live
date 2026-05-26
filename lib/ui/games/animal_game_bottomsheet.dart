import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../data/remote/firebase/profile_services.dart';
import '../../navigation/routes.dart';
import 'animalGame/game_controller.dart';
import 'package:flutter_svga/flutter_svga.dart';

class AnimalGameBottomSheet extends StatefulWidget {
  const AnimalGameBottomSheet({super.key});

  @override
  State<AnimalGameBottomSheet> createState() => _AnimalGameBottomSheetState();
}

class _AnimalGameBottomSheetState extends State<AnimalGameBottomSheet> {
  late GameController controller;
  bool _isResultShown = false;
  DialogRoute? _resultDialogRoute;

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

  @override
  void initState() {
    super.initState();
    controller = GameController();
    controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    if (_resultDialogRoute != null && _resultDialogRoute!.isActive) {
      _resultDialogRoute!.navigator?.removeRoute(_resultDialogRoute!);
    }
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller.currentPhase == GamePhase.showingResult && !_isResultShown) {
      _isResultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResultDialog());
    } else if (controller.currentPhase != GamePhase.showingResult) {
      if (_isResultShown) {
        _isResultShown = false;
        if (_resultDialogRoute != null && _resultDialogRoute!.isActive) {
          _resultDialogRoute!.navigator?.removeRoute(_resultDialogRoute!);
          _resultDialogRoute = null;
        }
      }
    }

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final screenW = MediaQuery.of(context).size.width;
            final screenH = MediaQuery.of(context).size.height;

            // ── Calculate grid size from available width ──
            const double hPadding = 16.0;       // sheet horizontal margin
            const double gridPadding = 8.0;      // inside grid container
            const double cellSpacing = 6.0;
            const double borderW = 2.5;          // grid container border
            const int cols = 3;

            final double gridContainerW = screenW - hPadding * 2;
            // Subtract border (both sides) from usable content area
            final double cellSize =
                (gridContainerW - borderW * 2 - gridPadding * 2 - cellSpacing * (cols - 1)) /
                    cols;
            // Container height = content needs + border top & bottom
            final double gridContainerH =
                cellSize * 3 + cellSpacing * 2 + gridPadding * 2 + borderW * 2;

            // ── Section heights ──
            const double topBarH    = 36.0;
            const double historyH   = 44.0;
            const double coinRowH   = 58.0;
            const double closeRowH  = 42.0;
            const double gapTotal   = 36.0; // 6 * 4 + 8 + 4

            final double sheetHeight =
                closeRowH + topBarH + gridContainerH + historyH + coinRowH + gapTotal + 12;

            return Container(
              height: sheetHeight,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: AssetImage("assets/animalgame/bg.png"),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Close row ──
                    SizedBox(
                      height: closeRowH,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, right: 10, top: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildUserProfileHeader(),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Top bar ──
                    SizedBox(height: topBarH, child: _buildTopBar()),
                    const SizedBox(height: 6),

                    // ── 3×3 Animal Grid ──
                    _buildAnimalGrid(gridContainerW, gridContainerH, cellSize, cellSpacing, gridPadding),
                    const SizedBox(height: 6),

                    // ── Win history ──
                    _buildHistoryRow(gridContainerW, historyH),
                    const SizedBox(height: 6),

                    // ── Coin selector ──
                    _buildCoinsRow(gridContainerW, coinRowH),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLocalWinBannerOverlay() {
    final winData = controller.activeGameWin;
    final bool show = controller.showGameWinBanner && winData != null;

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
      'assets/animalgame/bg.png',
      width: 28,
      height: 28,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const Icon(Icons.pets, color: Colors.orange, size: 28),
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

  // ──────────────────────────────────────────────────
  // TOP BAR
  // ──────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _pill('Players', Icons.people_alt_rounded),
          GestureDetector(
            onTap: () => _showRankingBottomSheet(context),
            child: _pill('Ranking', Icons.leaderboard_rounded),
          ),
        ],
      ),
    );
  }

  Widget _pill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withOpacity(0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.amber, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────
  // 3×3 GRID
  // ──────────────────────────────────────────────────
  Widget _buildAnimalGrid(double containerW, double containerH,
      double cellSize, double spacing, double padding) {
    return Container(
      width: containerW,
      height: containerH,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: const Color(0xFFc5c5d8).withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black54, width: 2.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (row) {
          return Padding(
            padding: EdgeInsets.only(bottom: row < 2 ? spacing : 0),
            child: Row(
              children: List.generate(3, (col) {
                final idx = row * 3 + col;
                return Padding(
                  padding: EdgeInsets.only(right: col < 2 ? spacing : 0),
                  child: SizedBox(
                    width: cellSize,
                    height: cellSize,
                    child: idx == 4
                        ? _buildCenterCell(cellSize)
                        : _buildAnimalCell(idx, cellSize),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCenterCell(double size) {
    final isActive = controller.currentPhase == GamePhase.betting ||
        controller.currentPhase == GamePhase.round;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber, width: 2.5),
        image: const DecorationImage(
          image: AssetImage('assets/animalgame/middle_icon.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: isActive
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                    color: Colors.black87, shape: BoxShape.circle),
                child: Text(
                  controller.currentPhase == GamePhase.betting
                      ? '${controller.selectionTimeRemaining}'
                      : '${controller.roundTimeRemaining.clamp(1, 8)}',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.bold),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildAnimalCell(int gridIdx, double size) {
    // grid index 4 is center — map around it
    final animalIdx = gridIdx > 4 ? gridIdx - 1 : gridIdx;
    final animal = controller.animals[animalIdx];
    final myBet = controller.animalBets[animal] ?? 0;
    final highlighted = (controller.currentPhase == GamePhase.round ||
            controller.currentPhase == GamePhase.result ||
            controller.currentPhase == GamePhase.showingResult) &&
        controller.currentHighlightedAnimal == animal;

    return GestureDetector(
      onTap: () => controller.placeBet(animal),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: highlighted
              ? Border.all(color: Colors.yellow, width: 3)
              : Border.all(color: Colors.black26, width: 1),
          image: DecorationImage(
            image: AssetImage('assets/animalgame/${animal}_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Multiplier
            Positioned(
              bottom: 4,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'X${_multiplier(animal)}',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: size * 0.17,
                    fontWeight: FontWeight.bold,
                    shadows: const [
                      Shadow(color: Colors.white, blurRadius: 4)
                    ],
                  ),
                ),
              ),
            ),
            // Bet badge
            if (myBet > 0)
              Positioned(
                top: 4,
                left: 4,
                right: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber, width: 1.5),
                  ),
                  child: Text(
                    _fmt(myBet),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────
  // HISTORY ROW
  // ──────────────────────────────────────────────────
  Widget _buildHistoryRow(double w, double h) {
    return Container(
      width: w,
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: controller.winHistory.isEmpty
          ? const Center(
              child: Text('Win history',
                  style: TextStyle(color: Colors.black38, fontSize: 12)))
          : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: controller.winHistory.length,
              itemBuilder: (_, i) {
                final animal = controller.winHistory[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 2.5),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                          'assets/animalgame/$animal.png',
                          fit: BoxFit.cover),
                    ),
                  ),
                );
              },
            ),
    );
  }

  // ──────────────────────────────────────────────────
  // COIN ROW
  // ──────────────────────────────────────────────────
  Widget _buildCoinsRow(double w, double h) {
    final coins = [
      {'val': 100,    'asset': 'coin_100.png'},
      {'val': 1000,   'asset': 'coin_1k.png'},
      {'val': 10000,  'asset': 'coin_10k.png'},
      {'val': 50000,  'asset': 'coin_50K.png'},
      {'val': 100000, 'asset': 'coin_100k.png'},
    ];

    // Chip size proportional to available width
    final chipSize = ((w - 32 - 80) / coins.length - 8).clamp(28.0, 44.0);

    return Container(
      width: w,
      height: h,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Balance
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2d2d44),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/animalgame/coin.png',
                    width: 18, height: 18,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.monetization_on,
                            color: Colors.amber, size: 18)),
                const SizedBox(width: 4),
                Text(
                  _fmt(controller.balance),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Coin chips
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: coins.map((c) {
                final val = c['val'] as int;
                final asset = c['asset'] as String;
                final selected = controller.selectedCoinValue == val;
                return GestureDetector(
                  onTap: () => controller.selectCoin(val),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: chipSize,
                    height: chipSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: selected
                          ? Border.all(color: Colors.red, width: 3)
                          : null,
                      boxShadow: selected
                          ? [const BoxShadow(
                              color: Colors.red,
                              blurRadius: 6,
                              spreadRadius: 1)]
                          : null,
                    ),
                    child: Image.asset(
                      'assets/animalgame/$asset',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                            color: Colors.orange, shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            val >= 1000000
                                ? '${val ~/ 1000000}M'
                                : val >= 1000
                                    ? '${val ~/ 1000}K'
                                    : '$val',
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
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────
  // RESULT DIALOG
  // ──────────────────────────────────────────────────
  void _showResultDialog() {
    if (_resultDialogRoute != null && _resultDialogRoute!.isActive) {
      _resultDialogRoute!.navigator?.removeRoute(_resultDialogRoute!);
    }

    _resultDialogRoute = DialogRoute(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (_) => AnimalGameResultDialog(controller: controller),
    );

    Navigator.of(context).push(_resultDialogRoute!);
  }

  // ──────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────
  int _multiplier(String a) {
    switch (a) {
      case 'lion':     return 40;
      case 'tiger':    return 25;
      case 'elephant': return 15;
      case 'bear':     return 10;
      case 'dragon':   return 5;
      case 'hayena':   return 5;
      case 'deer':     return 5;
      case 'ocean':    return 5;
      default:         return 5;
    }
  }

  String _fmt(int n) {
    final isNegative = n < 0;
    final absNumber = n.abs();
    String formatted;
    if (absNumber >= 1000000) {
      double val = absNumber / 1000000;
      String s = val.toStringAsFixed(2);
      if (s.endsWith('.00')) {
        formatted = '${val.toInt()}M';
      } else if (s.endsWith('0')) {
        formatted = '${val.toStringAsFixed(1)}M';
      } else {
        formatted = '${s}M';
      }
    } else if (absNumber >= 1000) {
      double val = absNumber / 1000;
      String s = val.toStringAsFixed(2);
      if (s.endsWith('.00')) {
        formatted = '${val.toInt()}K';
      } else if (s.endsWith('0')) {
        formatted = '${val.toStringAsFixed(1)}K';
      } else {
        formatted = '${s}K';
      }
    } else {
      formatted = absNumber.toString();
    }
    return isNegative ? '-$formatted' : formatted;
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
        return StatefulBuilder(
          builder: (context, setModalState) {
            void listener() {
              if (mounted) {
                setModalState(() {});
              }
            }
            controller.addListener(listener);

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
                          onTap: () {
                            controller.removeListener(listener);
                            Navigator.pop(context);
                          },
                          child: const Icon(Icons.close, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Colors.black12),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        if (controller.isLoadingRankings) {
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

                            // Use local custom formatting or simple toString
                            String formattedWinAmount;
                            final absNumber = winAmount.abs();
                            if (absNumber >= 1000000) {
                              formattedWinAmount = '${(absNumber / 1000000).toStringAsFixed(1)}M';
                            } else if (absNumber >= 1000) {
                              formattedWinAmount = '${(absNumber / 1000).toStringAsFixed(1)}K';
                            } else {
                              formattedWinAmount = absNumber.toString();
                            }
                            if (winAmount < 0) formattedWinAmount = '-$formattedWinAmount';

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
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/animalgame/coin.png',
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
                                    formattedWinAmount,
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
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class AnimalGameResultDialog extends StatelessWidget {
  final GameController controller;

  const AnimalGameResultDialog({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.amber.withOpacity(0.8), width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!controller.hasParticipated) ...[
              const Icon(Icons.info_outline, color: Colors.orange, size: 60),
              const SizedBox(height: 12),
              const Text('Not Participated',
                  style: TextStyle(
                      color: Colors.orange,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('You did not bet this round',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ] else if (controller.isWin) ...[
              const Icon(Icons.celebration, color: Colors.amber, size: 60),
              const SizedBox(height: 12),
              const Text('🎉 YOU WON! 🎉',
                  style: TextStyle(
                      color: Colors.amber,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ] else ...[
              const Icon(Icons.sentiment_dissatisfied,
                  color: Colors.red, size: 60),
              const SizedBox(height: 12),
              const Text('Better Luck Next Time',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ],
            if (controller.winningAnimal != null) ...[
              const SizedBox(height: 16),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber, width: 3),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/animalgame/${controller.winningAnimal}.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

void showAnimalGameBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => const AnimalGameBottomSheet(),
  );
}
