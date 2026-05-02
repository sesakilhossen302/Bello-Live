import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../navigation/routes.dart';
import '../home_cubit.dart';

class PKTab extends StatelessWidget {
  // 👉 INJECTED CUBIT HERE
  final HomeCubit cubit;

  const PKTab({super.key, required this.cubit});

  @override
  Widget build(BuildContext context) {
    // 👉 Listen to the centralized stream from Cubit
    return StreamBuilder<List<PKBattleCard>>(
      stream: cubit.pkBattlesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Colors.pink));
        }

        final pkBattles = snapshot.data ?? [];

        if (pkBattles.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 80, top: 10),
          itemCount: pkBattles.length * 2, // 2 cards per battle
          itemBuilder: (context, index) {
            final battleIndex = index ~/ 2;
            final isFirstCard = index % 2 == 0;
            final battle = pkBattles[battleIndex];
            final isTopMatch = battleIndex < 3; // Top 3 battles get special animations

            if (isFirstCard) {
              // A vs B card
              return _buildVSCard(
                context,
                roomId: battle.roomAId,
                hostAName: battle.hostAName,
                hostBName: battle.hostBName,
                hostAPicture: battle.hostAPicture,
                hostBPicture: battle.hostBPicture,
                viewCountA: battle.participantCountA,
                viewCountB: battle.participantCountB,
                pkEndTime: battle.pkEndTime,
                isTopMatch: isTopMatch,
                matchRank: battleIndex,
              );
            } else {
              // B vs A card (reversed view)
              return _buildVSCard(
                context,
                roomId: battle.roomBId,
                hostAName: battle.hostBName,
                hostBName: battle.hostAName,
                hostAPicture: battle.hostBPicture,
                hostBPicture: battle.hostAPicture,
                viewCountA: battle.participantCountB,
                viewCountB: battle.participantCountA,
                pkEndTime: battle.pkEndTime,
                isTopMatch: isTopMatch,
                matchRank: battleIndex,
              );
            }
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_kabaddi, size: 80, color: Colors.white.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'No Active PK Battles',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'PK battles will appear here when hosts start competing',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildVSCard(
    BuildContext context, {
    required String roomId,
    required String hostAName,
    required String hostBName,
    required String? hostAPicture,
    required String? hostBPicture,
    required int viewCountA,
    required int viewCountB,
    required int? pkEndTime,
    required bool isTopMatch,
    required int matchRank,
  }) {
    return GestureDetector(
      onTap: () {
        context.push(Routes.liveStream.path, extra: {"roomId": roomId, "isHost": false});
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF0a0a0a),
          boxShadow: [
            BoxShadow(
              color: isTopMatch ? Colors.purple.withValues(alpha: 0.3) : Colors.purple.withValues(alpha: 0.5),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    Expanded(child: _buildStreamerSide(hostAName, hostAPicture, viewCountA, true, isTopMatch)),
                    _buildVSSection(viewCountA, viewCountB, pkEndTime, isTopMatch),
                    Expanded(child: _buildStreamerSide(hostBName, hostBPicture, viewCountB, false, isTopMatch)),
                  ],
                ),
              ),
              if (isTopMatch) _buildTopMatchIndicator(matchRank),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopMatchIndicator(int matchRank) {
    final ranks = ['🥇', '🥈', '🥉'];
    final rankIcon = matchRank < 3 ? ranks[matchRank] : '🔥';

    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          width: 120,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.yellow.shade600, Colors.orange.shade600]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: Colors.yellow.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(rankIcon, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              const Text(
                'TOP MATCH',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStreamerSide(String name, String? pictureUrl, int viewCount, bool isLeft, bool isTopMatch) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Stack(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: isTopMatch
                      ? [Colors.pink.shade300, Colors.purple.shade400]
                      : [Colors.grey.shade600, Colors.grey.shade800],
                ),
                boxShadow: [
                  BoxShadow(
                    color: isTopMatch ? Colors.pink.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: pictureUrl ?? '',
                  fit: BoxFit.cover,
                  errorWidget: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey[800]),
                      child: Icon(Icons.person, color: Colors.white.withValues(alpha: 0.7), size: 35),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: isLeft ? 0 : null,
              left: isLeft ? null : 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade600]),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    '${(viewCount / 100).round()}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isTopMatch ? Colors.pink.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: isLeft ? TextAlign.start : TextAlign.end,
          ),
        ),

        const SizedBox(height: 6),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade600.withValues(alpha: 0.8), Colors.blue.shade800.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flash_on, size: 12, color: Colors.yellow.shade300),
              const SizedBox(width: 2),
              Text(
                '$viewCount',
                style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVSSection(int viewCountA, int viewCountB, int? pkEndTime, bool isTopMatch) {
    final total = viewCountA + viewCountB;
    final percentageA = total > 0 ? (viewCountA / total) : 0.5;

    String timeRemaining = 'BATTLE';
    if (pkEndTime != null) {
      final endTime = DateTime.fromMillisecondsSinceEpoch(pkEndTime);
      final remaining = endTime.difference(DateTime.now());
      if (!remaining.isNegative) {
        final minutes = remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
        final seconds = remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
        timeRemaining = '$minutes:$seconds';
      }
    }

    return SizedBox(
      width: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isTopMatch
                    ? [Colors.red.shade500, Colors.red.shade700]
                    : [Colors.grey.shade600, Colors.grey.shade800],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: isTopMatch ? Colors.red.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'VS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black)],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Container(
            width: 60,
            height: 8,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: Colors.black.withValues(alpha: 0.3)),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 60 * percentageA,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(colors: [Colors.blue.shade400, Colors.blue.shade600]),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 60 * (1 - percentageA),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(colors: [Colors.red.shade400, Colors.red.shade600]),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          Text(
            timeRemaining,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isTopMatch ? Colors.pink.shade300 : Colors.white.withValues(alpha: 0.8),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// Data model for PK battles exposed directly for the Cubit stream
class PKBattleCard {
  final String roomAId;
  final String roomBId;
  final String hostAName;
  final String hostBName;
  final String? hostAPicture;
  final String? hostBPicture;
  final int participantCountA;
  final int participantCountB;
  final int? pkEndTime;

  PKBattleCard({
    required this.roomAId,
    required this.roomBId,
    required this.hostAName,
    required this.hostBName,
    this.hostAPicture,
    this.hostBPicture,
    required this.participantCountA,
    required this.participantCountB,
    this.pkEndTime,
  });
}
