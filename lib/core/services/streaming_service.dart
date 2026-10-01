import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:agora_token_service/agora_token_service.dart';
import 'package:permission_handler/permission_handler.dart';

class StreamingChatMessage {
  final String id;
  final String userId;
  final String userName;
  final String message;
  final DateTime timestamp;

  StreamingChatMessage({
    this.id = '',
    required this.userId,
    required this.userName,
    required this.message,
    required this.timestamp,
  });
}

enum CameraPosition { front, back }
enum ConnectionState { connected, disconnected, reconnecting }

class StreamingService {
  StreamingService._internal();
  static final StreamingService instance = StreamingService._internal();

  RtcEngine? _engine;
  String? _appId;
  String? _primaryCertificate;
  bool _isInitialized = false;

  String? _currentRoomName;
  String? _currentUserId;
  String? _currentUserName;
  bool _isVideo = false;
  bool _isHost = false;
  bool _isMicOn = false;
  bool _isCameraOn = false;
  int? _dataStreamId;
  bool _isSpeakerMuted = false;
  
  // Realtime Database comment and emoji subscriptions
  StreamSubscription? _commentsSubscription;
  StreamSubscription? _quickEmojiSubscription;
  
  // For PK Battles, we might need a separate connection in Agora
  // Agora supports multi-channel via RtcEngineEx.joinChannelEx
  RtcConnection? _pkConnection;
  String? _opponentHostId;

  // Streams
  final _activeSpeakersController = StreamController<List<String>>.broadcast();
  final _dataMessagesController = StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessagesController = StreamController<StreamingChatMessage>.broadcast();
  final _connectionStateController = StreamController<ConnectionState>.broadcast();
  final _remoteParticipantsChangedController = StreamController<void>.broadcast();

  // Mapping from integer UID to String userAccount
  final Map<int, String> _uidToAccount = {};

  bool get isSpeakerMuted => _isSpeakerMuted;
  String? get opponentHostId => _opponentHostId;
  Stream<List<String>> get activeSpeakersStream => _activeSpeakersController.stream;
  Stream<Map<String, dynamic>> get dataMessagesStream => _dataMessagesController.stream;
  Stream<StreamingChatMessage> get chatMessagesStream => _chatMessagesController.stream;
  Stream<ConnectionState> get connectionStateStream => _connectionStateController.stream;
  Stream<void> get remoteParticipantsChangedStream => _remoteParticipantsChangedController.stream;

  Future<void> _initEngine() async {
    if (_isInitialized) return;

    final doc = await FirebaseFirestore.instance.collection('appSettings').doc('agora_config').get();
    if (doc.exists && doc.data() != null) {
      _appId = doc.data()!['appId'];
      _primaryCertificate = doc.data()!['primarycertificate'];
    }

    if (_appId == null || _appId!.isEmpty) {
      debugPrint("Agora App ID not found in Firestore. Using default or failing.");
      return;
    }

    await [Permission.camera, Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: _appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    // Configure high quality audio routing and loudspeaker
    await _engine!.enableAudio();
    await _engine!.setAudioProfile(
      profile: AudioProfileType.audioProfileSpeechStandard,
      scenario: AudioScenarioType.audioScenarioGameStreaming,
    );
    try {
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);
    } catch (e) {
      debugPrint('[Agora] setDefaultAudioRouteToSpeakerphone error: $e');
    }
    try {
      await _engine!.adjustPlaybackSignalVolume(100);
      await _engine!.adjustRecordingSignalVolume(100);
    } catch (e) {
      debugPrint('[Agora] adjust volume error: $e');
    }

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('[Agora] Joined channel: ${connection.channelId}');
          try {
            _engine?.setEnableSpeakerphone(true);
          } catch (e) {
            debugPrint('[Agora] onJoinChannelSuccess setEnableSpeakerphone error: $e');
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          _engine?.getUserInfoByUid(remoteUid).then((info) {
             if (info.userAccount != null) {
               _uidToAccount[remoteUid] = info.userAccount!;
               _remoteParticipantsChangedController.add(null);
             }
          });
        },
        onUserInfoUpdated: (int uid, UserInfo info) {
          if (info.userAccount != null) {
            _uidToAccount[uid] = info.userAccount!;
            _remoteParticipantsChangedController.add(null);
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          _uidToAccount.remove(remoteUid);
          _remoteParticipantsChangedController.add(null);
        },
        onActiveSpeaker: (RtcConnection connection, int uid) {
          final account = _uidToAccount[uid];
          if (account != null) {
            _activeSpeakersController.add([account]);
          }
        },
        onStreamMessage: (RtcConnection connection, int remoteUid, int streamId, Uint8List data, int length, int sentTs) {
          try {
            final rawStr = utf8.decode(data);
            final json = jsonDecode(rawStr) as Map<String, dynamic>;
            _dataMessagesController.add(json);

            if (json.containsKey('type') && json['type'] == 'chat') {
              _chatMessagesController.add(
                StreamingChatMessage(
                  userId: json['userId'] ?? '',
                  userName: json['userName'] ?? 'User',
                  message: json['message'] ?? '',
                  timestamp: DateTime.now(),
                ),
              );
            }
          } catch (e) {
            debugPrint('[Agora] Error parsing DataChannel packet: $e');
          }
        },
      ),
    );

    _isInitialized = true;
  }

  Future<String> _generateToken(String channelName, String userAccount) async {
    if (_primaryCertificate == null || _primaryCertificate!.isEmpty) return "";
    try {
      return RtcTokenBuilder.build(
        appId: _appId!,
        appCertificate: _primaryCertificate!,
        channelName: channelName,
        uid: userAccount,
        role: RtcRole.publisher,
        expireTimestamp: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600 * 24,
      );
    } catch (e) {
      return "";
    }
  }

  Future<void> connectRoom({
    required String roomName,
    required String userId,
    required String userName,
    required String role,
    bool isVideo = false,
    bool isHost = false,
  }) async {
    _currentRoomName = roomName;
    _currentUserId = userId;
    _currentUserName = userName;
    _isVideo = isVideo;
    _isHost = isHost;
    _isMicOn = isHost;
    _isCameraOn = isHost && isVideo;

    // Reset previous stream ID and subscriptions
    _dataStreamId = null;
    await _commentsSubscription?.cancel();
    _commentsSubscription = null;
    await _quickEmojiSubscription?.cancel();
    _quickEmojiSubscription = null;

    // Set up Realtime Database listener for comments
    final commentsRef = isVideo
        ? FirebaseDatabase.instance.ref('live_events/$roomName/comments')
        : FirebaseDatabase.instance.ref('room_events/$roomName/comments');

    _commentsSubscription = commentsRef.onChildAdded.listen((event) {
      try {
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final id = data['id']?.toString() ?? event.snapshot.key ?? '';
          final msgUserId = data['userId']?.toString() ?? '';
          final msgUserName = data['userName']?.toString() ?? 'User';
          final message = data['message']?.toString() ?? '';

          DateTime timestamp;
          final rawTs = data['timestamp'];
          if (rawTs is int) {
            timestamp = DateTime.fromMillisecondsSinceEpoch(rawTs);
          } else if (rawTs is num) {
            timestamp = DateTime.fromMillisecondsSinceEpoch(rawTs.toInt());
          } else {
            timestamp = DateTime.now();
          }

          if (message.isNotEmpty) {
            _chatMessagesController.add(
              StreamingChatMessage(
                id: id,
                userId: msgUserId,
                userName: msgUserName,
                message: message,
                timestamp: timestamp,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('[StreamingService] Error receiving Firebase comment: $e');
      }
    });

    // Set up Realtime Database listener for quick floating emojis
    final quickEmojiRef = isVideo
        ? FirebaseDatabase.instance.ref('live_events/$roomName/quick_emoji')
        : FirebaseDatabase.instance.ref('room_events/$roomName/quick_emoji');

    _quickEmojiSubscription = quickEmojiRef.onValue.listen((event) {
      try {
        if (event.snapshot.value != null) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          _dataMessagesController.add(data);
        }
      } catch (e) {
        debugPrint('[StreamingService] Error receiving quick emoji: $e');
      }
    });

    await _initEngine();
    if (_engine == null) return;

    await _engine!.setClientRole(role: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience);
    
    if (isVideo) {
      await _engine!.enableVideo();
      if (isHost) await _engine!.startPreview();
    } else {
      await _engine!.enableAudio();
      await _engine!.disableVideo();
    }

    String token = await _generateToken(roomName, userId);

    await _engine!.joinChannelWithUserAccount(
      token: token,
      channelId: roomName,
      userAccount: userId,
      options: ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: isHost && isVideo,
        publishMicrophoneTrack: isHost,
        clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
      ),
    );
  }

  Future<void> disconnect() async {
    await _commentsSubscription?.cancel();
    _commentsSubscription = null;
    await _quickEmojiSubscription?.cancel();
    _quickEmojiSubscription = null;
    _dataStreamId = null;
    await disconnectOpponentPKRoom();
    await _engine?.leaveChannel();
    _currentRoomName = null;
    _uidToAccount.clear();
  }

  Future<void> connectOpponentPKRoom({
    required String opponentRoomId,
    required String opponentHostId,
  }) async {
    if (_engine == null || _currentUserId == null) return;
    _opponentHostId = opponentHostId;

    _pkConnection = RtcConnection(channelId: opponentRoomId, localUid: 0);
    String token = await _generateToken(opponentRoomId, '${_currentUserId}_pk');

    await (_engine as RtcEngineEx).joinChannelEx(
      token: token,
      connection: _pkConnection!,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: false,
        publishMicrophoneTrack: false,
        clientRoleType: ClientRoleType.clientRoleAudience,
      ),
    );
  }

  Future<void> disconnectOpponentPKRoom() async {
    if (_pkConnection != null && _engine != null) {
      await (_engine as RtcEngineEx).leaveChannelEx(connection: _pkConnection!);
      _pkConnection = null;
      _opponentHostId = null;
    }
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    _isMicOn = enabled;
    if (_engine == null) return;
    try {
      if (enabled) {
        // Promote client role to Broadcaster so Agora allows publishing audio track
        await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        await _engine!.enableAudio();
        await _engine!.enableLocalAudio(true);
        await _engine!.muteLocalAudioStream(false);
        await _engine!.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishMicrophoneTrack: true,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );
      } else {
        await _engine!.muteLocalAudioStream(true);
        await _engine!.enableLocalAudio(false);
        // Only demote to Audience if not publishing camera and not host
        if (!_isHost && !_isCameraOn) {
          await _engine!.updateChannelMediaOptions(
            const ChannelMediaOptions(
              publishMicrophoneTrack: false,
              clientRoleType: ClientRoleType.clientRoleAudience,
            ),
          );
          await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
        } else {
          await _engine!.updateChannelMediaOptions(
            const ChannelMediaOptions(
              publishMicrophoneTrack: false,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[StreamingService] Error setting microphone enabled: $e');
    }
  }

  Future<void> setCameraEnabled(bool enabled) async {
    _isCameraOn = enabled;
    if (_engine == null) return;
    try {
      if (enabled) {
        await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        await _engine!.enableVideo();
        await _engine!.enableLocalVideo(true);
        await _engine!.startPreview();
        await _engine!.muteLocalVideoStream(false);
        await _engine!.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishCameraTrack: true,
            clientRoleType: ClientRoleType.clientRoleBroadcaster,
          ),
        );
      } else {
        await _engine!.muteLocalVideoStream(true);
        await _engine!.enableLocalVideo(false);
        await _engine!.stopPreview();
        if (!_isHost && !_isMicOn) {
          await _engine!.updateChannelMediaOptions(
            const ChannelMediaOptions(
              publishCameraTrack: false,
              clientRoleType: ClientRoleType.clientRoleAudience,
            ),
          );
          await _engine!.setClientRole(role: ClientRoleType.clientRoleAudience);
        } else {
          await _engine!.updateChannelMediaOptions(
            const ChannelMediaOptions(
              publishCameraTrack: false,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[StreamingService] Error setting camera enabled: $e');
    }
  }

  Future<bool> flipCamera() async {
    await _engine?.switchCamera();
    return true; 
  }

  Future<void> setSpeakerMuted(bool muted) async {
    _isSpeakerMuted = muted;
    await _engine?.adjustPlaybackSignalVolume(muted ? 0 : 100);
    await _engine?.setEnableSpeakerphone(!muted);
  }

  Future<void> publishData(Map<String, dynamic> payload) async {
    if (_engine == null) return;
    try {
      _dataStreamId ??= await _engine!.createDataStream(const DataStreamConfig(syncWithAudio: false, ordered: true));
      final bytes = utf8.encode(jsonEncode(payload));
      await _engine!.sendStreamMessage(streamId: _dataStreamId!, data: Uint8List.fromList(bytes), length: bytes.length);
    } catch (e) {
      // Safe to ignore for audience members who cannot create data streams
      debugPrint('[Agora] publishData ignored: $e');
    }
  }

  Future<void> sendChatMessage(
    String messageText, {
    String? roomId,
    bool? isVideo,
    String? customId,
  }) async {
    final targetRoom = roomId ?? _currentRoomName;
    if (targetRoom == null || targetRoom.isEmpty) {
      debugPrint('[StreamingService] Cannot send chat message: No active room.');
      return;
    }

    final targetIsVideo = isVideo ?? _isVideo;
    final msgId = customId ??
        FirebaseDatabase.instance.ref().push().key ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // 1. Post to Firebase Realtime Database so all room participants (broadcasters & audience) receive it
    try {
      final commentsRef = targetIsVideo
          ? FirebaseDatabase.instance.ref('live_events/$targetRoom/comments')
          : FirebaseDatabase.instance.ref('room_events/$targetRoom/comments');

      await commentsRef.child(msgId).set({
        'id': msgId,
        'userId': _currentUserId ?? '',
        'userName': _currentUserName ?? 'User',
        'message': messageText,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      debugPrint('[StreamingService] Error posting comment to Firebase: $e');
    }

    // 2. Also attempt Agora DataStream if broadcaster
    try {
      await publishData({
        'type': 'chat',
        'id': msgId,
        'userId': _currentUserId ?? '',
        'userName': _currentUserName ?? 'User',
        'message': messageText,
      });
    } catch (_) {}
  }

  Future<void> sendEmoji(
    String emoji, {
    String? roomId,
    bool? isVideo,
  }) async {
    final targetRoom = roomId ?? _currentRoomName;
    final targetIsVideo = isVideo ?? _isVideo;

    if (targetRoom != null && targetRoom.isNotEmpty) {
      try {
        final quickEmojiRef = targetIsVideo
            ? FirebaseDatabase.instance.ref('live_events/$targetRoom/quick_emoji')
            : FirebaseDatabase.instance.ref('room_events/$targetRoom/quick_emoji');

        await quickEmojiRef.set({
          'type': 'emoji',
          'userId': _currentUserId ?? '',
          'userName': _currentUserName ?? 'User',
          'emoji': emoji,
          'timestamp': ServerValue.timestamp,
        });
      } catch (e) {
        debugPrint('[StreamingService] Error posting emoji to Firebase: $e');
      }
    }

    try {
      await publishData({
        'type': 'emoji',
        'userId': _currentUserId ?? '',
        'userName': _currentUserName ?? '',
        'emoji': emoji,
        'command': 'EMOJI_ANIM:$emoji',
      });
    } catch (_) {}
  }

  Widget buildVideoView(
    String participantIdentity, {
    bool isOpponent = false,
    BoxFit fit = BoxFit.cover,
  }) {
    if (participantIdentity == _currentUserId && !isOpponent) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: _engine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }
    
    // For remote users, we need to map string identity to uid
    int? targetUid;
    _uidToAccount.forEach((uid, account) {
      if (account == participantIdentity) {
        targetUid = uid;
      }
    });

    if (isOpponent && _pkConnection != null) {
       return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: targetUid ?? 0),
          connection: _pkConnection!,
        ),
      );
    }

    if (targetUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine!,
          canvas: VideoCanvas(uid: targetUid),
          connection: RtcConnection(channelId: _currentRoomName!),
        ),
      );
    }

    return Container(color: Colors.black);
  }
}
