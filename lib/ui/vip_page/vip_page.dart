import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import 'package:flutter_svg/flutter_svg.dart';

class VIPPage extends StatefulWidget {
  const VIPPage({super.key});

  @override
  State<VIPPage> createState() => _VIPPageState();
}

class _VIPPageState extends State<VIPPage> {
  // VIP pricing data
  final Map<Category, VIPTier> vipTiers = {
    Category.bronze: VIPTier(
      name: 'Bronze VIP',
      beans: 5000,
      color: Colors.orange.shade400,
      icon: Icons.workspace_premium,
    ),
    Category.silver: VIPTier(
      name: 'Silver VIP',
      beans: 15000,
      color: Colors.grey.shade300,
      icon: Icons.diamond_outlined,
    ),
    Category.gold: VIPTier(name: 'Gold VIP', beans: 35000, color: Colors.amber.shade400, icon: Icons.diamond_outlined),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF000000), Color(0xFF1a0a0a), Color(0xFF2d1b2b), Color(0xFF4a2c4a), Color(0xFFff6b9d)],
            stops: [0.0, 0.3, 0.6, 0.8, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildVIPTiersSection(),
                      const SizedBox(height: 30),
                      _buildPermissionsTable(),
                      const SizedBox(height: 30),
                      _buildUpgradeButtons(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 20, top: 0, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, size: 28, color: Colors.pink),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Row(
            children: [
              Icon(Icons.diamond_outlined, color: Colors.amber.shade400, size: 28),
              const SizedBox(width: 8),
              Text(
                'VIP Membership',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 2))],
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildVIPTiersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        // borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildTierCard(vipTiers[Category.bronze]!)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTierCard(vipTiers[Category.silver]!)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTierCard(vipTiers[Category.gold]!)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierCard(VIPTier tier) {
    return Container(
      height: 150,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.4),
        border: Border.all(color: tier.color.withValues(alpha: 0.4), width: 1),
        boxShadow: [BoxShadow(color: tier.color.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 6))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(tier.icon, color: tier.color, size: 30),
          const SizedBox(height: 8),
          Text(
            tier.name,
            style: TextStyle(color: tier.color, fontSize: 14, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/icons/beans.svg', colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn), width: 16),
              const SizedBox(width: 4),
              Text(
                _formatNumber(tier.beans),
                style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
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
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                  color: Colors.black.withValues(alpha: 0.2),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        'VIP Privileges',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
              : Icons.diamond,
          color: color,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildPermissionRow(Permission permission) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              permission.name,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: _buildAccessIndicator(permission.access[Category.bronze] ?? false, vipTiers[Category.bronze]!.color),
          ),
          Expanded(
            child: _buildAccessIndicator(permission.access[Category.silver] ?? false, vipTiers[Category.silver]!.color),
          ),
          Expanded(
            child: _buildAccessIndicator(permission.access[Category.gold] ?? false, vipTiers[Category.gold]!.color),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessIndicator(bool hasAccess, Color tierColor) {
    return Container(
      alignment: Alignment.center,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasAccess ? tierColor.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2),
          border: Border.all(color: hasAccess ? tierColor : Colors.grey.withValues(alpha: 0.4), width: 2),
          boxShadow: hasAccess
              ? [BoxShadow(color: tierColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: hasAccess
            ? Icon(Icons.check, color: tierColor, size: 16)
            : Icon(Icons.close, color: Colors.grey.withValues(alpha: 0.6), size: 16),
      ),
    );
  }

  Widget _buildUpgradeButtons() {
    return Column(
      children: [
        Text(
          'Choose Your VIP Plan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))],
          ),
        ),
        const SizedBox(height: 20),
        ...vipTiers.values
            .map((tier) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildUpgradeButton(tier)))
            ,
      ],
    );
  }

  Widget _buildUpgradeButton(VIPTier tier) {
    return GestureDetector(
      onTap: () {
        _showUpgradeDialog(tier);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(colors: [tier.color.withValues(alpha: 0.8), tier.color]),
          boxShadow: [BoxShadow(color: tier.color.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 6))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tier.icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              'Upgrade to ${tier.name}',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black.withValues(alpha: 0.3)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset('assets/icons/beans.svg', colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn), width: 12),
                  const SizedBox(width: 4),
                  Text(
                    _formatNumber(tier.beans),
                    style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
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
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Colors.transparent,
            contentPadding: EdgeInsets.zero,
            content: Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Colors.black.withValues(alpha: 0.8),
                border: Border.all(color: tier.color.withValues(alpha: 0.4), width: 1),
                boxShadow: [BoxShadow(color: tier.color.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tier.icon, color: tier.color, size: 50),
                  const SizedBox(height: 20),
                  Text(
                    'Upgrade to ${tier.name}?',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset('assets/icons/beans.svg', colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn), width: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatNumber(tier.beans)} Beans Required',
                        style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.grey.withValues(alpha: 0.3),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.5), width: 1),
                            ),
                            child: const Text(
                              'Cancel',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                            _handleUpgrade(tier);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(colors: [tier.color.withValues(alpha: 0.8), tier.color]),
                            ),
                            child: const Text(
                              'Upgrade',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleUpgrade(VIPTier tier) {
    debugPrint('Upgrading to ${tier.name} for ${tier.beans} beans');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully upgraded to ${tier.name}!'),
        backgroundColor: tier.color,
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

// Data Models
enum Category { bronze, silver, gold }

class Permission {
  final String name;
  final Map<Category, bool> access;

  Permission({required this.name, required this.access});

  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      name: json['name'],
      access: {
        Category.bronze: json['bronze'] ?? false,
        Category.silver: json['silver'] ?? false,
        Category.gold: json['gold'] ?? false,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "bronze": access[Category.bronze] ?? false,
      "silver": access[Category.silver] ?? false,
      "gold": access[Category.gold] ?? false,
    };
  }
}

class VIPTier {
  final String name;
  final int beans;
  final Color color;
  final IconData icon;

  VIPTier({required this.name, required this.beans, required this.color, required this.icon});
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
