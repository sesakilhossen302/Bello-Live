import 'dart:async';
import '../../../data/remote/firebase/profile_services.dart';
import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

import 'home_page.dart'; // For StreamerModel
import 'tabs/pk_tab.dart'; // For PKBattleCard
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final List<StreamSubscription> _subscriptions = [];

  HomeCubit() : super(const HomeState()) {
    _initStreams();
  }

  final _firestore = FirebaseFirestore.instance;

  // BehaviorSubjects to hold and instantly replay the latest data to tabs
  final _allRoomsSubject = BehaviorSubject<List<StreamerModel>>.seeded([]);
  final _audioRoomsSubject = BehaviorSubject<List<StreamerModel>>.seeded([]);
  final _freshersSubject = BehaviorSubject<List<StreamerModel>>.seeded([]);
  final _pkBattlesSubject = BehaviorSubject<List<PKBattleCard>>.seeded([]);

  // Internal storage for unfiltered rooms to allow dynamic filtering
  List<StreamerModel> _allRoomsRaw = [];
  List<StreamerModel> _audioRoomsRaw = [];
  List<StreamerModel> _freshersRaw = [];
  List<PKBattleCard> _pkBattlesRaw = [];

  // Exposed Streams for the UI
  Stream<List<StreamerModel>> get allRoomsStream => _allRoomsSubject.stream;
  Stream<List<StreamerModel>> get audioRoomsStream => _audioRoomsSubject.stream;
  Stream<List<StreamerModel>> get freshersStream => _freshersSubject.stream;
  Stream<List<PKBattleCard>> get pkBattlesStream => _pkBattlesSubject.stream;

  void _initStreams() {
    debugPrint(
      '🔵 [HOME_CUBIT] Initializing optimized streams for Picture Live...',
    );

    // 1. Setup raw broadcast streams for Audio and Video(Live) rooms
    final audioRoomsStreamRaw = FirebaseDatabase.instance
        .ref('rooms')
        .orderByChild('isActive')
        .equalTo(true)
        .onValue
        .asBroadcastStream();
    final liveStreamsStreamRaw = FirebaseDatabase.instance
        .ref('live_streams')
        .orderByChild('isActive')
        .equalTo(true)
        .onValue
        .asBroadcastStream();

    // 2. Popular Tab: Combine Audio + Video, sort by host diamonds
    final sub1 = Rx.combineLatest2(
          audioRoomsStreamRaw,
          liveStreamsStreamRaw,
          (DatabaseEvent audioEvent, DatabaseEvent liveEvent) =>
              (audioEvent, liveEvent),
        )
        .debounceTime(const Duration(milliseconds: 500))
        .asyncExpand((events) async* {
          yield await _processRoomsWithDiamonds(events.$1, events.$2);
        })
        .listen((rooms) {
          _allRoomsRaw = rooms;
          _updateCountryCounts(rooms);
          _emitFilteredRooms();
        });
    _subscriptions.add(sub1);

    // 3. Freshers Tab: Combine Audio + Video, sort by host's creation date (newest first)
    final sub2 = Rx.combineLatest2(
          audioRoomsStreamRaw,
          liveStreamsStreamRaw,
          (DatabaseEvent audioEvent, DatabaseEvent liveEvent) =>
              (audioEvent, liveEvent),
        )
        .debounceTime(const Duration(milliseconds: 500))
        .asyncExpand((events) async* {
          yield await _processRoomsWithHostCreationDate(events.$1, events.$2);
        })
        .listen((rooms) {
          _freshersRaw = rooms;
          _emitFilteredRooms();
        });
    _subscriptions.add(sub2);

    // 4. Party Tab: Audio rooms only, sort by host diamonds
    final sub3 = audioRoomsStreamRaw
        .debounceTime(const Duration(milliseconds: 500))
        .asyncExpand((audioEvent) async* {
          yield await _processAudioRooms(audioEvent);
        })
        .listen((rooms) {
          _audioRoomsRaw = rooms;
          _emitFilteredRooms();
        });
    _subscriptions.add(sub3);

    // 5. PK Tab: Extract PK Battles directly from live_streams node
    final sub4 = liveStreamsStreamRaw.debounceTime(const Duration(milliseconds: 500)).listen(
      (event) {
        _extractAndEmitPKBattles(event);
      },
    );
    _subscriptions.add(sub4);
  }

  void _updateCountryCounts(List<StreamerModel> rooms) {
    final Map<String, int> counts = {};
    for (var room in rooms) {
      counts[room.country] = (counts[room.country] ?? 0) + 1;
    }
    emit(state.copyWith(countryCounts: counts));
  }

  void _emitFilteredRooms() {
    final country = state.selectedCountry;
    if (country == 'Global') {
      _allRoomsSubject.add(_allRoomsRaw);
      _audioRoomsSubject.add(_audioRoomsRaw);
      _freshersSubject.add(_freshersRaw);
      _pkBattlesSubject.add(_pkBattlesRaw);
    } else {
      _allRoomsSubject.add(
        _allRoomsRaw.where((r) => r.country == country).toList(),
      );
      _audioRoomsSubject.add(
        _audioRoomsRaw.where((r) => r.country == country).toList(),
      );
      _freshersSubject.add(
        _freshersRaw.where((r) => r.country == country).toList(),
      );
      _pkBattlesSubject.add(
        _pkBattlesRaw.where((r) => r.hostACountry == country).toList(),
      );
    }
  }

  void setCountry(String country) {
    emit(state.copyWith(selectedCountry: country));
    _emitFilteredRooms();
  }

  // --- Processing Functions ---

  int _compareStreamerRooms({
    required bool aHasPackage,
    required bool bHasPackage,
    required int aPackagePriority,
    required int bPackagePriority,
    required int aParticipants,
    required int bParticipants,
    required int aSecondary,
    required int bSecondary,
  }) {
    final bool aIsRoyal = aHasPackage && aPackagePriority >= 4;
    final bool bIsRoyal = bHasPackage && bPackagePriority >= 4;

    // 1. Royal package hosts: ALWAYS at the very top (even with fewer participants)
    if (aIsRoyal && !bIsRoyal) return -1;
    if (!aIsRoyal && bIsRoyal) return 1;
    if (aIsRoyal && bIsRoyal) {
      // If multiple Royals, sort by participant count descending
      if (aParticipants != bParticipants) {
        return bParticipants.compareTo(aParticipants);
      }
      return bSecondary.compareTo(aSecondary);
    }

    // 2. King, Queen, Crown package hosts come next (above general hosts)
    final bool aIsOtherPackage = aHasPackage && aPackagePriority >= 1;
    final bool bIsOtherPackage = bHasPackage && bPackagePriority >= 1;

    if (aIsOtherPackage && !bIsOtherPackage) return -1;
    if (!aIsOtherPackage && bIsOtherPackage) return 1;

    if (aIsOtherPackage && bIsOtherPackage) {
      // King, Queen, Crown: rank among each other by participant count descending
      // (e.g. Queen with 50 participants ranks above King with 5 participants)
      if (aParticipants != bParticipants) {
        return bParticipants.compareTo(aParticipants);
      }
      // If participant count is tied, higher package tier wins (King > Queen > Crown)
      if (aPackagePriority != bPackagePriority) {
        return bPackagePriority.compareTo(aPackagePriority);
      }
      return bSecondary.compareTo(aSecondary);
    }

    // 3. General hosts without package: ranked by participant count descending
    if (aParticipants != bParticipants) {
      return bParticipants.compareTo(aParticipants);
    }
    return bSecondary.compareTo(aSecondary);
  }

  Future<List<StreamerModel>> _processRoomsWithDiamonds(
    DatabaseEvent audioEvent,
    DatabaseEvent liveEvent,
  ) async {
    final List<Future<_RoomWithDiamonds>> futures = [];

    // Parse Audio
    if (audioEvent.snapshot.exists && audioEvent.snapshot.value != null) {
      final data = audioEvent.snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final roomId = entry.key.toString();
        final roomData = entry.value as Map<dynamic, dynamic>;
        futures.add(() async {
          final rawCount = roomData['participantCount'];
          final int participants = (rawCount is num)
              ? rawCount.toInt()
              : (int.tryParse(rawCount?.toString() ?? '') ?? 0);

          int hostDiamonds = await _fetchHostDiamonds(roomData['hostId']);
          final packageData = await _fetchHostPackageData(roomData['hostId']);

          final int rtdbPriority = (roomData['packagePriority'] as num?)?.toInt() ?? 0;
          final int finalPriority = packageData.priority > 0 ? packageData.priority : rtdbPriority;
          final bool finalHasPackage = packageData.hasPackage || (roomData['hasPackage'] == true) || finalPriority > 0;
          final String? finalBadgeUrl = packageData.badgeUrl ?? roomData['packageBadgeUrl']?.toString();

          roomData['packageBadgeUrl'] = finalBadgeUrl;
          roomData['hasPackage'] = finalHasPackage;
          roomData['packagePriority'] = finalPriority;
          final roles = await _fetchHostRoles(roomData['hostId']);
          roomData['isHost'] = roles['isHost'];
          roomData['isAgency'] = roles['isAgency'];
          roomData['isReseller'] = roles['isReseller'];
          roomData['isModerator'] = roles['isModerator'];
          return _RoomWithDiamonds(
            streamer: _mapToStreamerModel(roomId, roomData, isVideo: false),
            diamonds: hostDiamonds,
            hasPackage: finalHasPackage,
            packagePriority: finalPriority,
            participantCount: participants,
          );
        }());
      }
    }

    // Parse Live Streams
    if (liveEvent.snapshot.exists && liveEvent.snapshot.value != null) {
      final data = liveEvent.snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final roomId = entry.key.toString();
        final roomData = entry.value as Map<dynamic, dynamic>;
        futures.add(() async {
          final rawCount = roomData['participantCount'];
          final int participants = (rawCount is num)
              ? rawCount.toInt()
              : (int.tryParse(rawCount?.toString() ?? '') ?? 0);

          int hostDiamonds = await _fetchHostDiamonds(roomData['hostId']);
          final packageData = await _fetchHostPackageData(roomData['hostId']);

          final int rtdbPriority = (roomData['packagePriority'] as num?)?.toInt() ?? 0;
          final int finalPriority = packageData.priority > 0 ? packageData.priority : rtdbPriority;
          final bool finalHasPackage = packageData.hasPackage || (roomData['hasPackage'] == true) || finalPriority > 0;
          final String? finalBadgeUrl = packageData.badgeUrl ?? roomData['packageBadgeUrl']?.toString();

          roomData['packageBadgeUrl'] = finalBadgeUrl;
          roomData['hasPackage'] = finalHasPackage;
          roomData['packagePriority'] = finalPriority;
          final roles = await _fetchHostRoles(roomData['hostId']);
          roomData['isHost'] = roles['isHost'];
          roomData['isAgency'] = roles['isAgency'];
          roomData['isReseller'] = roles['isReseller'];
          roomData['isModerator'] = roles['isModerator'];
          return _RoomWithDiamonds(
            streamer: _mapToStreamerModel(roomId, roomData, isVideo: true),
            diamonds: hostDiamonds,
            hasPackage: finalHasPackage,
            packagePriority: finalPriority,
            participantCount: participants,
          );
        }());
      }
    }

    final results = await Future.wait(futures);
    results.sort((a, b) => _compareStreamerRooms(
      aHasPackage: a.hasPackage,
      bHasPackage: b.hasPackage,
      aPackagePriority: a.packagePriority,
      bPackagePriority: b.packagePriority,
      aParticipants: a.participantCount,
      bParticipants: b.participantCount,
      aSecondary: a.diamonds,
      bSecondary: b.diamonds,
    ));
    return results.map((e) => e.streamer).toList();
  }

  Future<List<StreamerModel>> _processAudioRooms(
    DatabaseEvent audioEvent,
  ) async {
    final List<Future<_RoomWithDiamonds>> futures = [];

    if (audioEvent.snapshot.exists && audioEvent.snapshot.value != null) {
      final data = audioEvent.snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final roomId = entry.key.toString();
        final roomData = entry.value as Map<dynamic, dynamic>;
        futures.add(() async {
          final rawCount = roomData['participantCount'];
          final int participants = (rawCount is num)
              ? rawCount.toInt()
              : (int.tryParse(rawCount?.toString() ?? '') ?? 0);

          int hostDiamonds = await _fetchHostDiamonds(roomData['hostId']);
          final packageData = await _fetchHostPackageData(roomData['hostId']);

          final int rtdbPriority = (roomData['packagePriority'] as num?)?.toInt() ?? 0;
          final int finalPriority = packageData.priority > 0 ? packageData.priority : rtdbPriority;
          final bool finalHasPackage = packageData.hasPackage || (roomData['hasPackage'] == true) || finalPriority > 0;
          final String? finalBadgeUrl = packageData.badgeUrl ?? roomData['packageBadgeUrl']?.toString();

          roomData['packageBadgeUrl'] = finalBadgeUrl;
          roomData['hasPackage'] = finalHasPackage;
          roomData['packagePriority'] = finalPriority;
          final roles = await _fetchHostRoles(roomData['hostId']);
          roomData['isHost'] = roles['isHost'];
          roomData['isAgency'] = roles['isAgency'];
          roomData['isReseller'] = roles['isReseller'];
          roomData['isModerator'] = roles['isModerator'];
          return _RoomWithDiamonds(
            streamer: _mapToStreamerModel(roomId, roomData, isVideo: false),
            diamonds: hostDiamonds,
            hasPackage: finalHasPackage,
            packagePriority: finalPriority,
            participantCount: participants,
          );
        }());
      }
    }

    final results = await Future.wait(futures);
    results.sort((a, b) => _compareStreamerRooms(
      aHasPackage: a.hasPackage,
      bHasPackage: b.hasPackage,
      aPackagePriority: a.packagePriority,
      bPackagePriority: b.packagePriority,
      aParticipants: a.participantCount,
      bParticipants: b.participantCount,
      aSecondary: a.diamonds,
      bSecondary: b.diamonds,
    ));
    return results.map((e) => e.streamer).toList();
  }

  Future<List<StreamerModel>> _processRoomsWithHostCreationDate(
    DatabaseEvent audioEvent,
    DatabaseEvent liveEvent,
  ) async {
    final List<Future<_RoomWithTimestamp>> futures = [];

    // Parse Audio
    if (audioEvent.snapshot.exists && audioEvent.snapshot.value != null) {
      final data = audioEvent.snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final roomId = entry.key.toString();
        final roomData = entry.value as Map<dynamic, dynamic>;
        futures.add(() async {
          final rawCount = roomData['participantCount'];
          final int participants = (rawCount is num)
              ? rawCount.toInt()
              : (int.tryParse(rawCount?.toString() ?? '') ?? 0);

          int hostCreatedAt = await _fetchHostCreatedAt(roomData['hostId']);
          final packageData = await _fetchHostPackageData(roomData['hostId']);

          final int rtdbPriority = (roomData['packagePriority'] as num?)?.toInt() ?? 0;
          final int finalPriority = packageData.priority > 0 ? packageData.priority : rtdbPriority;
          final bool finalHasPackage = packageData.hasPackage || (roomData['hasPackage'] == true) || finalPriority > 0;
          final String? finalBadgeUrl = packageData.badgeUrl ?? roomData['packageBadgeUrl']?.toString();

          roomData['packageBadgeUrl'] = finalBadgeUrl;
          roomData['hasPackage'] = finalHasPackage;
          roomData['packagePriority'] = finalPriority;
          final roles = await _fetchHostRoles(roomData['hostId']);
          roomData['isHost'] = roles['isHost'];
          roomData['isAgency'] = roles['isAgency'];
          roomData['isReseller'] = roles['isReseller'];
          roomData['isModerator'] = roles['isModerator'];
          return _RoomWithTimestamp(
            streamer: _mapToStreamerModel(roomId, roomData, isVideo: false),
            timestamp: hostCreatedAt,
            hasPackage: finalHasPackage,
            packagePriority: finalPriority,
            participantCount: participants,
          );
        }());
      }
    }

    // Parse Live Streams
    if (liveEvent.snapshot.exists && liveEvent.snapshot.value != null) {
      final data = liveEvent.snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final roomId = entry.key.toString();
        final roomData = entry.value as Map<dynamic, dynamic>;
        futures.add(() async {
          final rawCount = roomData['participantCount'];
          final int participants = (rawCount is num)
              ? rawCount.toInt()
              : (int.tryParse(rawCount?.toString() ?? '') ?? 0);

          int hostCreatedAt = await _fetchHostCreatedAt(roomData['hostId']);
          final packageData = await _fetchHostPackageData(roomData['hostId']);

          final int rtdbPriority = (roomData['packagePriority'] as num?)?.toInt() ?? 0;
          final int finalPriority = packageData.priority > 0 ? packageData.priority : rtdbPriority;
          final bool finalHasPackage = packageData.hasPackage || (roomData['hasPackage'] == true) || finalPriority > 0;
          final String? finalBadgeUrl = packageData.badgeUrl ?? roomData['packageBadgeUrl']?.toString();

          roomData['packageBadgeUrl'] = finalBadgeUrl;
          roomData['hasPackage'] = finalHasPackage;
          roomData['packagePriority'] = finalPriority;
          final roles = await _fetchHostRoles(roomData['hostId']);
          roomData['isHost'] = roles['isHost'];
          roomData['isAgency'] = roles['isAgency'];
          roomData['isReseller'] = roles['isReseller'];
          roomData['isModerator'] = roles['isModerator'];
          return _RoomWithTimestamp(
            streamer: _mapToStreamerModel(roomId, roomData, isVideo: true),
            timestamp: hostCreatedAt,
            hasPackage: finalHasPackage,
            packagePriority: finalPriority,
            participantCount: participants,
          );
        }());
      }
    }

    final results = await Future.wait(futures);
    results.sort((a, b) => _compareStreamerRooms(
      aHasPackage: a.hasPackage,
      bHasPackage: b.hasPackage,
      aPackagePriority: a.packagePriority,
      bPackagePriority: b.packagePriority,
      aParticipants: a.participantCount,
      bParticipants: b.participantCount,
      aSecondary: a.timestamp,
      bSecondary: b.timestamp,
    ));
    return results.map((e) => e.streamer).toList();
  }

  void _extractAndEmitPKBattles(DatabaseEvent liveEvent) {
    if (!liveEvent.snapshot.exists || liveEvent.snapshot.value == null) {
      _pkBattlesRaw = [];
      _emitFilteredRooms();
      return;
    }

    final data = liveEvent.snapshot.value as Map<dynamic, dynamic>;
    final List<PKBattleCard> pkBattles = [];

    data.forEach((roomId, roomData) {
      if (roomData is Map && roomData['pkState'] != null) {
        final pkState = roomData['pkState'] as Map<dynamic, dynamic>;
        if (pkState['isPK'] == true) {
          final opponentRoomId = pkState['opponentRoomId']?.toString() ?? '';

          final alreadyExists = pkBattles.any(
            (b) =>
                (b.roomAId == roomId.toString() &&
                    b.roomBId == opponentRoomId) ||
                (b.roomAId == opponentRoomId && b.roomBId == roomId.toString()),
          );

          if (!alreadyExists && opponentRoomId.isNotEmpty) {
            pkBattles.add(
              PKBattleCard(
                roomAId: roomId.toString(),
                roomBId: opponentRoomId,
                hostAName: roomData['hostName']?.toString() ?? 'Host A',
                hostBName: pkState['opponentHostName']?.toString() ?? 'Host B',
                hostAPicture: roomData['hostPicture']?.toString(),
                hostBPicture: pkState['opponentHostPicture']?.toString(),
                participantCountA: roomData['participantCount'] ?? 0,
                participantCountB: 0,
                pkEndTime: pkState['pkEndTime'] as int?,
                hostACountry: roomData['hostCountry']?.toString() ?? 'Unknown',
              ),
            );
          }
        }
      }
    });

    _pkBattlesRaw = pkBattles;
    _emitFilteredRooms();
  }

  // --- Helper Methods ---

  StreamerModel _mapToStreamerModel(
    String id,
    Map<dynamic, dynamic> data, {
    required bool isVideo,
  }) {
    return StreamerModel(
      id: id,
      hostId: data['hostId']?.toString(),
      name: data['hostName']?.toString() ?? 'Unknown',
      imageUrl: data['hostPicture']?.toString(),
      bio: data['notice']?.toString() ?? '',
      viewCount: (data['participantCount'] is num)
          ? (data['participantCount'] as num).toInt()
          : (int.tryParse(data['participantCount']?.toString() ?? '') ?? 0),
      isPremium: false,
      isVideo: isVideo,
      isLiveStream: isVideo,
      isLocked: data['isLocked'] == true,
      country: data['hostCountry']?.toString() ?? 'Unknown',
      packageBadgeUrl: data['packageBadgeUrl']?.toString(), // Pass the fetched url
      isHost: data['isHost'] == true,
      isAgency: data['isAgency'] == true,
      isReseller: data['isReseller'] == true,
      isModerator: data['isModerator'] == true,
      hasPackage: data['hasPackage'] == true,
      packagePriority: (data['packagePriority'] as int?) ?? 0,
    );
  }

  // --- Caching for host data to improve performance ---
  final Map<String, int> _diamondsCache = {};
  final Map<String, int> _createdAtCache = {};
  final Map<String, String?> _packageBadgeCache = {};
  final Map<String, _HostPackageData> _hostPackageDataCache = {};
  final Map<String, Map<String, bool>> _hostRolesCache = {};
  final Map<String, Future<int>> _diamondsFetchFutures = {};
  final Map<String, Future<int>> _createdAtFetchFutures = {};
  final Map<String, Future<_HostPackageData>> _hostPackageDataFetchFutures = {};
  final Map<String, Future<Map<String, bool>>> _hostRolesFetchFutures = {};

  Future<Map<String, bool>> _fetchHostRoles(String? hostId) async {
    if (hostId == null) return {'isHost': false, 'isAgency': false, 'isReseller': false, 'isModerator': false};
    if (_hostRolesCache.containsKey(hostId)) return _hostRolesCache[hostId]!;

    if (_hostRolesFetchFutures.containsKey(hostId)) {
      return await _hostRolesFetchFutures[hostId]!;
    }

    final Future<Map<String, bool>> future = () async {
      try {
        final userDoc = await _firestore.collection('users').doc(hostId).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            final roles = {
              'isHost': data['isHost'] == true || data['role'] == 'host',
              'isAgency': data['isAgency'] == true || data['role'] == 'agency',
              'isReseller': data['isReseller'] == true || data['role'] == 'reseller',
              'isModerator': ProfileService.checkIsModerator(data),
            };
            _hostRolesCache[hostId] = roles;
            return roles;
          }
        }
      } catch (_) {}
      final defaultRoles = {'isHost': false, 'isAgency': false, 'isReseller': false, 'isModerator': false};
      _hostRolesCache[hostId] = defaultRoles;
      return defaultRoles;
    }();

    _hostRolesFetchFutures[hostId] = future;
    final result = await future;
    _hostRolesFetchFutures.remove(hostId);
    return result;
  }

  Future<_HostPackageData> _fetchHostPackageData(String? hostId) async {
    if (hostId == null) return _HostPackageData.empty;
    if (_hostPackageDataCache.containsKey(hostId)) return _hostPackageDataCache[hostId]!;

    if (_hostPackageDataFetchFutures.containsKey(hostId)) {
      return await _hostPackageDataFetchFutures[hostId]!;
    }

    final Future<_HostPackageData> future = () async {
      try {
        final userDoc = await _firestore.collection('users').doc(hostId).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            final now = DateTime.now();
            int highestPriority = 0;
            String? badgeUrl;

            if (data.containsKey('activeAddOns')) {
              final addOns = data['activeAddOns'] as Map<String, dynamic>;
              for (var entry in addOns.entries) {
                final key = entry.key.toLowerCase().trim();
                final itemData = entry.value as Map<String, dynamic>?;
                if (itemData != null) {
                  final expiry = itemData['expiresAt'] as Timestamp?;
                  if (expiry == null || expiry.toDate().isAfter(now)) {
                    final itemName = (itemData['name'] ?? itemData['title'] ?? '').toString().toLowerCase();
                    final itemUrl = (itemData['imageUrl'] ?? itemData['imageURL'] ?? '').toString().toLowerCase();
                    final fullStr = '$key $itemName $itemUrl';

                    if (fullStr.contains('package') ||
                        fullStr.contains('royal') ||
                        fullStr.contains('king') ||
                        fullStr.contains('queen') ||
                        fullStr.contains('crown')) {
                      int p = 1;
                      if (fullStr.contains('royal')) {
                        p = 4;
                      } else if (fullStr.contains('king')) {
                        p = 3;
                      } else if (fullStr.contains('queen')) {
                        p = 2;
                      } else if (fullStr.contains('crown')) {
                        p = 1;
                      }

                      final String? url = (itemData['imageUrl'] ?? itemData['imageURL'])?.toString();
                      if (p > highestPriority) {
                        highestPriority = p;
                        badgeUrl = (url != null && url.isNotEmpty) ? url : badgeUrl;
                      } else {
                        badgeUrl ??= url;
                      }
                    }
                  }
                }
              }
            }

            final directPkg = (data['package'] ?? data['activePackage'] ?? data['vip'] ?? '').toString().toLowerCase();
            if (directPkg.isNotEmpty) {
              int p = 0;
              if (directPkg.contains('royal')) {
                p = 4;
              } else if (directPkg.contains('king')) {
                p = 3;
              } else if (directPkg.contains('queen')) {
                p = 2;
              } else if (directPkg.contains('crown')) {
                p = 1;
              }
              if (p > highestPriority) {
                highestPriority = p;
              }
            }

            if (highestPriority > 0) {
              final pkg = _HostPackageData(
                hasPackage: true,
                priority: highestPriority,
                badgeUrl: badgeUrl,
              );
              _hostPackageDataCache[hostId] = pkg;
              _packageBadgeCache[hostId] = badgeUrl;
              return pkg;
            }
          }
        }
      } catch (_) {}
      _hostPackageDataCache[hostId] = _HostPackageData.empty;
      _packageBadgeCache[hostId] = null;
      return _HostPackageData.empty;
    }();

    _hostPackageDataFetchFutures[hostId] = future;
    final result = await future;
    _hostPackageDataFetchFutures.remove(hostId);
    return result;
  }


  Future<int> _fetchHostDiamonds(String? hostId) async {
    if (hostId == null) return 0;
    if (_diamondsCache.containsKey(hostId)) return _diamondsCache[hostId]!;

    if (_diamondsFetchFutures.containsKey(hostId)) {
      return await _diamondsFetchFutures[hostId]!;
    }

    final Future<int> future = () async {
      try {
        final userDoc = await _firestore.collection('users').doc(hostId).get();
        if (userDoc.exists) {
          final diamonds = userDoc.data()?['diamonds'] ?? 0;
          _diamondsCache[hostId] = diamonds;
          return diamonds as int;
        }
      } catch (_) {}
      return 0;
    }();

    _diamondsFetchFutures[hostId] = future;
    final result = await future;
    _diamondsFetchFutures.remove(hostId);
    return result;
  }

  Future<int> _fetchHostCreatedAt(String? hostId) async {
    if (hostId == null) return DateTime.now().millisecondsSinceEpoch;
    if (_createdAtCache.containsKey(hostId)) return _createdAtCache[hostId]!;

    if (_createdAtFetchFutures.containsKey(hostId)) {
      return await _createdAtFetchFutures[hostId]!;
    }

    final Future<int> future = () async {
      try {
        final userDoc = await _firestore.collection('users').doc(hostId).get();
        if (userDoc.exists) {
          final createdAtData = userDoc.data()?['createdAt'];
          int timestamp = DateTime.now().millisecondsSinceEpoch;
          if (createdAtData is Timestamp) {
            timestamp = createdAtData.millisecondsSinceEpoch;
          } else if (createdAtData is int) {
            timestamp = createdAtData;
          }
          _createdAtCache[hostId] = timestamp;
          return timestamp;
        }
      } catch (_) {}
      return DateTime.now().millisecondsSinceEpoch;
    }();

    _createdAtFetchFutures[hostId] = future;
    final result = await future;
    _createdAtFetchFutures.remove(hostId);
    return result;
  }

  void init() async {
    final user = FirebaseAuth.instance.currentUser;
    emit(state.copyWith(user: user, isLoading: false));
  }

  @override
  Future<void> close() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _allRoomsSubject.close();
    _audioRoomsSubject.close();
    _freshersSubject.close();
    _pkBattlesSubject.close();
    return super.close();
  }
}

class _HostPackageData {
  final bool hasPackage;
  final int priority;
  final String? badgeUrl;

  const _HostPackageData({
    required this.hasPackage,
    required this.priority,
    this.badgeUrl,
  });

  static const empty = _HostPackageData(hasPackage: false, priority: 0, badgeUrl: null);
}

class _RoomWithDiamonds {
  final StreamerModel streamer;
  final int diamonds;
  final bool hasPackage;
  final int packagePriority;
  final int participantCount;

  _RoomWithDiamonds({
    required this.streamer,
    required this.diamonds,
    this.hasPackage = false,
    this.packagePriority = 0,
    required this.participantCount,
  });
}

class _RoomWithTimestamp {
  final StreamerModel streamer;
  final int timestamp;
  final bool hasPackage;
  final int packagePriority;
  final int participantCount;

  _RoomWithTimestamp({
    required this.streamer,
    required this.timestamp,
    this.hasPackage = false,
    this.packagePriority = 0,
    required this.participantCount,
  });
}
