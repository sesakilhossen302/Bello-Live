import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../navigation/routes.dart';
import '../../games/greedy_game_bottomsheet.dart';
import '../../games/spinner_game_bottomsheet.dart';

class GamesListBottomSheet extends StatelessWidget {
  const GamesListBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> games = [
      {
        'name': 'Greedy',
        'image': 'assets/greedy/greedy.jpeg',
        'onTap': () {
          Navigator.pop(context);
          showGreedyGameBottomSheet(context);
        },
      },
      {
        'name': 'Fruits King',
        'image': 'assets/spinner/fruits.jpeg',
        'onTap': () {
          Navigator.pop(context);
          showFruitsKingBottomSheet(context);
        },
      },
      {
        'name': 'Tin Patti',
        'image': 'assets/gameimages/card_back.png',
        'onTap': () {
          Navigator.pop(context);
          context.push(Routes.teenPatti.path);
        },
      },
      {
        'name': 'Animal Game',
        'image': 'assets/animalgame/bg.png',
        'onTap': () {
          Navigator.pop(context);
          context.push(Routes.animalGame.path);
        },
      },
    ];

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Color(0xFF2d1b2b),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              child: Row(
                children: [
                  const Text(
                    'Games',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, height: 1, thickness: 1),

            // Games Grid
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.builder(
                  itemCount: games.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    return _buildGameCard(context, games[index]);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, Map<String, dynamic> game) {
    return GestureDetector(
      onTap: game['onTap'],
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple.withValues(alpha: 0.3), Colors.pink.withValues(alpha: 0.3)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.asset(
                  game['image'],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey.shade800,
                      width: double.infinity,
                      child: const Icon(Icons.games, size: 60, color: Colors.white54),
                    );
                  },
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      game['name'],
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showGamesListBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return const GamesListBottomSheet();
    },
  );
}
