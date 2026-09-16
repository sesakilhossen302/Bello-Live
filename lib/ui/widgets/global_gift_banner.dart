import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../data/remote/firebase/global_gift_banner_service.dart';
import '../../navigation/routes.dart';

class GlobalGiftBanner extends StatefulWidget {
  const GlobalGiftBanner({super.key});

  @override
  State<GlobalGiftBanner> createState() => _GlobalGiftBannerState();
}

class _GlobalGiftBannerState extends State<GlobalGiftBanner> {
  StreamSubscription<DatabaseEvent>? _latestBannerSub;
  StreamSubscription<DatabaseEvent>? _bannersListSub;
  final List<Map<String, dynamic>> _bannerQueue = [];
  final Set<String> _processedBannerIds = {};
  Map<String, dynamic>? _activeBanner;
  bool _isShowing = false;
  bool _isInitialLatestIgnored = false;

  @override
  void initState() {
    super.initState();
    _listenToGlobalGiftBanners();
  }

  @override
  void dispose() {
    _latestBannerSub?.cancel();
    _bannersListSub?.cancel();
    super.dispose();
  }

  void _listenToGlobalGiftBanners() {
    // 1. Prime the seen set with existing banners so old history is never played
    GlobalGiftBannerService.getGlobalBannersQuery().get().then((snapshot) {
      if (snapshot.exists) {
        for (final child in snapshot.children) {
          final k = child.key;
          if (k != null) {
            _processedBannerIds.add(k);
          }
          if (child.value is Map) {
            final m = Map<String, dynamic>.from(child.value as Map);
            final id = m['id']?.toString();
            if (id != null && id.isNotEmpty) {
              _processedBannerIds.add(id);
            }
          }
        }
      }
    }).catchError((e) {
      debugPrint('Error getting initial global banners: $e');
    });

    // 2. Listen to the latest single node for instant onValue trigger
    _latestBannerSub = GlobalGiftBannerService.getLatestBannerRef()
        .onValue
        .listen((event) {
      if (!mounted) return;
      final rawValue = event.snapshot.value;
      if (rawValue == null || rawValue is! Map) return;

      final data = Map<String, dynamic>.from(rawValue);
      final String bannerId = data['id']?.toString() ?? '';
      if (bannerId.isEmpty) return;

      // On the very first event after listener connects, ignore past event currently in DB
      if (!_isInitialLatestIgnored) {
        _isInitialLatestIgnored = true;
        _processedBannerIds.add(bannerId);
        return;
      }

      _enqueueBanner(bannerId, data);
    }, onError: (err) {
      debugPrint('Error listening to global latest gift: $err');
    });

    // 3. Also listen to onChildAdded for sequence queue safety
    _bannersListSub = GlobalGiftBannerService.getGlobalBannersQuery()
        .onChildAdded
        .listen((event) {
      if (!mounted) return;
      final key = event.snapshot.key ?? '';
      final rawValue = event.snapshot.value;
      if (rawValue == null || rawValue is! Map) return;

      final data = Map<String, dynamic>.from(rawValue);
      final String bannerId = data['id']?.toString() ?? key;
      if (bannerId.isEmpty) return;

      _enqueueBanner(bannerId, data);
    }, onError: (err) {
      debugPrint('Error listening to global gift list: $err');
    });
  }

  void _enqueueBanner(String bannerId, Map<String, dynamic> data) {
    if (_processedBannerIds.contains(bannerId)) return;
    _processedBannerIds.add(bannerId);

    debugPrint('🎉 Global gift banner triggered: ${data['senderName']} ➔ ${data['receiverName']} (${data['giftValue']})');

    if (_bannerQueue.length < 15) {
      _bannerQueue.add(data);
    }
    _processQueue();
  }

  void _processQueue() {
    if (_isShowing || _bannerQueue.isEmpty || !mounted) return;

    final nextBanner = _bannerQueue.removeAt(0);
    setState(() {
      _activeBanner = nextBanner;
      _isShowing = true;
    });

    // Display banner for 4.5 seconds then smoothly animate out
    Future.delayed(const Duration(milliseconds: 4500), () {
      if (!mounted) return;
      setState(() {
        _isShowing = false;
      });

      // Wait for exit animation (380ms) before clearing and checking next
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        setState(() {
          _activeBanner = null;
        });

        if (_bannerQueue.isNotEmpty) {
          _processQueue();
        }
      });
    });
  }

  String _formatCoins(int amount) {
    final str = amount.toString();
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  void _onBannerTap(Map<String, dynamic> banner) {
    final roomId = banner['roomId']?.toString() ?? '';
    final roomType = banner['roomType']?.toString() ?? 'liveStream';
    if (roomId.isEmpty) return;

    try {
      if (roomType == 'audioRoom') {
        context.push(
          Routes.audioRoom.path,
          extra: {"roomId": roomId, "isHost": false},
        );
      } else {
        context.push(
          Routes.liveStream.path,
          extra: {"roomId": roomId, "isHost": false},
        );
      }
    } catch (e) {
      debugPrint('Error navigating to room from banner: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final banner = _activeBanner;
    final bool visible = _isShowing && banner != null;

    final String senderName = banner?['senderName']?.toString() ?? 'User';
    final String senderPicture = banner?['senderPicture']?.toString() ?? '';
    final String receiverName = banner?['receiverName']?.toString() ?? 'Host';
    final String giftImageUrl = banner?['giftImageUrl']?.toString() ?? '';
    final dynamic val = banner?['giftValue'];
    final int giftValue = (val is num)
        ? val.toInt()
        : (int.tryParse(val?.toString() ?? '') ?? 0);

    return Positioned(
      top: topPadding + 55,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Center(
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            offset: visible ? const Offset(0, 0) : const Offset(0, -1.6),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: visible ? 1.0 : 0.0,
              child: banner != null
                  ? Material(
                      color: Colors.transparent,
                      child: GestureDetector(
                        onTap: () => _onBannerTap(banner),
                        child: SizedBox(
                          width: 350,
                          height: 80,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 1. SVGA Animated Banner Background (gamebannerBlue.svga)
                              const Positioned.fill(
                                child: IgnorePointer(
                                  child: SVGAEasyPlayer(
                                    assetsName: 'assets/svga/gamebannerBlue.svga',
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),

                              // 2. Banner Content (Sender -> Receiver + Coins)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    // Sender Avatar & Mini Gift Icon
                                    SizedBox(
                                      width: 38,
                                      height: 38,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.cyanAccent,
                                                width: 1.5,
                                              ),
                                              boxShadow: const [
                                                BoxShadow(
                                                  color: Colors.cyan,
                                                  blurRadius: 5,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                            child: CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Colors.black45,
                                              backgroundImage:
                                                  senderPicture.isNotEmpty
                                                      ? CachedNetworkImageProvider(
                                                          senderPicture,
                                                        )
                                                      : null,
                                              child: senderPicture.isEmpty
                                                  ? const Icon(
                                                      Icons.person,
                                                      color: Colors.white,
                                                      size: 20,
                                                    )
                                                  : null,
                                            ),
                                          ),
                                          if (giftImageUrl.isNotEmpty)
                                            Positioned(
                                              right: -4,
                                              bottom: -4,
                                              child: Container(
                                                width: 18,
                                                height: 18,
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.black
                                                      .withValues(alpha: 0.7),
                                                  border: Border.all(
                                                    color: Colors.amberAccent,
                                                    width: 1,
                                                  ),
                                                ),
                                                child: ClipOval(
                                                  child: CachedNetworkImage(
                                                    imageUrl: giftImageUrl,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) =>
                                                        const Icon(
                                                      Icons.card_giftcard,
                                                      color: Colors.amberAccent,
                                                      size: 11,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Sender & Receiver Names + Action subtitle
                                    Expanded(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          RichText(
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: senderName,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black,
                                                        blurRadius: 4,
                                                        offset: Offset(1, 1),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const TextSpan(
                                                  text: ' ➔ ',
                                                  style: TextStyle(
                                                    color: Colors.cyanAccent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black,
                                                        blurRadius: 3,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: receiverName,
                                                  style: const TextStyle(
                                                    color: Color(0xFFFFD54F),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.5,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black,
                                                        blurRadius: 4,
                                                        offset: Offset(1, 1),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.auto_awesome,
                                                color: Colors.amberAccent,
                                                size: 10,
                                              ),
                                              const SizedBox(width: 3),
                                              Flexible(
                                                child: Text(
                                                  'Sent a special gift!',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(alpha: 0.85),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    shadows: const [
                                                      Shadow(
                                                        color: Colors.black,
                                                        blurRadius: 3,
                                                      ),
                                                    ],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 6),

                                    // Coin / Diamond Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.45),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: Colors.cyanAccent
                                              .withValues(alpha: 0.8),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.cyan
                                                .withValues(alpha: 0.25),
                                            blurRadius: 4,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.diamond,
                                            color: Colors.cyanAccent,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            _formatCoins(giftValue),
                                            style: const TextStyle(
                                              color: Color(0xFFE0F7FA),
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black,
                                                  blurRadius: 3,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
