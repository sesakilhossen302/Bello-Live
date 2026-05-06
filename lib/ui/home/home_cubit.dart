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
    Rx.combineLatest2(
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

    // 3. Freshers Tab: Combine Audio + Video, sort by host's creation date (newest first)
    Rx.combineLatest2(
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

    // 4. Party Tab: Audio rooms only, sort by host diamonds
    audioRoomsStreamRaw
        .debounceTime(const Duration(milliseconds: 500))
        .asyncExpand((audioEvent) async* {
          yield await _processAudioRooms(audioEvent);
        })
        .listen((rooms) {
          _audioRoomsRaw = rooms;
          _emitFilteredRooms();
        });

    // 5. PK Tab: Extract PK Battles directly from live_streams node
    liveStreamsStreamRaw.debounceTime(const Duration(milliseconds: 500)).listen(
      (event) {
        _extractAndEmitPKBattles(event);
      },
    );
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
          int hostDiamonds = await _fetchHostDiamonds(roomData['hostId']);
          return _RoomWithDiamonds(
            streamer: _mapToStreamerModel(roomId, roomData, isVideo: false),
            diamonds: hostDiamonds,
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
          int hostDiamonds = await _fetchHostDiamonds(roomData['hostId']);
          return _RoomWithDiamonds(
            streamer: _mapToStreamerModel(roomId, roomData, isVideo: true),
            diamonds: hostDiamonds,
          );
        }());
      }
    }

    final results = await Future.wait(futures);
    results.sort((a, b) => b.diamonds.compareTo(a.diamonds));
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
          int hostDiamonds = await _fetchHostDiamonds(roomData['hostId']);
          return _RoomWithDiamonds(
            streamer: _mapToStreamerModel(roomId, roomData, isVideo: false),
            diamonds: hostDiamonds,
          );
        }());
      }
    }

    final results = await Future.wait(futures);
    results.sort((a, b) => b.diamonds.compareTo(a.diamonds));
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
          int hostCreatedAt = await _fetchHostCreatedAt(roomData['hostId']);
          return _RoomWithTimestamp(
            streamer: _mapToStreamerModel(roomId, roomData, isVideo: false),
            timestamp: hostCreatedAt,
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
          int hostCreatedAt = await _fetchHostCreatedAt(roomData['hostId']);
          return _RoomWithTimestamp(
            streamer: _mapToStreamerModel(roomId, roomData, isVideo: true),
            timestamp: hostCreatedAt,
          );
        }());
      }
    }

    final results = await Future.wait(futures);
    results.sort((a, b) => b.timestamp.compareTo(a.timestamp));
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
      viewCount: data['participantCount'] ?? 0,
      isPremium: false,
      isVideo: isVideo,
      isLiveStream: isVideo,
      isLocked: data['isLocked'] == true,
      country: data['hostCountry']?.toString() ?? 'Unknown',
    );
  }

  // --- Caching for host data to improve performance ---
  final Map<String, int> _diamondsCache = {};
  final Map<String, int> _createdAtCache = {};
  final Map<String, Future<int>> _diamondsFetchFutures = {};
  final Map<String, Future<int>> _createdAtFetchFutures = {};

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
    _allRoomsSubject.close();
    _audioRoomsSubject.close();
    _freshersSubject.close();
    _pkBattlesSubject.close();
    return super.close();
  }
}

class _RoomWithDiamonds {
  final StreamerModel streamer;
  final int diamonds;
  _RoomWithDiamonds({required this.streamer, required this.diamonds});
}

class _RoomWithTimestamp {
  final StreamerModel streamer;
  final int timestamp;
  _RoomWithTimestamp({required this.streamer, required this.timestamp});
}
