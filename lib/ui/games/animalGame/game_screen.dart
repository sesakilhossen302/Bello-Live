import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../../navigation/routes.dart';
import '../../../../data/remote/firebase/profile_services.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'game_controller.dart';

class AnimalGameScreen extends StatefulWidget {
  const AnimalGameScreen({super.key});

  @override
  State<AnimalGameScreen> createState() => _AnimalGameScreenState();
}

class _AnimalGameScreenState extends State<AnimalGameScreen> {
  late GameController controller;
  bool _isResultShown = false;
  DialogRoute? _resultDialogRoute;

  @override
  void initState() {
    super.initState();
    controller = GameController();
    controller.addListener(() {
      setState(() {});
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
    if (controller.currentPhase == GamePhase.showingResult &&
        !_isResultShown) {
      _isResultShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showResultDialog(context);
      });
    } else if (controller.currentPhase != GamePhase.showingResult) {
      if (_isResultShown) {
        _isResultShown = false;
        if (_resultDialogRoute != null && _resultDialogRoute!.isActive) {
          _resultDialogRoute!.navigator?.removeRoute(_resultDialogRoute!);
          _resultDialogRoute = null;
        }
      }
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
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
                  _buildUserProfileRow(),
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
        ],
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
          GestureDetector(
            onTap: () => _showRankingBottomSheet(context),
            child: Container(
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
    final myBet = controller.animalBets[animal] ?? 0;
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
            if (myBet > 0)
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
                    _formatBalance(myBet),
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
    final isNegative = number < 0;
    final absNumber = number.abs();
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

  void _showResultDialog(BuildContext context) {
    if (_resultDialogRoute != null && _resultDialogRoute!.isActive) {
      _resultDialogRoute!.navigator?.removeRoute(_resultDialogRoute!);
    }

    _resultDialogRoute = DialogRoute(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: true,
      builder: (context) => AnimalGameResultDialog(controller: controller),
    );

    Navigator.of(context).push(_resultDialogRoute!);
  }

  Widget _buildUserProfileRow() {
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: ProfileService.getUserProfileStream(currentUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox(height: 50);
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String displayName = data['displayName'] ?? 'User';
        final String displayId = data['displayId'] ?? 'N/A';
        final String? photoUrl = data['photoUrl'];

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            children: [
              // Back button to close/pop screen safely
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.amber, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withOpacity(0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: ClipOval(
                  child: photoUrl != null && photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person, color: Colors.white70),
                        )
                      : const Icon(Icons.person, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 12),
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: $displayId',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Topup Button
              GestureDetector(
                onTap: () => context.push(Routes.topUp.path),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF8C00), Color(0xFFFF3C78)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF3C78).withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Top Up',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
      top: 120, // Slightly lower than bottomsheet top to fit under user profile row
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
                                    _formatBalance(winAmount),
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

  String _formatBalance(int number) {
    final isNegative = number < 0;
    final absNumber = number.abs();
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!controller.hasParticipated) ...[
                const Icon(Icons.info_outline, color: Colors.orange, size: 70),
                const SizedBox(height: 16),
                const Text(
                  'Not Participated',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'You did not bet in this round',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                if (controller.winningAnimal != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Winning Animal:',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 4),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/animalgame/${controller.winningAnimal}.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ] else if (controller.isWin) ...[
                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.celebration, color: Colors.amber, size: 70),
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Text('✨', style: TextStyle(fontSize: 24)),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Text('✨', style: TextStyle(fontSize: 24)),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 10,
                      child: Text('🎊', style: TextStyle(fontSize: 20)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 10,
                      child: Text('🎊', style: TextStyle(fontSize: 20)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '🎉 Congratulations! 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.amber,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'YOU WON!',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                if (controller.winningAnimal != null)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber, width: 4),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/animalgame/${controller.winningAnimal}.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.shade900.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.green, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Bet:',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Row(
                            children: [
                              Image.asset(
                                'assets/animalgame/coin.png',
                                width: 18,
                                height: 18,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _formatBalance(controller.totalBetAmount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'You Won:',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
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
                                _formatBalance(controller.winAmount),
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white30, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Net Gain:',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              const Text(
                                '+',
                                style: TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Image.asset(
                                'assets/animalgame/coin.png',
                                width: 18,
                                height: 18,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _formatBalance(
                                  controller.winAmount -
                                      controller.totalBetAmount,
                                ),
                                style: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 18,
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
              ] else ...[
                const Icon(
                  Icons.sentiment_dissatisfied,
                  color: Colors.red,
                  size: 70,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Better Luck Next Time!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'YOU LOST',
                  style: TextStyle(color: Colors.white70, fontSize: 20),
                ),
                const SizedBox(height: 16),
                if (controller.winningAnimal != null)
                  Column(
                    children: [
                      const Text(
                        'Winning Animal:',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.amber, width: 4),
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
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade900.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.red, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total Bet:',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                          ),
                          Row(
                            children: [
                              Image.asset(
                                'assets/animalgame/coin.png',
                                width: 18,
                                height: 18,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _formatBalance(controller.totalBetAmount),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Divider(color: Colors.white30, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Net Loss:',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              const Text(
                                '-',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Image.asset(
                                'assets/animalgame/coin.png',
                                width: 18,
                                height: 18,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _formatBalance(controller.totalBetAmount),
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 18,
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
              ],
            ],
          ),
        ),
      ),
    );
  }
}
