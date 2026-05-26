import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../../theme/app_theme.dart';

/// A data model for the UI to display a top earner.
class DisplayEarner {
  final String userId; // Added userId for the frame
  final String name;
  final String pictureUrl;
  final int earnings;

  DisplayEarner({required this.userId, required this.name, required this.pictureUrl, required this.earnings});
}

/// A bottom sheet that displays the round results and auto-closes after 5 seconds.
class GameResultBottomSheet extends StatefulWidget {
  final String roundId;
  final int winningIndex;
  final String resultImagePath;
  final int totalEarnings;
  final int totalBets;
  final List<DisplayEarner> topEarners;

  const GameResultBottomSheet({
    super.key,
    required this.roundId,
    required this.winningIndex,
    required this.resultImagePath,
    required this.totalEarnings,
    required this.totalBets,
    required this.topEarners,
  });

  @override
  State<GameResultBottomSheet> createState() => _GameResultBottomSheetState();
}

class _GameResultBottomSheetState extends State<GameResultBottomSheet> {
  Timer? _timer;
  int _secondsRemaining = 5;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        if (mounted) {
          final route = ModalRoute.of(context);
          if (route != null &&
              route.isCurrent &&
              route.animation?.status != AnimationStatus.reverse &&
              route.animation?.status != AnimationStatus.dismissed) {
            Navigator.pop(context); // Auto-close the sheet
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _secondsRemaining--;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatCurrency(int amount) {
    return NumberFormat.decimalPattern().format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500);
    final highlightStyle = const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        decoration: BoxDecoration(
          color: const Color(0xFF2a1a4f),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: AppColors.pink, width: 2),
        ),
        child: Stack(
          children: [
            SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Round ${widget.roundId} Result:',
                    style: textStyle.copyWith(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Image.asset(widget.resultImagePath, height: 60, width: 60),
                  const SizedBox(height: 16),

                  RichText(
                    text: TextSpan(
                      text: 'This round earnings: ',
                      style: textStyle,
                      children: [
                        TextSpan(
                          text: _formatCurrency(widget.totalEarnings),
                          style: highlightStyle.copyWith(color: Colors.greenAccent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  RichText(
                    text: TextSpan(
                      text: 'This round bets: ',
                      style: textStyle,
                      children: [
                        TextSpan(
                          text: _formatCurrency(widget.totalBets),
                          style: highlightStyle.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'This Round Ranking',
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _buildTopEarnersRow(),
                ],
              ),
            ),

            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_secondsRemaining s',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopEarnersRow() {
    if (widget.topEarners.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          "No one won this round.",
          style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.topEarners.map((earner) {
        return Flexible(
          child: _buildTopEarnerProfile(
            userId: earner.userId,
            pictureUrl: earner.pictureUrl,
            name: earner.name,
            amount: earner.earnings,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopEarnerProfile({
    required String userId,
    required String pictureUrl,
    required String name,
    required int amount,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Profile Picture with Active Frame ---
        SizedBox(
          width: 50, // radius 25 * 2
          height: 50,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.pinkLight,
                backgroundImage: CachedNetworkImageProvider(pictureUrl),
                onBackgroundImageError: (e, s) => const Icon(Icons.person, color: Colors.white),
              ),
              // Overlay the Frame (50 * 1.3 = 65)
              Positioned(
                width: 65,
                height: 65,
                child: IgnorePointer(child: ActiveFrameWidget(userId: userId, size: 65)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10), // Increased slightly to give the frame space
        Text(
          name,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(
          _formatCurrency(amount),
          style: const TextStyle(color: Colors.amber, fontSize: 14, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}
