import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/game_controller.dart';
import 'flip_card_widget.dart';

class CardDisplay extends StatelessWidget {
  const CardDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final GameController controller = Get.find();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Card Position 0
          Expanded(
            child: Obx(() {
              return Stack(
                children: [
                  FlipCardWidget(
                    showFront: !controller.revealedCards[0],
                    frontImage: 'assets/gameimages/card_back.png',
                    backImage: controller.positionCards.isNotEmpty &&
                            controller.positionCards[0].isNotEmpty
                        ? controller.positionCards[0]
                        : 'assets/gameimages/card_back.png',
                  ),
                  if (controller.dimNonWinningCards[0])
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),

          const SizedBox(width: 10),

          // Card Position 1
          Expanded(
            child: Obx(() {
              return Stack(
                children: [
                  FlipCardWidget(
                    showFront: !controller.revealedCards[1],
                    frontImage: 'assets/gameimages/card_back.png',
                    backImage: controller.positionCards.length > 1 &&
                            controller.positionCards[1].isNotEmpty
                        ? controller.positionCards[1]
                        : 'assets/gameimages/card_back.png',
                  ),
                  if (controller.dimNonWinningCards[1])
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),

          const SizedBox(width: 10),

          // Card Position 2
          Expanded(
            child: Obx(() {
              return Stack(
                children: [
                  FlipCardWidget(
                    showFront: !controller.revealedCards[2],
                    frontImage: 'assets/gameimages/card_back.png',
                    backImage: controller.positionCards.length > 2 &&
                            controller.positionCards[2].isNotEmpty
                        ? controller.positionCards[2]
                        : 'assets/gameimages/card_back.png',
                  ),
                  if (controller.dimNonWinningCards[2])
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
