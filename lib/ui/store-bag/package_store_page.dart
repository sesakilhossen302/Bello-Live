import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'dart:async';
import '../../core/widgets/gift_image_widget.dart';
import '../../data/remote/firebase/store_service.dart';
import '../../theme/app_theme.dart';

class PackageStorePage extends StatefulWidget {
  final String category;

  const PackageStorePage({super.key, required this.category});

  @override
  State<PackageStorePage> createState() => _PackageStorePageState();
}

class _PackageStorePageState extends State<PackageStorePage> {
  List<StoreItemModel> _packageItems = [];
  Map<String, List<StoreItemModel>> _bagItems = {};
  String? _activeImageUrl;
  StreamSubscription? _activeAddOnsSub;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _activeAddOnsSub = StoreService.getActiveAddOnsStream().listen((addons) {
      if (mounted) {
        setState(() {
          _activeImageUrl = addons[widget.category];
        });
      }
    });
  }

  @override
  void dispose() {
    _activeAddOnsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final items = await StoreService.fetchStoreItems();
      final bag = await StoreService.fetchMyBagItems();
      
      final categoryItems = items[widget.category] ?? [];
      
      // Sort by price ascending
      categoryItems.sort((a, b) => a.price.compareTo(b.price));

      setState(() {
        _packageItems = categoryItems;
        _bagItems = bag;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading packages: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF091433),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.category.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${widget.category.toUpperCase()}:',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _packageItems.isEmpty
                        ? const Center(child: Text('No packages available', style: TextStyle(color: Colors.white70)))
                        : ListView.separated(
                            itemCount: _packageItems.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _packageItems[index];
                              final isOwned = _bagItems[widget.category]?.any((e) => e.id == item.id) ?? false;
                              final isInUse = _activeImageUrl == item.imageUrl;
                              
                              return _PackageCard(
                                item: item,
                                isOwned: isOwned,
                                isInUse: isInUse,
                                onPurchaseComplete: _loadData,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PackageCard extends StatefulWidget {
  final StoreItemModel item;
  final bool isOwned;
  final bool isInUse;
  final VoidCallback onPurchaseComplete;

  const _PackageCard({
    required this.item, 
    required this.isOwned, 
    required this.isInUse,
    required this.onPurchaseComplete,
  });

  @override
  State<_PackageCard> createState() => _PackageCardState();
}

class _PackageCardState extends State<_PackageCard> {
  bool _isPurchasing = false;

  void _handleUse() async {
    setState(() => _isPurchasing = true);
    try {
      await StoreService.toggleActiveItem(widget.item, true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Equipped successfully'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  void _handlePurchase() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF162B5B),
        title: const Text('Confirm Purchase', style: TextStyle(color: Colors.white)),
        content: Text('Buy for ${widget.item.price} diamonds (365 days validity)?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Buy', style: TextStyle(color: Colors.white)),
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
          const SnackBar(
            content: Text('Successfully purchased!'),
            backgroundColor: Colors.green,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isInUse ? const Color(0xFFE62563) : Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Row(
        children: [
          // Left: Package Image/Avatar
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: ClipOval(
              child: MyImageWidget(
                imageUrl: widget.item.imageUrl,
                fit: BoxFit.cover,
                playAudio: false,
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Right: Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.diamond_rounded, color: Colors.blue, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.item.price}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '365 days validity',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  width: widget.isInUse ? 130 : 100,
                  child: ElevatedButton(
                    onPressed: widget.isInUse 
                        ? null 
                        : (widget.isOwned 
                            ? (_isPurchasing ? null : _handleUse) 
                            : (_isPurchasing ? null : _handlePurchase)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: widget.isInUse ? Colors.grey : AppColors.primary.withValues(alpha: 0.5),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: _isPurchasing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            widget.isInUse ? 'Already Used' : (widget.isOwned ? 'Use' : 'Buy'),
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
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
