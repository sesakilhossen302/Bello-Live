import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

import '../../navigation/routes.dart';

class RechargeDiamondsPage extends StatefulWidget {
  const RechargeDiamondsPage({super.key});

  @override
  State<RechargeDiamondsPage> createState() => _RechargeDiamondsPageState();
}

class _RechargeDiamondsPageState extends State<RechargeDiamondsPage> {
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1E42), // Consistent dark navy background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 16),
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Recharge Diamonds',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.stars, color: Colors.amber, size: 20),
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildBalanceCard(),
            const SizedBox(height: 16),
            Expanded(
              child: _buildPackagesGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF162B5B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'YOUR BALANCE',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.diamond, color: Colors.lightBlueAccent, size: 36),
              const SizedBox(width: 8),
              StreamBuilder<DocumentSnapshot>(
                stream: _userId != null 
                    ? FirebaseFirestore.instance.collection('users').doc(_userId).snapshots()
                    : null,
                builder: (context, snapshot) {
                  int balance = 0;
                  if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
                    final raw = snapshot.data!.data();
                    if (raw is Map<String, dynamic>) {
                      final val = raw['balance'] ?? raw['beans'] ?? 0;
                      if (val is num) {
                        balance = val.toInt();
                      } else {
                        balance = int.tryParse(val.toString()) ?? 0;
                      }
                    }
                  }
                  return Text(
                    balance.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPackagesGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recharge_packages')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No packages available.', style: TextStyle(color: Colors.white)));
        }

        // Sort locally to avoid needing a composite index in Firestore
        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final dynamic aRaw = aData['diamonds'] ?? 0;
          final dynamic bRaw = bData['diamonds'] ?? 0;
          final num aDiamonds = (aRaw is num) ? aRaw : (num.tryParse(aRaw.toString()) ?? 0);
          final num bDiamonds = (bRaw is num) ? bRaw : (num.tryParse(bRaw.toString()) ?? 0);
          return aDiamonds.compareTo(bDiamonds);
        });

        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75, // Adjust this ratio based on UI design
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            return _buildPackageItem(data, index);
          },
        );
      },
    );
  }

  Widget _buildPackageItem(Map<String, dynamic> data, int index) {
    final dynamic diamondsRaw = data['diamonds'];
    final int diamonds = (diamondsRaw is num)
        ? diamondsRaw.toInt()
        : (int.tryParse(diamondsRaw?.toString() ?? '0') ?? 0);
    final dynamic priceRaw = data['price'];
    final num price = (priceRaw is num) ? priceRaw : (num.tryParse(priceRaw?.toString() ?? '0') ?? 0);
    
    final bool isBestValue = index >= 4;
    final String tagText = isBestValue ? 'BEST VALUE' : 'POPULAR';
    final Color tagColor = isBestValue ? Colors.green.shade400 : Colors.lightBlue.shade400;

    final List<List<Color>> gradientColors = [
      [const Color(0xFF00B4DB), const Color(0xFF0083B0)],
      [const Color(0xFFF77062), const Color(0xFFFE5196)],
      [const Color(0xFF00B4DB), const Color(0xFF0083B0)],
      [const Color(0xFFF77062), const Color(0xFFFE5196)],
      [const Color(0xFF00B4DB), const Color(0xFF0083B0)],
      [const Color(0xFFF77062), const Color(0xFFFE5196)],
    ];
    final colorPair = gradientColors[index % gradientColors.length];

    return GestureDetector(
      onTap: () {
        context.push(Routes.resellerList.path);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF163C70),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Column(
          children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tagColor.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    tagText,
                    style: TextStyle(color: tagColor, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
                const Icon(Icons.diamond, color: Colors.lightBlueAccent, size: 16),
              ],
            ),
          ),
          const Spacer(flex: 1),
          const Icon(Icons.diamond, color: Colors.lightBlueAccent, size: 50),
          const SizedBox(height: 12),
          Text(
            _formatNumber(diamonds),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const Text(
            'Diamonds',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          ),
          const Spacer(flex: 2),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colorPair),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$price TK',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    ));
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      final str = number.toString();
      final len = str.length;
      if (len > 3) {
        return '${str.substring(0, len - 3)},${str.substring(len - 3)}';
      }
    }
    return number.toString();
  }
}
