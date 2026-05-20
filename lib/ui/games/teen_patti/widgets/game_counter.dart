import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/game_controller.dart';

class GameCounter extends StatelessWidget {
  const GameCounter({super.key});

  @override
  Widget build(BuildContext context) {
    final GameController controller = Get.find();

    return Obx(() {
      final timer = controller.roundTimer.value;
      final gameState = controller.gameState.value;

      if (gameState != GameState.betting) {
        return const SizedBox.shrink();
      }

      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '$timer',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    });
  }
}
