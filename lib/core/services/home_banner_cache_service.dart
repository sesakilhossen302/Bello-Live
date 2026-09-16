import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AgencyModel {
  final String name;
  final String code;
  final String topRank;
  final int hosts;
  final int diamonds;
  final String imageUrl;
  final Color cardColor;

  const AgencyModel({
    required this.name,
    required this.code,
    required this.topRank,
    required this.hosts,
    required this.diamonds,
    required this.imageUrl,
    required this.cardColor,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'code': code,
        'topRank': topRank,
        'hosts': hosts,
        'diamonds': diamonds,
        'imageUrl': imageUrl,
        'cardColor': cardColor.toARGB32(),
      };

  factory AgencyModel.fromJson(Map<String, dynamic> json) => AgencyModel(
        name: json['name']?.toString() ?? '',
        code: json['code']?.toString() ?? '',
        topRank: json['topRank']?.toString() ?? '',
        hosts: (json['hosts'] as num?)?.toInt() ?? 0,
        diamonds: (json['diamonds'] as num?)?.toInt() ?? 0,
        imageUrl: json['imageUrl']?.toString() ?? '',
        cardColor: Color((json['cardColor'] as num?)?.toInt() ?? 0xFFB81D24),
      );
}

class HomeBannerCacheService {
  HomeBannerCacheService._();
  static final HomeBannerCacheService instance = HomeBannerCacheService._();

  static List<String> bannerUrls = [];
  static List<AgencyModel> agencies = [];

  static final ValueNotifier<List<String>> bannerNotifier = ValueNotifier<List<String>>([]);
  static final ValueNotifier<List<AgencyModel>> agencyNotifier = ValueNotifier<List<AgencyModel>>([]);

  static bool _isInitialized = false;
  static StreamSubscription? _bannerSubscription;
  static StreamSubscription? _agencySubscription;

  /// Initializes local cache from disk and starts silent background sync
  static Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // 1. Instantly load from local disk cache into memory
    await _loadFromDisk();

    // 2. Start silent background Firestore synchronization
    _startBackgroundSync();
  }

  static Future<File> _getCacheFile(String fileName) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$fileName');
  }

  static Future<void> _loadFromDisk() async {
    try {
      final bannerFile = await _getCacheFile('cached_home_banners.json');
      if (await bannerFile.exists()) {
        final content = await bannerFile.readAsString();
        final List<dynamic> list = jsonDecode(content);
        final urls = list.map((e) => e.toString()).where((u) => u.startsWith('http')).toList();
        if (urls.isNotEmpty) {
          bannerUrls = List.from(urls);
          bannerNotifier.value = List.from(urls);
        }
      }
    } catch (e) {
      debugPrint('Error loading banner cache from disk: $e');
    }

    try {
      final agencyFile = await _getCacheFile('cached_home_agencies.json');
      if (await agencyFile.exists()) {
        final content = await agencyFile.readAsString();
        final List<dynamic> list = jsonDecode(content);
        final loaded = list
            .map((e) => AgencyModel.fromJson(e as Map<String, dynamic>))
            .toList();
        if (loaded.isNotEmpty) {
          agencies = List.from(loaded);
          agencyNotifier.value = List.from(loaded);
        }
      }
    } catch (e) {
      debugPrint('Error loading agency cache from disk: $e');
    }
  }

  static Future<void> _saveBannersToDisk(List<String> urls) async {
    try {
      final file = await _getCacheFile('cached_home_banners.json');
      await file.writeAsString(jsonEncode(urls));
    } catch (e) {
      debugPrint('Error saving banners to disk: $e');
    }
  }

  static Future<void> _saveAgenciesToDisk(List<AgencyModel> list) async {
    try {
      final file = await _getCacheFile('cached_home_agencies.json');
      final data = list.map((a) => a.toJson()).toList();
      await file.writeAsString(jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving agencies to disk: $e');
    }
  }

  static void _startBackgroundSync() {
    // 1. Silent Banners Listener
    _bannerSubscription?.cancel();
    _bannerSubscription = FirebaseFirestore.instance
        .collection('banners')
        .doc('current')
        .snapshots()
        .listen((doc) {
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;
      List<String> urls = [];
      final dynamic listData = data['banners'] ?? data['banner'];
      if (listData is List) {
        urls = listData
            .map((e) => e.toString())
            .where((e) => e.startsWith('http'))
            .toList();
      } else if (listData is String && listData.startsWith('http')) {
        urls = [listData];
      }

      if (urls.isNotEmpty && !listEquals(bannerUrls, urls)) {
        bannerUrls = List.from(urls);
        bannerNotifier.value = List.from(urls);
        _saveBannersToDisk(urls);
      }
    }, onError: (e) {
      debugPrint('Error syncing banners in background: $e');
    });

    // 2. Silent Agencies Listener
    _agencySubscription?.cancel();
    _agencySubscription = FirebaseFirestore.instance
        .collection('agencies')
        .snapshots()
        .listen((snapshot) {
      _processAgencySnapshot(snapshot);
    }, onError: (e) {
      debugPrint('Error syncing agencies in background: $e');
    });

    // Immediate one-time fetch to guarantee immediate update on startup/reload
    FirebaseFirestore.instance.collection('agencies').get().then((snap) {
      _processAgencySnapshot(snap);
    }).catchError((e) {
      debugPrint('Error direct syncing agencies: $e');
    });
  }

  static String? _extractImageUrl(Map<String, dynamic>? map) {
    if (map == null) return null;
    for (final key in [
      'logo',
      'photoUrl',
      'profileImage',
      'avatar',
      'image',
      'ownerPhoto',
      'photo',
      'userPicture',
      'avatarUrl',
      'profilePicture',
      'nidFrontUrl',
      'nidFront',
    ]) {
      final val = map[key]?.toString().trim();
      if (val != null &&
          val.isNotEmpty &&
          (val.startsWith('http://') || val.startsWith('https://')) &&
          !val.contains('ui-avatars.com')) {
        return val;
      }
    }
    return null;
  }

  static Future<void> _processAgencySnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    try {
      final colors = [
        const Color(0xFFB81D24),
        const Color(0xFF3B52D4),
        const Color(0xFF6B11B4),
        const Color(0xFF0F9D58),
        const Color(0xFFE37400),
      ];

      final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snapshot.docs);
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> activeDocs = [];

      for (final doc in docs) {
        final data = doc.data();
        final status = data['status']?.toString().toLowerCase().trim();
        if (status != null && status != 'active' && status != 'approved' && status.isNotEmpty) {
          continue;
        }
        activeDocs.add(doc);
      }

      // Collect ownerIds & applicationIds for agencies where direct image is missing
      final Set<String> missingOwnerIds = {};
      final List<String> missingAppIds = [];

      for (final doc in activeDocs) {
        final data = doc.data();
        if (_extractImageUrl(data) == null) {
          final oId = data['ownerId']?.toString().trim() ?? data['userId']?.toString().trim();
          if (oId != null && oId.isNotEmpty) {
            missingOwnerIds.add(oId);
          }
          final appId = data['applicationId']?.toString().trim();
          if (appId != null && appId.isNotEmpty) {
            missingAppIds.add(appId);
          }
        }
      }

      final Map<String, String> ownerPhotoMap = {};

      // Batch fetch missing owner profiles from 'users' collection
      if (missingOwnerIds.isNotEmpty) {
        const chunkSize = 10;
        final ownerList = missingOwnerIds.toList();
        for (var i = 0; i < ownerList.length; i += chunkSize) {
          final chunk = ownerList.sublist(
            i,
            (i + chunkSize) > ownerList.length ? ownerList.length : (i + chunkSize),
          );
          try {
            final snap = await FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            for (final uDoc in snap.docs) {
              final photo = _extractImageUrl(uDoc.data());
              if (photo != null && photo.isNotEmpty) {
                ownerPhotoMap[uDoc.id] = photo;
              }
            }
          } catch (e) {
            debugPrint('Error fetching agency owner users: $e');
          }
        }
      }

      // If still missing, check agency_applications
      for (final appId in missingAppIds) {
        try {
          final appDoc = await FirebaseFirestore.instance
              .collection('agency_applications')
              .doc(appId)
              .get();
          if (appDoc.exists) {
            final photo = _extractImageUrl(appDoc.data());
            if (photo != null && photo.isNotEmpty) {
              ownerPhotoMap[appId] = photo;
            }
          }
        } catch (e) {
          debugPrint('Error fetching agency application: $e');
        }
      }

      final List<AgencyModel> loadedAgencies = [];

      for (var i = 0; i < activeDocs.length; i++) {
        final doc = activeDocs[i];
        final data = doc.data();

        final hostsList = (data['hosts'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .where((uid) => uid.isNotEmpty)
            .toList();

        int totalDiamonds = 0;
        if (hostsList.isNotEmpty) {
          try {
            const chunkSize = 10;
            for (var start = 0; start < hostsList.length; start += chunkSize) {
              final chunk = hostsList.sublist(
                start,
                (start + chunkSize) > hostsList.length ? hostsList.length : (start + chunkSize),
              );
              final usersSnap = await FirebaseFirestore.instance
                  .collection('users')
                  .where(FieldPath.documentId, whereIn: chunk)
                  .get();
              for (final userDoc in usersSnap.docs) {
                final ud = userDoc.data();
                final d = (ud['totalReceived'] ?? ud['diamonds'] ?? ud['totalEarnings'] ?? 0) as num;
                totalDiamonds += d.toInt();
              }
            }
          } catch (e) {
            debugPrint('Error summing host diamonds: $e');
          }
        }

        final agencyName = data['name']?.toString().trim().isNotEmpty == true
            ? data['name'].toString().trim()
            : (data['holderName']?.toString().trim().isNotEmpty == true
                ? data['holderName'].toString().trim()
                : 'Agency ${doc.id}');
        final agencyCode = data['agencyId']?.toString() ?? doc.id;
        final ownerId = data['ownerId']?.toString().trim() ?? data['userId']?.toString().trim();
        final appId = data['applicationId']?.toString().trim();

        // 1. Direct image on agency document
        String? resolvedImage = _extractImageUrl(data);

        // 2. Owner user profile image
        if (resolvedImage == null && ownerId != null) {
          resolvedImage = ownerPhotoMap[ownerId];
        }

        // 3. Application image
        if (resolvedImage == null && appId != null) {
          resolvedImage = ownerPhotoMap[appId];
        }

        // Auto-sync back to agency document if resolved from owner
        if (resolvedImage != null && resolvedImage.isNotEmpty) {
          final existingLogo = data['logo']?.toString().trim();
          if (existingLogo == null || existingLogo.isEmpty || existingLogo.contains('ui-avatars.com')) {
            doc.reference.update({'logo': resolvedImage}).catchError((_) {});
          }
        }

        final finalImageUrl = (resolvedImage != null && resolvedImage.isNotEmpty)
            ? resolvedImage
            : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(agencyName)}&background=random';

        loadedAgencies.add(
          AgencyModel(
            name: agencyName,
            code: agencyCode,
            topRank: 'Top: ${loadedAgencies.length + 1}',
            hosts: hostsList.length,
            diamonds: totalDiamonds,
            imageUrl: finalImageUrl,
            cardColor: colors[loadedAgencies.length % colors.length],
          ),
        );
      }

      // Sort by total diamonds descending
      loadedAgencies.sort((a, b) => b.diamonds.compareTo(a.diamonds));
      // Re-assign topRank after sorting
      for (var i = 0; i < loadedAgencies.length; i++) {
        loadedAgencies[i] = AgencyModel(
          name: loadedAgencies[i].name,
          code: loadedAgencies[i].code,
          topRank: 'Top: ${i + 1}',
          hosts: loadedAgencies[i].hosts,
          diamonds: loadedAgencies[i].diamonds,
          imageUrl: loadedAgencies[i].imageUrl,
          cardColor: loadedAgencies[i].cardColor,
        );
      }

      if (loadedAgencies.isNotEmpty) {
        agencies = List.from(loadedAgencies);
        agencyNotifier.value = List.from(loadedAgencies);
        _saveAgenciesToDisk(loadedAgencies);
      }
    } catch (e) {
      debugPrint('Error processing agency snapshot: $e');
    }
  }
}
