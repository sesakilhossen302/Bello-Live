import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/svg.dart';

import '../../../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../../../data/remote/firebase/assets_services.dart';
import '../../../../data/remote/firebase/profile_services.dart';
import '../../../core/widgets/GiftImageWidget.dart';
import '../../../data/remote/firebase/live_streaming_services.dart';

class ParticipantSelector {
  final String userId;
  final String userName;
  final String? userPicture;
  bool isSelected;

  ParticipantSelector({required this.userId, required this.userName, this.userPicture, this.isSelected = false});
}

class GiftBottomSheet extends StatefulWidget {
  final String roomId;
  final List<dynamic> participants;
  final String hostId;

  const GiftBottomSheet({super.key, required this.roomId, required this.participants, required this.hostId});

  @override
  State<GiftBottomSheet> createState() => _GiftBottomSheetState();
}

class _GiftBottomSheetState extends State<GiftBottomSheet> with SingleTickerProviderStateMixin {
  GiftModel? _selectedGift;
  List<ParticipantSelector> _participantSelectors = [];
  int _currentBalance = 0;
  bool _isSending = false;

  List<String>? _cachedCategories;
  final Map<String, List<GiftModel>> _cachedGiftsByCategory = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _initializeParticipants();
    _loadBalance();
    _loadCategories();
  }

  @override
  void dispose() {
    if (mounted && _cachedCategories != null) {
      _tabController.dispose();
    }
    super.dispose();
  }

  void _initializeParticipants() {
    _participantSelectors = widget.participants.map((p) {
      return ParticipantSelector(
        userId: p.userId,
        userName: p.userName,
        userPicture: p.userPicture,
        isSelected: p.userId == widget.hostId,
      );
    }).toList();

    _participantSelectors.sort((a, b) {
      if (a.userId == widget.hostId) return -1;
      if (b.userId == widget.hostId) return 1;
      return 0;
    });
  }

  Future<void> _loadBalance() async {
    final balance = await ProfileService.getCurrentUserBalance();
    if (!mounted) return;
    setState(() {
      _currentBalance = balance;
    });
  }

  Future<void> _loadBalanceUpdate() async {
    // Small helper to refresh balance without a full reload
    final balance = await ProfileService.getCurrentUserBalance();
    if (mounted) setState(() => _currentBalance = balance);
  }

  Future<void> _loadCategories() async {
    var categories = await AssetsService.getGiftCategories();

    // Filter out Lucky category
    categories = categories.where((cat) => cat != 'Lucky').toList();

    final List<String> desiredOrder = ['Event', 'Popular', 'Luxury', 'Celebrate', 'Backpit'];

    categories.sort((a, b) {
      int indexA = desiredOrder.indexOf(a);
      int indexB = desiredOrder.indexOf(b);
      if (indexA == -1) indexA = 999;
      if (indexB == -1) indexB = 999;
      return indexA.compareTo(indexB);
    });

    if (!mounted) return;

    setState(() {
      _cachedCategories = categories;
      _tabController = TabController(length: categories.length, vsync: this);
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          setState(() {
            _selectedGift = null;
          });
        }
      });
    });
  }

  int get _totalCost {
    if (_selectedGift == null) return 0;
    final selectedCount = _participantSelectors.where((p) => p.isSelected).length;
    return _selectedGift!.value * selectedCount;
  }

  bool get _canSend {
    if (_selectedGift == null) return false;
    if (_currentBalance < _totalCost) return false;
    return _participantSelectors.any((p) => p.isSelected);
  }

  Future<void> _sendGift() async {
    if (!_canSend || _selectedGift == null) return;

    setState(() {
      _isSending = true;
    });

    try {
      final selectedParticipants = _participantSelectors.where((p) => p.isSelected).toList();
      final selectedRecipientIds = selectedParticipants.map((p) => p.userId).toList();

      final String receiverIds = selectedRecipientIds.join(',');
      final String receiverNames = selectedParticipants.map((p) => p.userName).join(', ');

      await ProfileService.sendGift(giftValue: _selectedGift!.value, recipientIds: selectedRecipientIds);

      await LiveStreamService.sendGift(
        roomId: widget.roomId,
        giftAnimationUrl: _selectedGift!.iconUrl,
        giftImageUrl: _selectedGift!.imageUrl,
        giftValue: _selectedGift!.value,
        category: _selectedGift!.category,
        receiverId: receiverIds,
        receiverName: receiverNames,
      );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.5;

    return SafeArea(
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: Color(0xFF2d1b2b),
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(width: 16),
                const Text(
                  'Send Gift',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Padding(padding: const EdgeInsets.only(right: 16), child: _buildBalanceDisplay()),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _cachedCategories == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.pink))
                  : Column(
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Colors.white10)),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            indicatorColor: Colors.pink,
                            labelColor: Colors.pink,
                            unselectedLabelColor: Colors.white70,
                            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                            tabs: _cachedCategories!.map((cat) => Tab(text: cat)).toList(),
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: _cachedCategories!.map((category) {
                              return _GiftGridView(
                                category: category,
                                selectedGiftId: _selectedGift?.id,
                                cachedGifts: _cachedGiftsByCategory[category],
                                onGiftSelected: (gift) {
                                  setState(() {
                                    _selectedGift = gift;
                                  });
                                },
                                onGiftsCached: (gifts) {
                                  _cachedGiftsByCategory[category] = gifts;
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
            ),
            _buildBottomSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Send to',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_selectedGift != null)
                Text(
                  'Total: $_totalCost',
                  style: TextStyle(
                    color: _canSend ? Colors.amber : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _participantSelectors.length,
                    itemBuilder: (context, index) {
                      final participant = _participantSelectors[index];
                      return _buildParticipantItem(participant);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 36,
                child: ElevatedButton(
                  onPressed: _canSend && !_isSending ? _sendGift : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    disabledBackgroundColor: Colors.grey.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Send',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceDisplay() {
    return StreamBuilder<int>(
      stream: ProfileService.getCurrentUserBalanceStream(),
      initialData: _currentBalance,
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != _currentBalance) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _currentBalance = snapshot.data!;
          });
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              SvgPicture.asset("assets/icons/beans.svg", colorFilter: const ColorFilter.mode(Colors.amber, BlendMode.srcIn), width: 16),
              const SizedBox(width: 4),
              Text(
                _currentBalance.toString(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParticipantItem(ParticipantSelector participant) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () {
          setState(() {
            participant.isSelected = !participant.isSelected;
          });
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: participant.isSelected ? Colors.pink : Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: participant.userPicture != null && participant.userPicture!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: participant.userPicture!,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => const Icon(Icons.person, color: Colors.white, size: 20),
                            )
                          : const Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                  ),
                  // Frame Logic (40 * 1.3 = 52)
                  Positioned(
                    width: 52,
                    height: 52,
                    child: IgnorePointer(child: ActiveFrameWidget(userId: participant.userId, size: 52)),
                  ),
                ],
              ),
            ),
            if (participant.isSelected)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: const BoxDecoration(color: Colors.pink, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GiftGridView extends StatefulWidget {
  final String category;
  final String? selectedGiftId;
  final List<GiftModel>? cachedGifts;
  final Function(GiftModel) onGiftSelected;
  final Function(List<GiftModel>) onGiftsCached;

  const _GiftGridView({
    required this.category,
    required this.selectedGiftId,
    required this.cachedGifts,
    required this.onGiftSelected,
    required this.onGiftsCached,
  });

  @override
  State<_GiftGridView> createState() => _GiftGridViewState();
}

class _GiftGridViewState extends State<_GiftGridView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (widget.cachedGifts != null) {
      return _buildGrid(widget.cachedGifts!);
    }

    return StreamBuilder<List<GiftModel>>(
      stream: AssetsService.getGiftsByCategory(widget.category),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.pink));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)),
          );
        }

        final gifts = snapshot.data ?? [];

        if (gifts.isEmpty) {
          return const Center(
            child: Text('No gifts found.', style: TextStyle(color: Colors.white70)),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onGiftsCached(gifts);
        });

        return _buildGrid(gifts);
      },
    );
  }

  Widget _buildGrid(List<GiftModel> gifts) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: gifts.length,
      itemBuilder: (context, index) {
        final gift = gifts[index];
        final isSelected = widget.selectedGiftId == gift.id;

        return GestureDetector(
          onTap: () => widget.onGiftSelected(gift),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.2),
                      border: Border.all(color: isSelected ? Colors.pink : Colors.transparent, width: 3),
                    ),
                    child: ClipOval(
                      child: GiftImageWidget(
                        imageUrl: gift.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: Center(
                          child: CircularProgressIndicator(color: Colors.pink.withValues(alpha: 0.5), strokeWidth: 1.5),
                        ),
                        errorWidget: const Icon(Icons.card_giftcard, color: Colors.white54, size: 24),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.cyan.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond_outlined, color: Colors.cyan, size: 10),
                    const SizedBox(width: 2),
                    Text(
                      gift.value.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

void showGiftBottomSheet(
  BuildContext context, {
  required String roomId,
  required List<dynamic> participants,
  required String hostId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => GiftBottomSheet(roomId: roomId, participants: participants, hostId: hostId),
  );
}
