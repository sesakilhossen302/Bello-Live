import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/game_controller.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final GameController controller = Get.find();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Teen Patti Record's",
          style: TextStyle(
            color: Color(0xFFF9C74F),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Chairs at top
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 15),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.black12, width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildChairHeader('assets/gameimages/chair_a.png', 'A'),
                _buildChairHeader('assets/gameimages/chair_b.png', 'B'),
                _buildChairHeader('assets/gameimages/chair_c.png', 'C'),
              ],
            ),
          ),

          // Records List
          Expanded(
            child: Obx(() {
              final recordsList = controller.gameRecords;

              if (recordsList.isEmpty) {
                return const Center(
                  child: Text(
                    'No records yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                itemCount: recordsList.length,
                itemBuilder: (context, index) {
                  final record = recordsList[index];
                  return _buildRecordRow(record);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildChairHeader(String chairImage, String label) {
    return SizedBox(
      width: 110,
      child: Column(
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
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordRow(GameRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.black12, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildResultIndicator('A', record.winningBlock == 'A'),
          _buildResultIndicator('B', record.winningBlock == 'B'),
          _buildResultIndicator('C', record.winningBlock == 'C'),
        ],
      ),
    );
  }

  Widget _buildResultIndicator(String label, bool isWinner) {
    return Container(
      width: 110,
      child: Center(
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isWinner ? const Color(0xFF228B22) : Colors.grey.shade400,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              isWinner ? 'Win' : 'Fail',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
