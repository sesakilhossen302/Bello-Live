// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart' hide ConnectionState;
// import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
// import 'package:http/http.dart' as http;
// import 'package:livekit_client/livekit_client.dart';
// import '../config/app_config.dart';
// import '../../data/remote/firebase/app_services.dart';

// class LiveKitChatMessage {
//   final String userId;
//   final String userName;
//   final String message;
//   final DateTime timestamp;

//   LiveKitChatMessage({
//     required this.userId,
//     required this.userName,
//     required this.message,
//     required this.timestamp,
//   });
// }

// class LiveKitService {
//   LiveKitService._internal();
//   static final LiveKitService instance = LiveKitService._internal();

//   // Primary LiveKit Room instance
//   Room? _room;
//   EventsListener<RoomEvent>? _roomListener;

//   // Secondary Room instance for 1v1 PK battle cross-room streaming
//   Room? _opponentRoom;
//   EventsListener<RoomEvent>? _opponentRoomListener;
//   String? _currentOpponentHostId;

//   // Active state
//   String? _currentRoomName;
//   String? _currentUserId;
//   String? _currentUserName;
//   bool _isConnecting = false;
//   bool _isSpeakerMuted = false;
//   CameraPosition _cameraPosition = CameraPosition.front;
//   StreamSubscription? _audioDeviceSubscription;

//   // Reactive Streams
//   final _activeSpeakersController = StreamController<List<String>>.broadcast();
//   final _dataMessagesController = StreamController<Map<String, dynamic>>.broadcast();
//   final _chatMessagesController = StreamController<LiveKitChatMessage>.broadcast();
//   final _connectionStateController = StreamController<ConnectionState>.broadcast();
//   final _remoteParticipantsChangedController = StreamController<void>.broadcast();

//   // Getters
//   Room? get room => _room;
//   Room? get opponentRoom => _opponentRoom;
//   bool get isConnected => _room?.connectionState == ConnectionState.connected;
//   bool get isConnecting => _isConnecting;
//   bool get isSpeakerMuted => _isSpeakerMuted;
//   String? get currentRoomName => _currentRoomName;
//   CameraPosition get cameraPosition => _cameraPosition;
//   bool get isFrontCamera => _cameraPosition == CameraPosition.front;

//   Stream<List<String>> get activeSpeakersStream => _activeSpeakersController.stream;
//   Stream<Map<String, dynamic>> get dataMessagesStream => _dataMessagesController.stream;
//   Stream<LiveKitChatMessage> get chatMessagesStream => _chatMessagesController.stream;
//   Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
//   Stream<void> get remoteParticipantsChangedStream => _remoteParticipantsChangedController.stream;

//   Set<String> _currentlySpeakingIdentities = <String>{};
//   bool isParticipantSpeaking(String identity) => _currentlySpeakingIdentities.contains(identity);

//   // ============================================================================
//   // TOKEN FETCHING
//   // ============================================================================

//   /// Requests a cryptographically signed JWT access token from `rtc_server`.
//   Future<String> fetchToken({
//     required String roomName,
//     required String userId,
//     required String userName,
//     required String role,
//     bool isVideo = false,
//   }) async {
//     final config = await AppServices.getLiveKitConfig();
//     final tokenServerUrl = config['tokenServerUrl'] ?? AppConfig.tokenServerUrl;

//     final url = Uri.parse('$tokenServerUrl/token');
//     final payload = {
//       'roomName': roomName,
//       'participantName': userName,
//       'participantIdentity': userId,
//       'role': role.toUpperCase(),
//       'roomType': isVideo ? 'VIDEO' : 'AUDIO',
//     };

//     debugPrint('[LiveKitService] Requesting token from: $url with role: $role');
//     final response = await http.post(
//       url,
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode(payload),
//     ).timeout(const Duration(seconds: 10));

//     if (response.statusCode == 200) {
//       final data = jsonDecode(response.body);
//       if (data['success'] == true && data['token'] != null) {
//         return data['token'] as String;
//       }
//     }

//     throw Exception('Failed to fetch LiveKit token: ${response.statusCode} - ${response.body}');
//   }

//   // ============================================================================
//   // ROOM LIFECYCLE (PRIMARY)
//   // ============================================================================

//   /// Connects to a LiveKit room with carrier-grade media options (simulcast, Opus tuning).
//   Future<Room> connectRoom({
//     required String roomName,
//     required String userId,
//     required String userName,
//     required String role,
//     bool isVideo = false,
//     bool isHost = false,
//   }) async {
//     if (_room != null && _room!.connectionState == ConnectionState.connected) {
//       if (_currentRoomName == roomName) {
//         debugPrint('[LiveKitService] Already connected to room: $roomName');
//         return _room!;
//       }
//       await disconnect();
//     }

//     _isConnecting = true;
//     _currentRoomName = roomName;
//     _currentUserId = userId;
//     _currentUserName = userName;

//     try {
//       final config = await AppServices.getLiveKitConfig();
//       final liveKitUrl = config['liveKitUrl'] ?? AppConfig.liveKitUrl;
//       final token = await fetchToken(
//         roomName: roomName,
//         userId: userId,
//         userName: userName,
//         role: role,
//         isVideo: isVideo,
//       );

//       // Build production RoomOptions
//       final roomOptions = RoomOptions(
//         adaptiveStream: true,
//         dynacast: true,
//         defaultAudioPublishOptions: const AudioPublishOptions(
//           dtx: false,          // Continuous transmission: ZERO speech onset clipping
//         ),
//         defaultAudioCaptureOptions: const AudioCaptureOptions(
//           echoCancellation: true,
//           noiseSuppression: true,
//           autoGainControl: false, // Prevents volume pumping
//           highPassFilter: false,
//           typingNoiseDetection: false,
//         ),
//         defaultCameraCaptureOptions: const CameraCaptureOptions(
//           params: VideoParameters(
//             dimensions: VideoDimensions(720, 1280),
//             encoding: VideoEncoding(maxBitrate: 2000000, maxFramerate: 30),
//           ),
//         ),
//         defaultVideoPublishOptions: VideoPublishOptions(
//           simulcast: isVideo,
//           videoCodec: 'h264',
//           videoEncoding: const VideoEncoding(maxBitrate: 2000000, maxFramerate: 30),
//           videoSimulcastLayers: isVideo
//               ? [
//                   const VideoParameters(
//                     dimensions: VideoDimensions(180, 320),
//                     encoding: VideoEncoding(maxBitrate: 120000, maxFramerate: 15),
//                   ),
//                   const VideoParameters(
//                     dimensions: VideoDimensions(360, 640),
//                     encoding: VideoEncoding(maxBitrate: 450000, maxFramerate: 24),
//                   ),
//                   const VideoParameters(
//                     dimensions: VideoDimensions(720, 1280),
//                     encoding: VideoEncoding(maxBitrate: 2000000, maxFramerate: 30),
//                   ),
//                 ]
//               : [],
//         ),
//       );

//       final room = Room(roomOptions: roomOptions);
//       _room = room;
//       _setupRoomListeners(room);

//       debugPrint('[LiveKitService] Connecting to LiveKit at: $liveKitUrl');
//       await room.connect(liveKitUrl, token);

//       // Ensure intelligent audio routing (headphone/bluetooth priority, loud speaker fallback)
//       await applyAudioRouting();
//       _startAudioDeviceListener();

//       // Media initialization
//       if (isHost) {
//         await room.localParticipant?.setMicrophoneEnabled(true);
//         if (isVideo) {
//           await room.localParticipant?.setCameraEnabled(true);
//         }
//       } else {
//         // Audience members join with microphone muted
//         await room.localParticipant?.setMicrophoneEnabled(false);
//         if (isVideo) {
//           await room.localParticipant?.setCameraEnabled(false);
//         }
//       }

//       _isConnecting = false;
//       return room;
//     } catch (e) {
//       _isConnecting = false;
//       debugPrint('[LiveKitService] Connection failed: $e');
//       await disconnect();
//       rethrow;
//     }
//   }

//   void _setupRoomListeners(Room room) {
//     _roomListener?.dispose();
//     _roomListener = room.createListener();

//     _roomListener!
//       ..on<RoomDisconnectedEvent>((event) {
//         debugPrint('[LiveKitService] Room disconnected: ${event.reason}');
//         _connectionStateController.add(ConnectionState.disconnected);
//       })
//       ..on<RoomReconnectingEvent>((_) {
//         debugPrint('[LiveKitService] Room reconnecting...');
//         _connectionStateController.add(ConnectionState.reconnecting);
//       })
//       ..on<RoomReconnectedEvent>((_) {
//         debugPrint('[LiveKitService] Room successfully reconnected!');
//         _connectionStateController.add(ConnectionState.connected);
//       })
//       ..on<ActiveSpeakersChangedEvent>((event) {
//         final speakerIdentities = event.speakers.map((s) => s.identity).toList();
//         _currentlySpeakingIdentities = speakerIdentities.toSet();
//         _activeSpeakersController.add(speakerIdentities);
//       })
//       ..on<DataReceivedEvent>((event) {
//         try {
//           final rawStr = utf8.decode(event.data);
//           final json = jsonDecode(rawStr) as Map<String, dynamic>;
//           _dataMessagesController.add(json);

//           if (json.containsKey('type') && json['type'] == 'chat') {
//             _chatMessagesController.add(
//               LiveKitChatMessage(
//                 userId: event.participant?.identity ?? json['userId'] ?? '',
//                 userName: event.participant?.name ?? json['userName'] ?? 'User',
//                 message: json['message'] ?? '',
//                 timestamp: DateTime.now(),
//               ),
//             );
//           }
//         } catch (e) {
//           debugPrint('[LiveKitService] Error parsing DataChannel packet: $e');
//         }
//       })
//       ..on<ParticipantConnectedEvent>((_) => _remoteParticipantsChangedController.add(null))
//       ..on<ParticipantDisconnectedEvent>((_) => _remoteParticipantsChangedController.add(null))
//       ..on<TrackSubscribedEvent>((event) {
//         if (event.track.kind == TrackType.AUDIO) {
//           debugPrint('[LiveKitService] Remote audio track subscribed: ${event.track.sid}. Ensuring audio routing...');
//           applyAudioRouting();
//         }
//         _remoteParticipantsChangedController.add(null);
//       })
//       ..on<TrackUnsubscribedEvent>((_) => _remoteParticipantsChangedController.add(null))
//       ..on<TrackMutedEvent>((_) => _remoteParticipantsChangedController.add(null))
//       ..on<TrackUnmutedEvent>((_) => _remoteParticipantsChangedController.add(null));
//   }

//   // ============================================================================
//   // MEDIA CONTROL METHODS
//   // ============================================================================

//   /// Toggles hardware microphone on/off.
//   Future<void> setMicrophoneEnabled(bool enabled) async {
//     try {
//       await _room?.localParticipant?.setMicrophoneEnabled(enabled);
//       for (final pub in _room?.localParticipant?.audioTrackPublications ?? []) {
//         if (enabled) {
//           await pub.unmute();
//         } else {
//           await pub.mute();
//         }
//       }
//       debugPrint('[LiveKitService] Microphone enabled: $enabled');
//     } catch (e) {
//       debugPrint('[LiveKitService] Error setting microphone: $e');
//     }
//   }

//   /// Toggles hardware camera on/off.
//   Future<void> setCameraEnabled(bool enabled) async {
//     try {
//       await _room?.localParticipant?.setCameraEnabled(enabled);
//       if (!enabled) {
//         _cameraPosition = CameraPosition.front;
//       }
//       debugPrint('[LiveKitService] Camera enabled: $enabled');
//     } catch (e) {
//       debugPrint('[LiveKitService] Error setting camera: $e');
//     }
//   }

//   /// Toggles between front and back camera for the local video stream.
//   /// Returns true if currently on front camera, false if on back camera.
//   Future<bool> flipCamera() async {
//     try {
//       final localP = _room?.localParticipant;
//       if (localP == null) {
//         debugPrint('[LiveKitService] Cannot flip camera: local participant is null');
//         return _cameraPosition == CameraPosition.front;
//       }

//       LocalVideoTrack? videoTrack;
//       for (final pub in localP.videoTrackPublications) {
//         if (pub.track is LocalVideoTrack) {
//           videoTrack = pub.track as LocalVideoTrack;
//           break;
//         }
//       }

//       if (videoTrack == null) {
//         debugPrint('[LiveKitService] No LocalVideoTrack found in publications');
//         return _cameraPosition == CameraPosition.front;
//       }

//       CameraPosition currentPos = _cameraPosition;
//       final options = videoTrack.currentOptions;
//       if (options is CameraCaptureOptions) {
//         currentPos = options.cameraPosition;
//       }

//       final targetPos = currentPos.switched();
//       debugPrint('[LiveKitService] Switching camera from $currentPos to $targetPos');

//       try {
//         await videoTrack.setCameraPosition(targetPos);
//       } catch (e) {
//         debugPrint('[LiveKitService] setCameraPosition exception: $e. Trying device fallback...');
//         final devices = await Hardware.instance.enumerateDevices();
//         final videoDevices = devices.where((d) => d.kind == 'videoinput').toList();
//         final isLookingForBack = targetPos == CameraPosition.back;
//         final targetDevice = videoDevices.firstWhere(
//           (d) {
//             final label = d.label.toLowerCase();
//             return isLookingForBack
//                 ? (label.contains('back') || label.contains('rear') || label.contains('environment'))
//                 : (label.contains('front') || label.contains('user'));
//           },
//           orElse: () => videoDevices.length > 1
//               ? (isLookingForBack ? videoDevices.last : videoDevices.first)
//               : videoDevices.first,
//         );
//         await videoTrack.switchCamera(targetDevice.deviceId);
//       }

//       _cameraPosition = targetPos;
//       _remoteParticipantsChangedController.add(null);
//       debugPrint('[LiveKitService] Successfully switched camera to $targetPos');
//       return targetPos == CameraPosition.front;
//     } catch (e) {
//       debugPrint('[LiveKitService] Failed to flip camera: $e');
//       return _cameraPosition == CameraPosition.front;
//     }
//   }

//   /// Applies intelligent audio routing:
//   /// - If wired or bluetooth headphones are connected: routes audio directly to headphones.
//   /// - If no headphones are connected: routes audio to loud speakerphone.
//   /// - If user explicitly muted speaker: disables speakerphone.
//   Future<void> applyAudioRouting() async {
//     try {
//       if (_isSpeakerMuted) {
//         debugPrint('[LiveKitService] Speaker is muted, disabling speakerphone');
//         await rtc.Helper.setSpeakerphoneOn(false);
//         return;
//       }

//       debugPrint('[LiveKitService] Routing audio: prioritizing headphones / Bluetooth headset, fallback to speakerphone');
//       await rtc.Helper.setSpeakerphoneOnButPreferBluetooth();
//     } catch (e) {
//       debugPrint('[LiveKitService] Error in applyAudioRouting: $e');
//       try {
//         await Hardware.instance.setSpeakerphoneOn(!_isSpeakerMuted);
//       } catch (_) {}
//     }
//   }

//   void _startAudioDeviceListener() {
//     _audioDeviceSubscription?.cancel();
//     _audioDeviceSubscription = Hardware.instance.onDeviceChange.stream.listen((devices) async {
//       debugPrint('[LiveKitService] Audio device change detected (${devices.length} devices). Re-evaluating audio route...');
//       await applyAudioRouting();
//     });
//   }

//   /// Toggles hardware speakerphone output muting.
//   Future<void> setSpeakerMuted(bool muted) async {
//     _isSpeakerMuted = muted;
//     await applyAudioRouting();
//     debugPrint('[LiveKitService] Speaker muted: $muted');
//   }

//   // ============================================================================
//   // DATA CHANNEL IN-ROOM MESSAGING
//   // ============================================================================

//   /// Publishes arbitrary JSON payload across the WebRTC low-latency DataChannel.
//   Future<void> publishData(Map<String, dynamic> payload) async {
//     try {
//       final raw = utf8.encode(jsonEncode(payload));
//       await _room?.localParticipant?.publishData(raw, reliable: true);
//     } catch (e) {
//       debugPrint('[LiveKitService] Error publishing DataChannel message: $e');
//     }
//   }

//   /// Sends in-room chat message.
//   Future<void> sendChatMessage(String messageText) async {
//     await publishData({
//       'type': 'chat',
//       'userId': _currentUserId ?? '',
//       'userName': _currentUserName ?? '',
//       'message': messageText,
//     });
//   }

//   /// Sends in-room emoji animation trigger.
//   Future<void> sendEmoji(String emoji) async {
//     await publishData({
//       'type': 'emoji',
//       'userId': _currentUserId ?? '',
//       'userName': _currentUserName ?? '',
//       'emoji': emoji,
//       'command': 'EMOJI_ANIM:$emoji',
//     });
//   }

//   // ============================================================================
//   // 1V1 PK BATTLE DUAL-ROOM STREAMING
//   // ============================================================================

//   /// Connects to opponent's room as subscriber-only to display opponent's stream.
//   Future<void> connectOpponentPKRoom({
//     required String opponentRoomId,
//     required String opponentHostId,
//   }) async {
//     if (_opponentRoom != null) {
//       await disconnectOpponentPKRoom();
//     }

//     _currentOpponentHostId = opponentHostId;
//     debugPrint('[LiveKitService] Connecting to opponent PK room: $opponentRoomId (Host: $opponentHostId)');

//     try {
//       final config = await AppServices.getLiveKitConfig();
//       final liveKitUrl = config['liveKitUrl'] ?? AppConfig.liveKitUrl;
//       final token = await fetchToken(
//         roomName: opponentRoomId,
//         userId: '${_currentUserId ?? 'viewer'}_pk_sub',
//         userName: _currentUserName ?? 'Viewer',
//         role: 'LISTENER',
//         isVideo: true,
//       );

//       final room = Room(
//         roomOptions: const RoomOptions(
//           adaptiveStream: true,
//           dynacast: true,
//         ),
//       );

//       _opponentRoom = room;
//       _opponentRoomListener?.dispose();
//       _opponentRoomListener = room.createListener();

//       _opponentRoomListener!
//         ..on<TrackSubscribedEvent>((_) => _remoteParticipantsChangedController.add(null))
//         ..on<TrackUnsubscribedEvent>((_) => _remoteParticipantsChangedController.add(null));

//       await room.connect(liveKitUrl, token);
//       debugPrint('[LiveKitService] Connected to opponent PK room successfully!');
//     } catch (e) {
//       debugPrint('[LiveKitService] Error connecting to opponent PK room: $e');
//     }
//   }

//   /// Disconnects from opponent's PK room.
//   Future<void> disconnectOpponentPKRoom() async {
//     _currentOpponentHostId = null;
//     if (_opponentRoom != null) {
//       debugPrint('[LiveKitService] Disconnecting from opponent PK room...');
//       _opponentRoomListener?.dispose();
//       _opponentRoomListener = null;
//       await _opponentRoom?.disconnect();
//       await _opponentRoom?.dispose();
//       _opponentRoom = null;
//     }
//   }

//   // ============================================================================
//   // VIDEO VIEW RENDERING
//   // ============================================================================

//   /// Builds video widget for user. Local preview bypasses network for 0ms delay.
//   Widget buildVideoView(
//     String participantIdentity, {
//     bool isOpponent = false,
//     BoxFit fit = BoxFit.cover,
//   }) {
//     // 1. Check if local user (0ms instant preview)
//     if (!isOpponent && _room?.localParticipant?.identity == participantIdentity) {
//       final localPubs = _room?.localParticipant?.videoTrackPublications;
//       if (localPubs != null && localPubs.isNotEmpty) {
//         final track = localPubs.first.track;
//         if (track != null && !localPubs.first.muted) {
//           return VideoTrackRenderer(
//             track,
//             key: ValueKey('local_video_${track.sid}_${_cameraPosition.name}'),
//             fit: fit == BoxFit.cover ? VideoViewFit.cover : VideoViewFit.contain,
//           );
//         }
//       }
//       return const SizedBox.shrink();
//     }

//     // 2. Check opponent room
//     final bool checkOpponent = isOpponent || (_opponentRoom != null && (_currentOpponentHostId == participantIdentity || _opponentRoom!.remoteParticipants.containsKey(participantIdentity)));
//     if (checkOpponent && _opponentRoom != null) {
//       for (var p in _opponentRoom!.remoteParticipants.values) {
//         if (p.identity == participantIdentity || participantIdentity.isEmpty || p.identity == _currentOpponentHostId) {
//           for (var pub in p.videoTrackPublications) {
//             if (pub.track != null && !pub.muted) {
//               return VideoTrackRenderer(pub.track!, fit: fit == BoxFit.cover ? VideoViewFit.cover : VideoViewFit.contain);
//             }
//           }
//         }
//       }
//       return const SizedBox.shrink();
//     }

//     // 3. Remote user in primary room
//     if (_room != null) {
//       final remoteP = _room!.remoteParticipants[participantIdentity];
//       if (remoteP != null) {
//         for (var pub in remoteP.videoTrackPublications) {
//           if (pub.track != null && !pub.muted) {
//             return VideoTrackRenderer(pub.track!, fit: fit == BoxFit.cover ? VideoViewFit.cover : VideoViewFit.contain);
//           }
//         }
//       }
//     }

//     return const SizedBox.shrink();
//   }

//   // ============================================================================
//   // TEARDOWN & CLEANUP
//   // ============================================================================

//   /// Cleans up all active rooms, tracks, listeners, and audio configurations.
//   Future<void> disconnect() async {
//     debugPrint('[LiveKitService] Disconnecting all LiveKit sessions...');
//     await disconnectOpponentPKRoom();

//     _roomListener?.dispose();
//     _roomListener = null;

//     if (_room != null) {
//       await _room?.disconnect();
//       await _room?.dispose();
//       _room = null;
//     }

//     _audioDeviceSubscription?.cancel();
//     _audioDeviceSubscription = null;
//     _currentRoomName = null;
//     _currentlySpeakingIdentities.clear();
//     _isConnecting = false;
//     _isSpeakerMuted = false;
//     _cameraPosition = CameraPosition.front;
//   }
// }
