import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/gift_image_widget.dart';
import '../../data/remote/firebase/store_service.dart';
import '../../navigation/routes.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  Map<String, List<StoreItemModel>> _storeItems = {};
  List<String> _categories = [];
  bool _isLoading = true;
  int _userDiamonds = 0;
  String? _userPhotoUrl;
  Set<String> _purchasedItemIds = {};
  Map<String, String> _activeItems = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final items = await StoreService.fetchStoreItems();
      final bagItems = await StoreService.fetchMyBagItems();
      
      Set<String> purchasedItemIds = {};
      for (var list in bagItems.values) {
        for (var item in list) {
          purchasedItemIds.add(item.id);
        }
      }

      String? photoUrl;
      int balance = 0;
      Map<String, String> activeItems = {};
      
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        final userData = doc.data();
        photoUrl = userData?['photoUrl'] as String?;
        final rawBalance = userData?['balance'] ?? userData?['beans'] ?? 0;
        if (rawBalance is num) {
          balance = rawBalance.toInt();
        } else {
          balance = int.tryParse(rawBalance.toString()) ?? 0;
        }
        
        final addOns = userData?['activeAddOns'] as Map<String, dynamic>? ?? {};
        final now = DateTime.now();
        addOns.forEach((cat, itemData) {
          final expiry = itemData['expiresAt'] as Timestamp?;
          final url = itemData['imageUrl'] as String?;
          if (url != null && (expiry == null || expiry.toDate().isAfter(now))) {
            activeItems[cat] = url;
          }
        });
      }

      final allowed = ['frame', 'entry', 'identry', 'id entry', 'room screen', 'roomskin'];
      final categories = items.keys.where((c) => allowed.contains(c.toLowerCase().trim())).toList()..sort();

      setState(() {
        _storeItems = items;
        _categories = categories;
        _userDiamonds = balance;
        _userPhotoUrl = photoUrl;
        _purchasedItemIds = purchasedItemIds;
        _activeItems = activeItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading store: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF5A189A)))
                  : _categories.isEmpty
                      ? const Center(
                          child: Text(
                            'No items available in store',
                            style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        )
                      : DefaultTabController(
                          length: _categories.length,
                          child: Column(
                            children: [
                              _buildTabBar(),
                              Expanded(
                                child: TabBarView(
                                  children: _categories.map((category) {
                                    return SingleChildScrollView(child: _buildStoreGrid(category));
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: const Color(0xFF5A189A),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, size: 26, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Text(
              'Store',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          // Coin Balance Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFA000),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$_userDiamonds',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // My Bag Button
          GestureDetector(
            onTap: () {
              context.push(Routes.myBag.path);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Text(
                'My Bag',
                style: TextStyle(color: Color(0xFF5A189A), fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: const Color(0xFF0F1E42),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        isScrollable: _categories.length > 3,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: const LinearGradient(colors: [Color(0xFF5A189A), Color(0xFFFF7043)]),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5A189A).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: _categories.map((category) => Tab(text: category)).toList(),
      ),
    );
  }

  Widget _buildStoreGrid(String category) {
    final items = _storeItems[category] ?? [];

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 50),
        child: Center(
          child: Text(
            "No items available",
            style: TextStyle(color: Colors.white60, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    final int crossAxisCount = category == 'Entry' ? 1 : 2;
    final double childAspectRatio = category == 'Entry' ? 2.0 : 0.85;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final isPurchased = _purchasedItemIds.contains(item.id);
          final isActive = _activeItems[item.category] == item.imageUrl;
          return StoreItemCard(
            item: item,
            userPhotoUrl: _userPhotoUrl,
            onPurchaseComplete: _loadData,
            isPurchased: isPurchased,
            isActive: isActive,
            onEquipToggle: (equip) async {
              try {
                await StoreService.toggleActiveItem(item, equip);
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
          );
        },
      ),
    );
  }
}

class StoreItemCard extends StatefulWidget {
  final StoreItemModel item;
  final VoidCallback onPurchaseComplete;
  final String? userPhotoUrl;
  final bool isPurchased;
  final bool isActive;
  final Function(bool) onEquipToggle;

  const StoreItemCard({
    super.key,
    required this.item,
    required this.onPurchaseComplete,
    this.userPhotoUrl,
    this.isPurchased = false,
    this.isActive = false,
    required this.onEquipToggle,
  });

  @override
  State<StoreItemCard> createState() => _StoreItemCardState();
}

class _StoreItemCardState extends State<StoreItemCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 150), vsync: this);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handlePurchase() async {
    if (widget.isActive) {
      widget.onEquipToggle(false);
      return;
    }
    if (widget.isPurchased) {
      widget.onEquipToggle(true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162B5B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Purchase',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.item.category == 'Frame')
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: Container(
                      width: 80,
                      height: 80,
                      color: const Color(0xFF0F1E42),
                      child: widget.userPhotoUrl != null && widget.userPhotoUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.userPhotoUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Color(0xFF5A189A), strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) =>
                                  const Icon(Icons.person, size: 40, color: Colors.white54),
                            )
                          : const Icon(Icons.person, size: 40, color: Colors.white54),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: MyImageWidget(
                      imageUrl: widget.item.imageUrl,
                      fit: BoxFit.contain,
                      playAudio: true,
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                height: 120,
                child: MyImageWidget(
                  imageUrl: widget.item.imageUrl,
                  fit: BoxFit.contain,
                  playAudio: true,
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Buy ${widget.item.name} for ${widget.item.price} coins/month?',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buy', style: TextStyle(color: Color(0xFF5A189A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isPurchasing = true);
    try {
      await StoreService.buyItem(widget.item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully purchased ${widget.item.name}!'),
            backgroundColor: const Color(0xFF5A189A),
          ),
        );
        widget.onPurchaseComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _animationController.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _animationController.reverse();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _animationController.reverse();
      },
      onTap: _isPurchasing ? null : _handlePurchase,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF0F1E42),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                  if (_isPressed)
                    BoxShadow(
                      color: const Color(0xFF5A189A).withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 0),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: _isPurchasing
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF5A189A)))
                            : MyImageWidget(
                                imageUrl: widget.item.imageUrl,
                                fit: BoxFit.contain,
                                playAudio: false,
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: widget.item.category == 'Entry' ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        if (widget.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green),
                            ),
                            child: const Text('Used', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        else if (widget.isPurchased)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.blue),
                            ),
                            child: const Text('Use', style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                        else
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Color(0xFFFFA000), size: 14),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${widget.item.price} coins/mo',
                                  style: const TextStyle(
                                    color: Color(0xFFFFA000),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
