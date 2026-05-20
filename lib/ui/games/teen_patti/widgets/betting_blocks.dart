import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/game_controller.dart';
import '../helpers/number_formatter.dart';

class BettingBlocks extends StatelessWidget {
  const BettingBlocks({super.key});

  @override
  Widget build(BuildContext context) {
    final GameController controller = Get.find();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Obx(() {
        final positions = controller.blockPositions;

        if (positions.isEmpty) {
          return const SizedBox();
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Position 0
            Expanded(
              child: _buildBlock(
                context,
                controller,
                positions[0].label,
                positions[0].chairImage,
                0,
              ),
            ),

            const SizedBox(width: 8),

            // Position 1
            Expanded(
              child: _buildBlock(
                context,
                controller,
                positions[1].label,
                positions[1].chairImage,
                1,
              ),
            ),

            const SizedBox(width: 8),

            // Position 2
            Expanded(
              child: _buildBlock(
                context,
                controller,
                positions[2].label,
                positions[2].chairImage,
                2,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBlock(
    BuildContext context,
    GameController controller,
    String blockName,
    String chairImage,
    int positionIndex,
  ) {
    return GestureDetector(
      onTap: () {
        if (controller.gameState.value == GameState.betting) {
          controller.placeBet(blockName);
        }
      },
      child: Obx(() {
        final shouldDim = controller.gameState.value == GameState.winAnimation &&
            controller.winningPosition.value != positionIndex;

        return Stack(
          children: [
            Column(
              children: [
                Image.asset(
                  chairImage,
                  height: 70,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 70,
                      color: Colors.brown,
                      child: const Icon(Icons.chair, color: Colors.white, size: 40),
                    );
                  },
                ),

                const SizedBox(height: 8),

                Container(
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        blockName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        'Pot: 1K',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),

                      const SizedBox(height: 4),
                      const Divider(),

                      Obx(() {
                        final userBets = controller.getBlockBets(blockName);
                        final userTotal = userBets.fold(0, (sum, bet) => sum + bet.value);

                        return Text(
                          'You: ${NumberFormatter.format(userTotal)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.purple,
                          ),
                        );
                      }),
                      const SizedBox(height: 4),
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
