import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/gift_image_widget.dart';
import '../../data/remote/firebase/store_service.dart';
import '../../navigation/routes.dart';

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
                            "Your bag is empty. Visit the store!",
                            style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w500),
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
              'My Bag',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          GestureDetector(
            onTap: () async {
              await context.push(Routes.store.path);
              _loadData();
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
                'Store',
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
    final items = _bagItems[category] ?? [];

    final int crossAxisCount = category == 'Entry' ? 1 : 2;
    final double childAspectRatio = category == 'Entry' ? 2 : 0.75;

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
          final isEquipped = _activeAddOns[item.category] == item.imageUrl;

          return BagItemCard(
            item: item,
            isEquipped: isEquipped,
            onEquipToggle: () async {
              try {
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

  const BagItemCard({
    super.key,
    required this.item,
    required this.isEquipped,
    required this.onEquipToggle,
  });

  @override
  Widget build(BuildContext context) {
    final expStr = item.expiresAt != null
        ? '${item.expiresAt!.day}/${item.expiresAt!.month}/${item.expiresAt!.year}'
        : 'Never';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF0F1E42),
        border: Border.all(
          color: isEquipped ? const Color(0xFF5A189A) : Colors.white.withValues(alpha: 0.08),
          width: isEquipped ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
          if (isEquipped)
            BoxShadow(
              color: const Color(0xFF5A189A).withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 0),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: MyImageWidget(
                  imageUrl: item.imageUrl,
                  fit: BoxFit.contain,
                  playAudio: false,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Exp: $expStr',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  maxLines: 1,
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: onEquipToggle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isEquipped ? const Color(0xFF8E8E93) : const Color(0xFF5A189A),
                    minimumSize: const Size(double.infinity, 32),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text(
                    isEquipped ? 'Remove' : 'Use',
                    style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
