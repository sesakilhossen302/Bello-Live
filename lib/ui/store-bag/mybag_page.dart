import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui';

import '../../core/widgets/gift_image_widget.dart';
import '../../data/remote/firebase/store_service.dart';
import '../../navigation/routes.dart';
import '../../theme/app_theme.dart';

class MyBagPage extends StatefulWidget {
  const MyBagPage({super.key});

  @override
  State<MyBagPage> createState() => _MyBagPageState();
}

class _MyBagPageState extends State<MyBagPage> {
  Map<String, List<StoreItemModel>> _bagItems = {};
  List<String> _categories = [];
  bool _isLoading = true;
  Map<String, String> _activeAddOns = {};

  @override
  void initState() {
    super.initState();
    _loadData();

    StoreService.getActiveAddOnsStream().listen((addOns) {
      if (mounted) {
        setState(() => _activeAddOns = addOns);
      }
    });
  }

  Future<void> _loadData() async {
    try {
      final items = await StoreService.fetchMyBagItems();
      final categories = items.keys.toList()..sort();

      setState(() {
        _bagItems = items;
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading bag: $e')));
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
                  child: Text("Your bag is empty. Visit the store!", style: TextStyle(color: Colors.white54)),
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
              'My Bag',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              await context.push(Routes.store.path);
              _loadData();
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
                        'Store',
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
              boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 0))],
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
    final items = _bagItems[category] ?? [];

    // Adjust grid properties based on category (slightly taller ratio than Store to fit the Use button)
    final int crossAxisCount = category == 'Entry' ? 1 : 2;
    final double childAspectRatio = category == 'Entry' ? 2 : 0.75;

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
          final item = items[index];
          // Check if THIS specific item is the active one in its category
          final isEquipped = _activeAddOns[item.category] == item.imageUrl;

          return BagItemCard(
            item: item,
            isEquipped: isEquipped,
            onEquipToggle: () async {
              try {
                // Call our new toggle method
                await StoreService.toggleActiveItem(item, !isEquipped);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
          );
        },
      ),
    );
  }
}

class BagItemCard extends StatelessWidget {
  final StoreItemModel item;
  final bool isEquipped;
  final VoidCallback onEquipToggle;

  const BagItemCard({super.key, required this.item, required this.isEquipped, required this.onEquipToggle});

  @override
  Widget build(BuildContext context) {
    final expStr = item.expiresAt != null
        ? '${item.expiresAt!.day}/${item.expiresAt!.month}/${item.expiresAt!.year}'
        : 'Never';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.3),
        border: Border.all(color: isEquipped ? Colors.purple : Colors.pink.withValues(alpha: 0.3), width: isEquipped ? 2 : 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 4)),
          if (isEquipped) BoxShadow(color: Colors.purple.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 0)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: MyImageWidget(
                      imageUrl: item.imageUrl,
                      fit: BoxFit.contain, // Show entire image
                      playAudio: false, // Explicitly muted in list view
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min, // Takes up only needed space
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2), // Slight spacing between name and expiry
                    Text('Exp: $expStr', style: TextStyle(color: Colors.grey.shade400, fontSize: 11), maxLines: 1),
                    const SizedBox(height: 8), // Spacing before the button
                    ElevatedButton(
                      onPressed: onEquipToggle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEquipped ? Colors.grey.shade800 : Colors.purple,
                        minimumSize: const Size(double.infinity, 30),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        isEquipped ? 'Remove' : 'Use',
                        style: const TextStyle(fontSize: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
