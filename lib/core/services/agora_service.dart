import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_token_service/agora_token_service.dart';

class AgoraService {
  AgoraService._internal();
  static final AgoraService instance = AgoraService._internal();

  RtcEngine? _engine;
  String? _appId;
  String? _primaryCertificate;
  
  bool _isInitialized = false;

  final _activeSpeakersController = StreamController<List<int>>.broadcast();
  Stream<List<int>> get activeSpeakersStream => _activeSpeakersController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Fetch config from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('appSettings')
          .doc('agora_config')
          .get();
          
      if (doc.exists && doc.data() != null) {
        _appId = doc.data()!['appId'];
        _primaryCertificate = doc.data()!['primarycertificate'];
      }

      if (_appId == null || _appId!.isEmpty) {
        throw Exception("Agora App ID not found in Firestore");
      }

      // 2. Request permissions
      await [Permission.camera, Permission.microphone].request();

      // 3. Initialize Engine
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(RtcEngineContext(
        appId: _appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ));

      // Setup basic event handlers
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint('[AgoraService] Joined channel: ${connection.channelId}');
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint('[AgoraService] Remote user joined: $remoteUid');
          },
          onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
            debugPrint('[AgoraService] Remote user offline: $remoteUid');
          },
          onActiveSpeaker: (RtcConnection connection, int uid) {
            _activeSpeakersController.add([uid]);
          },
        ),
      );

      _isInitialized = true;
      debugPrint('[AgoraService] Initialized successfully with App ID: $_appId');
    } catch (e) {
      debugPrint('[AgoraService] Error initializing: $e');
    }
  }

  RtcEngine? get engine => _engine;

  Future<void> joinVideoRoom({
    required String channelName,
    required int uid,
    required bool isHost,
  }) async {
    if (!_isInitialized) await initialize();
    
    await _engine!.setClientRole(role: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience);
    await _engine!.enableVideo();
    await _engine!.startPreview();

    // Since we don't have a backend to generate tokens yet, and app certificate is on, 
    // we need to pass a token. We will implement token generation using a dart package.
    String token = await _generateTokenLocal(channelName, uid);

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: isHost,
        publishMicrophoneTrack: isHost,
        clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
      ),
    );
  }

  Future<void> joinAudioRoom({
    required String channelName,
    required int uid,
    required bool isHost,
  }) async {
    if (!_isInitialized) await initialize();

    await _engine!.setClientRole(role: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience);
    await _engine!.enableAudio();
    await _engine!.disableVideo();

    String token = await _generateTokenLocal(channelName, uid);

    await _engine!.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: ChannelMediaOptions(
        autoSubscribeAudio: true,
        publishMicrophoneTrack: isHost,
        publishCameraTrack: false,
        clientRoleType: isHost ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
      ),
    );
  }
  
  // NOTE: Generating tokens on the client is insecure and only for testing.
  Future<String> _generateTokenLocal(String channelName, int uid) async {
    if (_primaryCertificate == null || _primaryCertificate!.isEmpty) {
      return ""; // Proceed without token if no certificate
    }
    
    try {
      final token = RtcTokenBuilder.build(
        appId: _appId!,
        appCertificate: _primaryCertificate!,
        channelName: channelName,
        uid: uid.toString(),
        role: RtcRole.publisher,
        expireTimestamp: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600, // 1 hour
      );
      return token;
    } catch (e) {
      debugPrint("Token generation failed: $e");
      return "";
    }
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();
  }

  Future<void> disconnect() async {
    await leaveChannel();
    await _engine?.release();
    _isInitialized = false;
  }
}
