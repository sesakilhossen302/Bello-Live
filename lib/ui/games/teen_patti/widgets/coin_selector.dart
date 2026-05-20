import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/game_controller.dart';
import '../helpers/number_formatter.dart';
import '../teen_patti_records.dart';

class CoinSelector extends StatelessWidget {
  const CoinSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final GameController controller = Get.find();

    final coins = [
      {'value': 100, 'image': 'assets/gameimages/coin_100.png'},
      {'value': 1000, 'image': 'assets/gameimages/coin_1k.png'},
      {'value': 10000, 'image': 'assets/gameimages/coin_10k.png'},
      {'value': 50000, 'image': 'assets/gameimages/coin_50K.png'},
      {'value': 100000, 'image': 'assets/gameimages/coin_100k.png'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade900, Colors.red.shade800],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.yellow.shade700, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Total balance
          Obx(() {
            return Row(
              children: [
                Image.asset(
                  'assets/gameimages/coin.png',
                  width: 22,
                  height: 22,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.monetization_on,
                        color: Colors.white,
                        size: 12,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 3),
                Text(
                  NumberFormatter.format(controller.totalCoins.value),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            );
          }),

          // Coins
          ...coins.map((coin) {
            final value = coin['value'] as int;
            final image = coin['image'] as String;

            return Obx(() {
              final isSelected = controller.selectedCoinValue.value == value;

              return GestureDetector(
                onTap: () {
                  if (controller.gameState.value == GameState.betting) {
                    controller.selectCoin(value, image);
                  }
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: EdgeInsets.all(isSelected ? 2 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
                  ),
                  child: Image.asset(
                    image,
                    width: 35,
                    height: 35,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 35,
                        height: 35,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${value ~/ 1000}K',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            });
          }).toList(),

          // Records Button
          GestureDetector(
            onTap: () {
              Get.to(() => const RecordsScreen());
            },
            child: Container(
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.access_time,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
