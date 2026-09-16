import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import '../../data/remote/firebase/level_service.dart';

import 'package:flutter_svg/flutter_svg.dart';

// Firebase Imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/remote/firebase/profile_services.dart';

import '../../theme/app_theme.dart';

class MyLevelPage extends StatefulWidget {
  const MyLevelPage({super.key});

  @override
  State<MyLevelPage> createState() => _MyLevelPageState();
}

class _MyLevelPageState extends State<MyLevelPage> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Padding(
                padding: const EdgeInsets.only(left: 0, right: 20, top: 0, bottom: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.back, size: 28, color: Colors.pink),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Text(
                      'My Level',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              Expanded(
                child: _userId == null
                    ? const Center(
                  child: Text('Please log in to see your level.', style: TextStyle(color: Colors.white)),
                )
                    : StreamBuilder<DocumentSnapshot>(
                  stream: ProfileService.getUserProfileStream(_userId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.pink));
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error: ${snapshot.error}', style: TextStyle(color: Colors.red.shade300)),
                      );
                    }

                    if (!snapshot.hasData || !snapshot.data!.exists) {
                      return const Center(
                        child: Text('Profile data not found.', style: TextStyle(color: Colors.white70)),
                      );
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>;

                    // Calculate Real Data
                    final int currentXP = data['totalSent'] ?? 0;
                    final int currentLevel = getSentLevel(currentXP);
                    final int nextLevelXP = currentLevel < 100 ? _getRequiredXP(currentLevel + 1) : _getRequiredXP(100);

                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),
                          _buildLevelHeader(currentLevel, currentXP, nextLevelXP),
                          const SizedBox(height: 30),
                          _buildLevelGrid(currentLevel),
                          const SizedBox(height: 30),
                          _buildXPExplanation(),
                          const SizedBox(height: 30),
                          _buildHowToLevelUp(),
                          const SizedBox(height: 30),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelHeader(int currentLevel, int currentXP, int nextLevelXP) {
    // Prevent division by zero and cap progress at 100% for max level
    double progressPercentage = 1.0;
    if (currentLevel < 100) {
      // Calculate visual progress strictly within the current tier gap
      int previousLevelXP = _getRequiredXP(currentLevel);
      int xpNeededForThisTier = nextLevelXP - previousLevelXP;
      int xpEarnedInThisTier = currentXP - previousLevelXP;

      progressPercentage = xpEarnedInThisTier / xpNeededForThisTier;
      // Safety clamp between 0.0 and 1.0
      progressPercentage = progressPercentage.clamp(0.0, 1.0);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.1), blurRadius: 30, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Level Image and Text
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/levels/rank_caifu_cf_$currentLevel.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.pink.shade300,
                              Colors.pink.shade500,
                              Colors.purple.shade400,
                              Colors.pink.shade600,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.military_tech_rounded, color: Colors.white, size: 32),
                              const SizedBox(height: 2),
                              Text(
                                '$currentLevel',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Progress Bar
              Column(
                children: [
                  Text(
                    currentLevel < 100 ? 'Progress to Level ${currentLevel + 1}' : 'Max Level Reached!',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: progressPercentage,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.pink.shade400),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Exp ${_formatNumber(currentXP)}',
                        style: TextStyle(color: Colors.pink.shade300, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        currentLevel < 100 ? 'Exp ${_formatNumber(nextLevelXP)}' : 'MAX',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLevelGrid(int currentLevel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: ShaderMask(
            shaderCallback: (bounds) =>
                LinearGradient(colors: [Colors.pink.shade300, Colors.purple.shade400]).createShader(bounds),
            child: const Text(
              'All Levels',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 101, // 0 to 100 inclusive
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemBuilder: (context, index) {
            return _buildLevelTile(index, currentLevel);
          },
        ),
      ],
    );
  }

  Widget _buildLevelTile(int level, int currentLevel) {
    int requiredXP = _getRequiredXP(level);
    bool isUnlocked = level <= currentLevel;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(
          color: currentLevel == level
              ? Colors.pink.withValues(alpha: 0.6)
              : isUnlocked
              ? AppColors.primary.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnlocked ? AppColors.primary.withValues(alpha: 0.2) : Colors.transparent,
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              double availableHeight = constraints.maxHeight - 50;
              double availableWidth = constraints.maxWidth - 24;
              double imageSize = availableWidth < availableHeight ? availableWidth : availableHeight;

              return Padding(
                padding: const EdgeInsets.all(0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/levels/rank_caifu_cf_$level.png',
                      width: imageSize,
                      height: imageSize,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: imageSize,
                          height: imageSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isUnlocked ? AppColors.primary.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.military_tech_rounded,
                              color: AppColors.primary,
                              size: imageSize * 0.4,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 4),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            'Lv $level',
                            style: TextStyle(
                              color: level == currentLevel
                                  ? Colors.pink.shade400
                                  : isUnlocked
                                  ? AppColors.primary
                                  : Colors.white.withValues(alpha: 0.5),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isUnlocked)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.lock_rounded, color: Colors.white.withValues(alpha: 0.5), size: 14),
                          ),
                      ],
                    ),

                    const SizedBox(height: 2),

                    Text(
                      'Exp ${_formatNumber(requiredXP)}',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildXPExplanation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.cyan.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_rounded, color: Colors.cyan, size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'Exp Explained',
                    style: TextStyle(color: Colors.cyan, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.amber.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset('assets/icons/beans.svg', colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn), width: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '1 Bean = 1 Exp',
                          style: TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      color: Colors.pink.withValues(alpha: 0.2),
                      border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.pink, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '1 Point = 1 Exp',
                          style: TextStyle(color: Colors.pink, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHowToLevelUp() {
    final List<LevelUpMethod> methods = [
      LevelUpMethod(title: 'Send Gift', icon: Icons.card_giftcard_rounded, color: Colors.pink),
      LevelUpMethod(title: 'Go Live', icon: Icons.live_tv, color: Colors.purple),
      LevelUpMethod(title: 'Recharge Coin', icon: Icons.diamond_outlined, color: Colors.amber),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: ShaderMask(
            shaderCallback: (bounds) =>
                LinearGradient(colors: [Colors.pink.shade300, Colors.purple.shade400]).createShader(bounds),
            child: const Text(
              'How do I level up?',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
        ),

        ...methods.asMap().entries.map((entry) {
          int index = entry.key;
          LevelUpMethod method = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.black.withValues(alpha: 0.3),
                border: Border.all(color: method.color.withValues(alpha: 0.3), width: 1),
                boxShadow: [
                  BoxShadow(color: method.color.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: method.color.withValues(alpha: 0.2)),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(color: method.color, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),

                      const SizedBox(width: 15),

                      Icon(method.icon, color: method.color, size: 24),

                      const SizedBox(width: 15),

                      Text(
                        method.title,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(2)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(2)}K';
    } else {
      return number.toString();
    }
  }
}

// Data Models
class LevelUpMethod {
  final String title;
  final IconData icon;
  final Color color;

  LevelUpMethod({required this.title, required this.icon, required this.color});
}

// ========== HELPER FUNCTIONS & CONSTANTS ==========

int _getRequiredXP(int level) {
  return LevelService.getRequiredXP(level);
}

int getSentLevel(int totalSent) {
  return LevelService.getSentLevel(totalSent);
}