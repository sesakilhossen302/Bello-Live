import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/game_controller.dart';

class TimerDisplay extends StatelessWidget {
  const TimerDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final GameController controller = Get.find();

    return Obx(() {
      final timer = controller.roundTimer.value;
      final gameState = controller.gameState.value;

      String displayText = '';

      if (gameState == GameState.betting) {
        displayText = '$timer';
      } else if (gameState == GameState.revealing) {
        displayText = 'Revealing...';
      } else {
        displayText = 'Complete';
      }

      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: Center(
          child: Text(
            displayText,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    });
  }
}
