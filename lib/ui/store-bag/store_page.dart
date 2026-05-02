import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/gift_image_widget.dart';
import '../../data/remote/firebase/profile_services.dart';
import '../../data/remote/firebase/store_service.dart';
import '../../navigation/routes.dart';
import '../../theme/app_theme.dart';

class StorePage extends StatefulWidget {
  const StorePage({super.key});

  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  Map<String, List<StoreItemModel>> _storeItems = {};
  List<String> _categories = [];
  bool _isLoading = true;
  int _userBalance = 0;
  String? _userPhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final items = await StoreService.fetchStoreItems();
      final balance = await ProfileService.getCurrentUserBalance();

      String? photoUrl;
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        photoUrl = doc.data()?['photoUrl'] as String?;
      }

      final categories = items.keys.toList()..sort();

      setState(() {
        _storeItems = items;
        _categories = categories;
        _userBalance = balance;
        _userPhotoUrl = photoUrl;
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
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.purple))
                    : _categories.isEmpty
                    ? const Center(
                  child: Text('No items available in store', style: TextStyle(color: Colors.white)),
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
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 16, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.back, size: 28, color: Colors.purple),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          const Expanded(
            child: Text(
              'Store',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),

          // My Bag Button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.black.withValues(alpha: 0.3),
              border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [Colors.amber.shade300, Colors.amber.shade600]),
                      ),
                      child: const Icon(Icons.monetization_on, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_userBalance',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8), // Spacing between the two buttons
          // Coin Balance Display
          GestureDetector(
            onTap: () {
              context.push(Routes.myBag.path);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withValues(alpha: 0.3),
                border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'My Bag',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: TabBar(
            isScrollable: _categories.length > 4,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: LinearGradient(colors: [Colors.purple.shade400, Colors.purple.shade600]),
              boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 0))],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: _categories.map((category) => Tab(text: category)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreGrid(String category) {
    final items = _storeItems[category] ?? [];

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 50),
        child: Center(
          child: Text("No items available", style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    // Adjust grid properties based on category
    final int crossAxisCount = category == 'Entry' ? 1 : 2;
    final double childAspectRatio = category == 'Entry' ? 2.0 : 0.85;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return StoreItemCard(item: items[index], userPhotoUrl: _userPhotoUrl, onPurchaseComplete: _loadData);
        },
      ),
    );
  }
}

class StoreItemCard extends StatefulWidget {
  final StoreItemModel item;
  final VoidCallback onPurchaseComplete;
  final String? userPhotoUrl;

  const StoreItemCard({super.key, required this.item, required this.onPurchaseComplete, this.userPhotoUrl});

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Confirm Purchase', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Frame visualization logic
            if (widget.item.category == 'Frame')
              Stack(
                alignment: Alignment.center,
                children: [
                  ClipOval(
                    child: Container(
                      width: 80, // Equivalent to radius: 40 (40 * 2)
                      height: 80,
                      color: Colors.grey.shade800,
                      child: widget.userPhotoUrl != null && widget.userPhotoUrl!.isNotEmpty
                          ? CachedNetworkImage(
                        imageUrl: widget.userPhotoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.purple, strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                        const Icon(Icons.person, size: 40, color: Colors.white54),
                      )
                          : const Icon(Icons.person, size: 40, color: Colors.white54),
                    ),
                  ),
                  SizedBox(
                    width: 120, // Adjust this to fit nicely around the 40 radius avatar
                    height: 120,
                    child: MyImageWidget(
                      imageUrl: widget.item.imageUrl,
                      fit: BoxFit.contain, // Contain ensures the frame stays proportional
                      playAudio: true, // Allow sound in the dialog
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
                  playAudio: true, // Allow sound in the dialog
                ),
              ),

            const SizedBox(height: 20),
            Text(
              'Buy ${widget.item.name} for ${widget.item.price} beans/month?',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buy', style: TextStyle(color: Colors.purple)),
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
          SnackBar(content: Text('Successfully purchased ${widget.item.name}!'), backgroundColor: Colors.green),
        );
        widget.onPurchaseComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
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
                color: Colors.black.withValues(alpha: 0.3),
                border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 1),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 4)),
                  if (_isPressed)
                    BoxShadow(color: Colors.pink.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 0)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                                ? const Center(child: CircularProgressIndicator(color: Colors.pink))
                                : MyImageWidget(
                              imageUrl: widget.item.imageUrl,
                              fit: BoxFit.contain, // Display fully in grid
                              playAudio: false, // Explicitly mute in grid list
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, // Takes up only needed space
                          children: [
                            Text(
                              widget.item.name,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              maxLines: widget.item.category == 'Entry' ? 1 : 2, // single line if wide
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8), // Spacing between name and price
                            Row(
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [Colors.amber.shade300, Colors.amber.shade600]),
                                  ),
                                  child: const Icon(Icons.monetization_on, color: Colors.white, size: 12),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${widget.item.price} beans/mo',
                                    style: TextStyle(
                                      color: Colors.pink.shade300,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
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
              ),
            ),
          );
        },
      ),
    );
  }
}
