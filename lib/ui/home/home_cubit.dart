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

  // Exposed Streams for the UI
  Stream<List<StreamerModel>> get allRoomsStream => _allRoomsSubject.stream;
  Stream<List<StreamerModel>> get audioRoomsStream => _audioRoomsSubject.stream;
  Stream<List<StreamerModel>> get freshersStream => _freshersSubject.stream;
  Stream<List<PKBattleCard>> get pkBattlesStream => _pkBattlesSubject.stream;

  void _initStreams() {
    debugPrint('🔵 [HOME_CUBIT] Initializing optimized streams for Picture Live...');

    // 1. Setup raw broadcast streams for Audio and Video(Live) rooms
    final audioRoomsStreamRaw = FirebaseDatabase.instance.ref('rooms').orderByChild('isActive').equalTo(true).onValue.asBroadcastStream();
    final liveStreamsStreamRaw = FirebaseDatabase.instance.ref('live_streams').orderByChild('isActive').equalTo(true).onValue.asBroadcastStream();

    // 2. Popular Tab: Combine Audio + Video, sort by host diamonds
    Rx.combineLatest2(
      audioRoomsStreamRaw,
      liveStreamsStreamRaw,
          (DatabaseEvent audioEvent, DatabaseEvent liveEvent) async {
        return await _processRoomsWithDiamonds(audioEvent, liveEvent);
      },
    ).asyncExpand((future) async* {
      yield await future;
    }).listen((rooms) {
      _allRoomsSubject.add(rooms);
    });

    // 3. Freshers Tab: Combine Audio + Video, sort by host's creation date (newest first)
    Rx.combineLatest2(
      audioRoomsStreamRaw,
      liveStreamsStreamRaw,
          (DatabaseEvent audioEvent, DatabaseEvent liveEvent) async {
        return await _processRoomsWithHostCreationDate(audioEvent, liveEvent);
      },
    ).asyncExpand((future) async* {
      yield await future;
    }).listen((rooms) {
      _freshersSubject.add(rooms);
    });

    // 4. Party Tab: Audio rooms only, sort by host diamonds
    audioRoomsStreamRaw.asyncExpand((audioEvent) async* {
      yield await _processAudioRooms(audioEvent);
    }).listen((rooms) {
      _audioRoomsSubject.add(rooms);
    });

    // 5. PK Tab: Extract PK Battles directly from live_streams node
    liveStreamsStreamRaw.listen((event) {
      _extractAndEmitPKBattles(event);
    });
  }

  // --- Processing Functions ---

  Future<List<StreamerModel>> _processRoomsWithDiamonds(DatabaseEvent audioEvent, DatabaseEvent liveEvent) async {
    final List<_RoomWithDiamonds> roomsWithDiamonds = [];

    // Parse Audio
    if (audioEvent.snapshot.exists && audioEvent.snapshot.value != null) {
      final data = audioEvent.snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final roomData = entry.value as Map<dynamic, dynamic>;
        int hostDiamonds = await _fetchHostDiamonds(roomData['hostId']);
        roomsWithDiamonds.add(_RoomWithDiamonds(
          streamer: _mapToStreamerModel(entry.key.toString(), roomData, isVideo: false),
          diamonds: hostDiamonds,
        ));
      }
    }

    // Parse Live Streams
    if (liveEvent.snapshot.exists && liveEvent.snapshot.value != null) {
      final data = liveEvent.snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final roomData = entry.value as Map<dynamic, dynamic>;
        int hostDiamonds = await _fetchHostDiamonds(roomData['hostId']);
        roomsWithDiamonds.add(_RoomWithDiamonds(
          streamer: _mapToStreamerModel(entry.key.toString(), roomData, isVideo: true),
          diamonds: hostDiamonds,
        ));
      }
    }

    roomsWithDiamonds.sort((a, b) => b.diamonds.compareTo(a.diamonds));
    return roomsWithDiamonds.map((e) => e.streamer).toList();
  }

  Future<List<StreamerModel>> _processAudioRooms(DatabaseEvent audioEvent) async {
    final List<_RoomWithDiamonds> roomsWithDiamonds = [];

    if (audioEvent.snapshot.exists && audioEvent.snapshot.value != null) {
      final data = audioEvent.snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final roomData = entry.value as Map<dynamic, dynamic>;
        int hostDiamonds = await _fetchHostDiamonds(roomData['hostId']);
        roomsWithDiamonds.add(_RoomWithDiamonds(
          streamer: _mapToStreamerModel(entry.key.toString(), roomData, isVideo: false),
          diamonds: hostDiamonds,
        ));
      }
    }

    roomsWithDiamonds.sort((a, b) => b.diamonds.compareTo(a.diamonds));
    return roomsWithDiamonds.map((e) => e.streamer).toList();
  }

  Future<List<StreamerModel>> _processRoomsWithHostCreationDate(DatabaseEvent audioEvent, DatabaseEvent liveEvent) async {
    final List<_RoomWithTimestamp> roomsWithTimestamp = [];

    // Parse Audio
    if (audioEvent.snapshot.exists && audioEvent.snapshot.value != null) {
      final data = audioEvent.snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final roomData = entry.value as Map<dynamic, dynamic>;
        int hostCreatedAt = await _fetchHostCreatedAt(roomData['hostId']);
        roomsWithTimestamp.add(_RoomWithTimestamp(
          streamer: _mapToStreamerModel(entry.key.toString(), roomData, isVideo: false),
          timestamp: hostCreatedAt,
        ));
      }
    }

    // Parse Live Streams
    if (liveEvent.snapshot.exists && liveEvent.snapshot.value != null) {
      final data = liveEvent.snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final roomData = entry.value as Map<dynamic, dynamic>;
        int hostCreatedAt = await _fetchHostCreatedAt(roomData['hostId']);
        roomsWithTimestamp.add(_RoomWithTimestamp(
          streamer: _mapToStreamerModel(entry.key.toString(), roomData, isVideo: true),
          timestamp: hostCreatedAt,
        ));
      }
    }

    roomsWithTimestamp.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return roomsWithTimestamp.map((e) => e.streamer).toList();
  }

  void _extractAndEmitPKBattles(DatabaseEvent liveEvent) {
    if (!liveEvent.snapshot.exists || liveEvent.snapshot.value == null) {
      _pkBattlesSubject.add([]);
      return;
    }

    final data = liveEvent.snapshot.value as Map<dynamic, dynamic>;
    final List<PKBattleCard> pkBattles = [];

    data.forEach((roomId, roomData) {
      if (roomData is Map && roomData['pkState'] != null) {
        final pkState = roomData['pkState'] as Map<dynamic, dynamic>;
        if (pkState['isPK'] == true) {
          final opponentRoomId = pkState['opponentRoomId']?.toString() ?? '';

          final alreadyExists = pkBattles.any((b) =>
          (b.roomAId == roomId.toString() && b.roomBId == opponentRoomId) ||
              (b.roomAId == opponentRoomId && b.roomBId == roomId.toString()));

          if (!alreadyExists && opponentRoomId.isNotEmpty) {
            pkBattles.add(PKBattleCard(
              roomAId: roomId.toString(),
              roomBId: opponentRoomId,
              hostAName: roomData['hostName']?.toString() ?? 'Host A',
              hostBName: pkState['opponentHostName']?.toString() ?? 'Host B',
              hostAPicture: roomData['hostPicture']?.toString(),
              hostBPicture: pkState['opponentHostPicture']?.toString(),
              participantCountA: roomData['participantCount'] ?? 0,
              participantCountB: 0,
              pkEndTime: pkState['pkEndTime'] as int?,
            ));
          }
        }
      }
    });

    _pkBattlesSubject.add(pkBattles);
  }

  // --- Helper Methods ---

  StreamerModel _mapToStreamerModel(String id, Map<dynamic, dynamic> data, {required bool isVideo}) {
    return StreamerModel(
      id: id,
      name: data['hostName']?.toString() ?? 'Unknown',
      imageUrl: data['hostPicture']?.toString(),
      bio: data['notice']?.toString() ?? '',
      viewCount: data['participantCount'] ?? 0,
      isPremium: false,
      isVideo: isVideo,
      isLiveStream: isVideo,
      isLocked: data['isLocked'] == true,
    );
  }

  Future<int> _fetchHostDiamonds(String? hostId) async {
    if (hostId == null) return 0;
    try {
      final userDoc = await _firestore.collection('users').doc(hostId).get();
      if (userDoc.exists) return userDoc.data()?['diamonds'] ?? 0;
    } catch (_) {}
    return 0;
  }

  Future<int> _fetchHostCreatedAt(String? hostId) async {
    if (hostId == null) return DateTime.now().millisecondsSinceEpoch;
    try {
      final userDoc = await _firestore.collection('users').doc(hostId).get();
      if (userDoc.exists) {
        final createdAtData = userDoc.data()?['createdAt'];
        if (createdAtData is Timestamp) return createdAtData.millisecondsSinceEpoch;
        if (createdAtData is int) return createdAtData;
      }
    } catch (_) {}
    return DateTime.now().millisecondsSinceEpoch;
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