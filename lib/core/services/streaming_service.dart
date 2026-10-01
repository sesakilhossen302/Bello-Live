import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:agora_token_service/agora_token_service.dart';
import 'package:permission_handler/permission_handler.dart';

class StreamingChatMessage {
  final String userId;
  final String userName;
  final String message;
  final DateTime timestamp;

  StreamingChatMessage({
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
  int? _dataStreamId;
  bool _isSpeakerMuted = false;
  
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
  Stream<List<String>> get activeSpeakersStream => _activeSpeakersController.stream;
  Stream<Map<String, dynamic>> get dataMessagesStream => _dataMessagesController.stream;
  Stream<StreamingChatMessage> get chatMessagesStream => _chatMessagesController.stream;
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

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('[Agora] Joined channel: ${connection.channelId}');
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
    await _initEngine();
    if (_engine == null) return;

    _currentRoomName = roomName;
    _currentUserId = userId;
    _currentUserName = userName;

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
    await _engine?.enableLocalAudio(enabled);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    await _engine?.enableLocalVideo(enabled);
  }

  Future<bool> flipCamera() async {
    await _engine?.switchCamera();
    return true; 
  }

  Future<void> setSpeakerMuted(bool muted) async {
    _isSpeakerMuted = muted;
    // In Agora, to mute the speaker/playback, we can adjust playback signal volume
    await _engine?.adjustPlaybackSignalVolume(muted ? 0 : 100);
  }

  Future<void> publishData(Map<String, dynamic> payload) async {
    if (_engine == null) return;
    if (_dataStreamId == null) {
      _dataStreamId = await _engine!.createDataStream(const DataStreamConfig(syncWithAudio: false, ordered: true));
    }
    final bytes = utf8.encode(jsonEncode(payload));
    await _engine!.sendStreamMessage(streamId: _dataStreamId!, data: Uint8List.fromList(bytes), length: bytes.length);
  }

  Future<void> sendChatMessage(String messageText) async {
    await publishData({
      'type': 'chat',
      'userId': _currentUserId ?? '',
      'userName': _currentUserName ?? '',
      'message': messageText,
    });
  }

  Future<void> sendEmoji(String emoji) async {
    await publishData({
      'type': 'emoji',
      'userId': _currentUserId ?? '',
      'userName': _currentUserName ?? '',
      'emoji': emoji,
      'command': 'EMOJI_ANIM:$emoji',
    });
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
