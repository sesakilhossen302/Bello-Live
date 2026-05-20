import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/game_controller.dart';
import 'widgets/card_display.dart';
import 'widgets/betting_blocks.dart';
import 'widgets/coin_selector.dart';
import 'widgets/game_counter.dart';
import 'widgets/game_header.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // If not already registered, put the controller
    final GameController controller = Get.put(GameController());

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/gameimages/bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 70),
              const CardDisplay(),
              const GameCounter(),
              const SizedBox(height: 20),
              const BettingBlocks(),
              const SizedBox(height: 20),
              const GameHeader(),
              const Spacer(),
              const CoinSelector(),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }
}
