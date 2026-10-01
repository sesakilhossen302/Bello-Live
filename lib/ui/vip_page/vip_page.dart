import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VIPPage extends StatefulWidget {
  const VIPPage({super.key});

  @override
  State<VIPPage> createState() => _VIPPageState();
}

class _VIPPageState extends State<VIPPage> {
  final Map<Category, VIPTier> vipTiers = {
    Category.bronze: VIPTier(
      name: 'Bronze VIP',
      beans: 5000,
      color: const Color(0xFFCD7F32),
      icon: Icons.workspace_premium,
    ),
    Category.silver: VIPTier(
      name: 'Silver VIP',
      beans: 15000,
      color: const Color(0xFF78909C),
      icon: Icons.diamond_outlined,
    ),
    Category.gold: VIPTier(
      name: 'Gold VIP',
      beans: 35000,
      color: const Color(0xFFFFB300),
      icon: Icons.diamond_rounded,
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildVIPTiersSection(),
                    const SizedBox(height: 20),
                    _buildPermissionsTable(),
                    const SizedBox(height: 24),
                    _buildUpgradeButtons(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: const Color(0xFF5A189A),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, size: 26, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.diamond_rounded, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          const Text(
            'VIP Membership',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVIPTiersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0F1E42),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _buildTierCard(vipTiers[Category.bronze]!)),
          const SizedBox(width: 10),
          Expanded(child: _buildTierCard(vipTiers[Category.silver]!)),
          const SizedBox(width: 10),
          Expanded(child: _buildTierCard(vipTiers[Category.gold]!)),
        ],
      ),
    );
  }

  Widget _buildTierCard(VIPTier tier) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: tier.color.withValues(alpha: 0.08),
        border: Border.all(color: tier.color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tier.color.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tier.icon, color: tier.color, size: 34),
          const SizedBox(height: 8),
          Text(
            tier.name,
            style: TextStyle(color: tier.color, fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
              const SizedBox(width: 4),
              Text(
                '${_formatNumber(tier.beans)} Coins',
                style: TextStyle(
                  color: Colors.amber.shade900,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsTable() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF0F1E42),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              color: const Color(0xFF162B5B),
              child: Row(
                children: [
                  const Expanded(
                    flex: 3,
                    child: Text(
                      'VIP Privileges',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(child: _buildHeaderCell('Bronze', vipTiers[Category.bronze]!.color)),
                  Expanded(child: _buildHeaderCell('Silver', vipTiers[Category.silver]!.color)),
                  Expanded(child: _buildHeaderCell('Gold', vipTiers[Category.gold]!.color)),
                ],
              ),
            ),

            // Permissions List
            ...permissions.map((permission) => _buildPermissionRow(permission)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String title, Color color) {
    return Column(
      children: [
        Icon(
          title == 'Bronze'
              ? Icons.workspace_premium
              : title == 'Silver'
                  ? Icons.diamond_outlined
                  : Icons.diamond_rounded,
          color: color,
          size: 18,
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPermissionRow(Permission permission) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 0.8)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              permission.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: _buildAccessIndicator(
              permission.access[Category.bronze] ?? false,
              vipTiers[Category.bronze]!.color,
            ),
          ),
          Expanded(
            child: _buildAccessIndicator(
              permission.access[Category.silver] ?? false,
              vipTiers[Category.silver]!.color,
            ),
          ),
          Expanded(
            child: _buildAccessIndicator(
              permission.access[Category.gold] ?? false,
              vipTiers[Category.gold]!.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessIndicator(bool hasAccess, Color tierColor) {
    return Container(
      alignment: Alignment.center,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasAccess ? tierColor : Colors.grey.withValues(alpha: 0.15),
        ),
        child: Icon(
          hasAccess ? Icons.check : Icons.close,
          color: hasAccess ? Colors.white : Colors.grey,
          size: 15,
        ),
      ),
    );
  }

  Widget _buildUpgradeButtons() {
    return Column(
      children: [
        const Text(
          'Choose Your VIP Plan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...vipTiers.values
            .map((tier) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildUpgradeButton(tier),
                )),
      ],
    );
  }

  Widget _buildUpgradeButton(VIPTier tier) {
    return GestureDetector(
      onTap: () => _showUpgradeDialog(tier),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(colors: [tier.color, tier.color.withValues(alpha: 0.85)]),
          boxShadow: [
            BoxShadow(
              color: tier.color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tier.icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              'Upgrade to ${tier.name}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.black.withValues(alpha: 0.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(tier.beans),
                    style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpgradeDialog(VIPTier tier) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF162B5B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(tier.icon, color: tier.color, size: 48),
              const SizedBox(height: 16),
              Text(
                'Upgrade to ${tier.name}?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${_formatNumber(tier.beans)} Coins Required',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEFEFF4),
                        foregroundColor: const Color(0xFF1C1C1E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleUpgrade(tier);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tier.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: const Text('Upgrade', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleUpgrade(VIPTier tier) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully upgraded to ${tier.name}!'),
        backgroundColor: const Color(0xFF5A189A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }
}

enum Category { bronze, silver, gold }

class Permission {
  final String name;
  final Map<Category, bool> access;

  Permission({required this.name, required this.access});
}

class VIPTier {
  final String name;
  final int beans;
  final Color color;
  final IconData icon;

  VIPTier({
    required this.name,
    required this.beans,
    required this.color,
    required this.icon,
  });
}

final permissions = [
  Permission(
    name: "Special message bubble",
    access: {Category.bronze: true, Category.silver: true, Category.gold: true},
  ),
  Permission(name: "Profile views", access: {Category.bronze: true, Category.silver: true, Category.gold: true}),
  Permission(name: "Hide VIP Status", access: {Category.bronze: true, Category.silver: true, Category.gold: true}),
  Permission(name: "Hide sent coins", access: {Category.bronze: true, Category.silver: true, Category.gold: true}),
  Permission(name: "Hide online status", access: {Category.bronze: true, Category.silver: true, Category.gold: true}),
  Permission(name: "Hide support service", access: {Category.bronze: true, Category.silver: true, Category.gold: true}),
  Permission(name: "VIP Badge", access: {Category.bronze: true, Category.silver: true, Category.gold: true}),
  Permission(name: "Special Enter Effect", access: {Category.bronze: true, Category.silver: true, Category.gold: true}),
  Permission(name: "Profile Card", access: {Category.bronze: true, Category.silver: true, Category.gold: true}),
  Permission(name: "VIP store", access: {Category.bronze: true, Category.silver: true, Category.gold: true}),
  Permission(
    name: "Special Profile Design",
    access: {Category.bronze: true, Category.silver: true, Category.gold: true},
  ),
  Permission(
    name: "Hide received diamonds",
    access: {Category.bronze: false, Category.silver: true, Category.gold: true},
  ),
  Permission(name: "Bronze VIP gifts", access: {Category.bronze: false, Category.silver: true, Category.gold: true}),
  Permission(name: "Silver VIP gifts", access: {Category.bronze: false, Category.silver: true, Category.gold: true}),
  Permission(name: "Gold VIP gifts", access: {Category.bronze: false, Category.silver: false, Category.gold: true}),
  Permission(
    name: "Hide from profile viewer list",
    access: {Category.bronze: false, Category.silver: false, Category.gold: true},
  ),
];
