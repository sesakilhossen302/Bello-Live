import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'package:collection/collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/cubits/app_cubit.dart';
import '../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../core/utils/view_count.dart';
import '../../core/widgets/GiftImageWidget.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../data/remote/firebase/app_services.dart';
import '../../data/remote/firebase/live_streaming_services.dart';
import '../../data/remote/firebase/profile_services.dart';
import '../../navigation/routes.dart';
import '../profile/profile_page.dart';
import '../streaming/audio_room_page.dart';
import 'bottomsheets/invite_pk_bottomsheet.dart';
import 'bottomsheets/profile_info_bottomsheet.dart';
import 'bottomsheets/emoji_bottomsheet.dart';
import 'bottomsheets/live_tools_bottomsheet.dart';
import 'bottomsheets/participants_bottomsheet.dart';
import 'bottomsheets/requests_bottomsheet.dart';

import '../../ui/streaming/bottomsheets/play_music_bottomsheet.dart';
import 'bottomsheets/video_gifts_bottomsheet.dart';

// --- MODELS ---
class LiveStreamParticipant {
  final String userId;
  final String userName;
  final String? userPicture;
  final bool isMuted;
  final bool isCameraOn;
  final bool isOnSeat;

  LiveStreamParticipant({
    required this.userId,
    required this.userName,
    this.userPicture,
    required this.isMuted,
    required this.isCameraOn,
    required this.isOnSeat,
  });

  factory LiveStreamParticipant.fromRTDB(
    String key,
    Map<dynamic, dynamic> data,
  ) {
    return LiveStreamParticipant(
      userId: data['userId'] ?? key,
      userName: data['userName'] ?? 'Unknown',
      userPicture: data.containsKey('userPicture') ? data['userPicture'] : null,
      isMuted: data['isMuted'] ?? true,
      isCameraOn: data['isCameraOn'] ?? false,
      isOnSeat: data['isOnSeat'] ?? false,
    );
  }
}

class JoinRequest {
  final String requestId;
  final String userId;
  final String userName;
  final String? userPicture;

  JoinRequest({
    required this.requestId,
    required this.userId,
    required this.userName,
    this.userPicture,
  });

  factory JoinRequest.fromRTDB(String key, Map<dynamic, dynamic> data) {
    return JoinRequest(
      requestId: key,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userPicture: data['userPicture'],
    );
  }
}

class ChatMessage {
  final String userId;
  final String username;
  final String message;
  final DateTime timestamp;
  final bool isGiftMessage;
  final int? giftValue;

  ChatMessage({
    required this.userId,
    required this.username,
    required this.message,
    required this.timestamp,
    this.isGiftMessage = false,
    this.giftValue,
  });
}

class EmojiEvent {
  final String senderId;
  final String senderName;
  final String emojiUrl;
  final String emojiName;

  EmojiEvent({
    required this.senderId,
    required this.senderName,
    required this.emojiUrl,
    required this.emojiName,
  });
}

// --- PAGE ---
class LiveStreamPage extends StatefulWidget {
  final String roomID;
  final bool isHost;

  const LiveStreamPage({super.key, required this.roomID, required this.isHost});

  @override
  State<LiveStreamPage> createState() => _LiveStreamPageState();
}

class _LiveStreamPageState extends State<LiveStreamPage>
    with SingleTickerProviderStateMixin {
  late MusicPlayerManager _musicPlayerManager;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();
  bool _isChatExpanded = false;

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Stream Subscriptions
  StreamSubscription? _roomSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _participantsSubscription;
  StreamSubscription? _joinRequestsSubscription;
  StreamSubscription? _emojiSubscription;
  StreamSubscription? _pkInvitesSubscription;
  StreamSubscription? _sentPKInvitesSubscription;
  StreamSubscription? _opponentParticipantsSubscription;
  StreamSubscription? _globalRandomPKInvitesSubscription;
  BuildContext? _currentRandomPKDialogContext;
  final Map<String, Stream<int>> _diamondsStreamCache = {};

  // Cache to store user levels to avoid redundant Firestore reads while scrolling
  final Map<String, int> _userLevelCache = {};

  int _lastProcessedGiftTime = 0;

  // State Variables
  late Map<String, dynamic> roomData;
  List<LiveStreamParticipant> _participants = [];
  final List<ChatMessage> _messages = [];
  List<JoinRequest> _joinRequests = [];
  List<PKInvite> _pendingInvites = [];
  int _participantCount = 0;
  bool _isInitialized = false;
  late bool _isJoined;
  bool _roomDoesNotExist = false;
  String _currentUserName = "Me";
  final Set<String> _dialogsShownForInviteIds = {};
  String _roomNotice = "";
  final ZegoVoiceChangerPreset _currentVoicePreset =
      ZegoVoiceChangerPreset.None;
  final bool _isSpeakerOn = true;

  // --- Join Animation Variables ---
  final Duration welcomeTime = const Duration(milliseconds: 3500);
  Timer? _joinAnimationTimer;
  String? _newJoinerName;
  late AnimationController _joinAnimationController;
  late Animation<Offset> _joinAnimationOffset;

  // PK State Variables
  bool _isPKMode = false;
  Map<String, dynamic> _pkState = {};
  bool _isMinimizing = false;
  List<LiveStreamParticipant> _opponentParticipants = [];

  Timer? _pkTimer;
  String _pkTimerDisplay = "00:00";

  final int _pkScoreBlue = 0;
  final int _pkScoreRed = 0;

  bool _isStartingPKAnimation = false;

  // Emoji State
  EmojiEvent? _currentEmojiEvent;
  Timer? _emojiTimer;

  GiftOverlay? _currentGiftOverlay;
  Timer? _giftOverlayTimer;
  String? _fullScreenGiftUrl;

  // --- Duration Timer Variables ---
  Timer? durationTimer;
  final ValueNotifier<Duration> _currentDuration = ValueNotifier(Duration.zero);

  @override
  void initState() {
    super.initState();
    _isJoined = widget.isHost;
    _musicPlayerManager = MusicPlayerManager();

    // Initialize Animation Controller
    _joinAnimationController = AnimationController(
      duration: welcomeTime,
      vsync: this,
    );
    _joinAnimationOffset = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(1.5, 0.0),
          end: const Offset(0.0, 0.0),
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0.0, 0.0)),
        weight: 3.0,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.0, 0.0),
          end: const Offset(-1.5, 0.0),
        ).chain(CurveTween(curve: Curves.linear)),
        weight: 1.0,
      ),
    ]).animate(_joinAnimationController);

    // Chat Focus Listeners
    _chatFocusNode.addListener(_updateChatExpansion);
    _chatController.addListener(_updateChatExpansion);

    _initialize();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  void _updateChatExpansion() {
    final shouldExpand =
        _chatFocusNode.hasFocus || _chatController.text.isNotEmpty;
    if (_isChatExpanded != shouldExpand) {
      setState(() {
        _isChatExpanded = shouldExpand;
      });
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _messageSubscription?.cancel();
    _participantsSubscription?.cancel();
    _joinRequestsSubscription?.cancel();
    _emojiSubscription?.cancel();
    _emojiTimer?.cancel();
    _pkInvitesSubscription?.cancel();
    _sentPKInvitesSubscription?.cancel();
    _opponentParticipantsSubscription?.cancel();
    _globalRandomPKInvitesSubscription?.cancel();
    _pkTimer?.cancel();

    _joinAnimationTimer?.cancel();
    _joinAnimationController.dispose();

    _chatFocusNode.removeListener(_updateChatExpansion);
    _chatFocusNode.dispose();
    _chatController.removeListener(_updateChatExpansion);
    _chatController.dispose();
    _chatScrollController.dispose();
    _musicPlayerManager.dispose();

    durationTimer?.cancel();
    _currentDuration.dispose();

    if (_isInitialized && !_isMinimizing) {
      if (widget.isHost) {
        if (_isPKMode && _pkState.containsKey('opponentRoomId')) {
          LiveStreamService.endPKBattle(
            widget.roomID,
            _pkState['opponentRoomId'],
          );

          String opponentHostId = _pkState['opponentHostId'] ?? '';
          if (opponentHostId.isNotEmpty) {
            ZegoUIKit().stopPlayAnotherRoomAudioVideo(opponentHostId);
          }
        }
        LiveStreamService.deleteRoom(widget.roomID);
      } else {
        if (_isJoined) {
          LiveStreamService.leaveRoom(widget.roomID);
        }
      }
      ZegoUIKit().leaveRoom();
      ZegoUIKit().logout();
      ZegoUIKit().uninit();
    }
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final permissions = widget.isHost
          ? [Permission.microphone, Permission.camera]
          : [Permission.microphone];
      if (!await _checkPermissions(permissions)) {
        if (mounted) context.pop();
        return;
      }

      final roomSnapshot = await LiveStreamService.getRoomInfo(widget.roomID);
      if (!roomSnapshot.exists) {
        if (mounted) {
          setState(() {
            _roomDoesNotExist = true;
          });
        }
        return;
      }

      roomData = Map<String, dynamic>.from(roomSnapshot.value as Map);
      _musicPlayerManager.initialize();
      await _finishInitialization();
    } catch (e) {
      debugPrint('Error initializing live stream: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        context.pop();
      }
    }
  }

  Future<void> _finishInitialization() async {
    await ZegoUIKit().init(
      appID: await AppServices.getZegoAppId(),
      appSign: await AppServices.getZegoAppSign(),
      scenario: ZegoScenario.Default,
    );

    ZegoUIKit().updateVideoViewMode(true);

    final currentUser = _auth.currentUser!;
    try {
      final userDoc = await ProfileService.getUserProfile(currentUser.uid);
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserName = data['displayName'] ?? "Unknown";
        });
      } else {
        setState(() {
          _currentUserName = currentUser.displayName ?? "Unknown";
        });
      }
    } catch (e) {
      debugPrint("Error fetching user name: $e");
      setState(() {
        _currentUserName = currentUser.displayName ?? "Unknown";
      });
    }

    ZegoUIKit().login(currentUser.uid, _currentUserName);
    await ZegoUIKit().joinRoom(widget.roomID);

    ZegoUIKit().turnMicrophoneOn(widget.isHost);
    ZegoUIKit().turnCameraOn(widget.isHost);
    ZegoUIKit().setAudioOutputToSpeaker(true);

    if (widget.isHost) {
      await LiveStreamService.toggleCameraState(widget.roomID, true);
    } else {
      if (!widget.isHost) {
        await LiveStreamService.joinRoom(widget.roomID);
        _sendJoinMessage();
      }
    }

    _setupListeners();
    setState(() => _isInitialized = true);
  }

  void startDurationTracking() {
    final startTimestamp = roomData['createdAt'] as int?;
    if (startTimestamp == null) return;

    durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - startTimestamp;

      // Update the value directly. NO setState()!
      _currentDuration.value = Duration(milliseconds: elapsed);
    });
  }

  void _startPKBattleSequence(Map<String, dynamic> newPKState) {
    setState(() {
      _pkState = newPKState;
    });

    if (!mounted) return;

    debugPrint("PK Animation finished. Starting PK logic.");

    if (widget.isHost) {
      final hostId = _auth.currentUser!.uid;
      LiveStreamService.demoteAllParticipantsToViewers(widget.roomID, hostId);
    }

    if (widget.isHost && newPKState['role'] == 'sender') {
      String opponentRoomId = newPKState['opponentRoomId'] ?? '';
      String opponentHostId = newPKState['opponentHostId'] ?? '';
      if (opponentRoomId.isNotEmpty && opponentHostId.isNotEmpty) {
        debugPrint(
          "Sender is starting to play opponent's stream: $opponentHostId",
        );
        ZegoUIKit().startPlayAnotherRoomAudioVideo(
          opponentRoomId,
          opponentHostId,
        );
      }
    }

    final dynamic pkEndTimeValue = newPKState['pkEndTime'];
    if (pkEndTimeValue != null) {
      final DateTime pkEndTime = DateTime.fromMillisecondsSinceEpoch(
        pkEndTimeValue as int,
      );
      _startPKTimer(pkEndTime);
    }

    _opponentParticipantsSubscription?.cancel();
    _opponentParticipantsSubscription =
        LiveStreamService.getRoomParticipants(
          newPKState['opponentRoomId'],
        ).listen((event) {
          if (!event.snapshot.exists) {
            if (mounted) setState(() => _opponentParticipants = []);
            return;
          }

          final participantsMap = Map<dynamic, dynamic>.from(
            event.snapshot.value as Map,
          );
          final newOpponentParticipants = participantsMap.entries
              .map(
                (entry) =>
                    LiveStreamParticipant.fromRTDB(entry.key, entry.value),
              )
              .toList();

          if (mounted) {
            setState(() {
              _opponentParticipants = newOpponentParticipants;
            });
          }
        });

    setState(() async {
      _isPKMode = true;
      await Future.delayed(Duration(seconds: 1));
      _isStartingPKAnimation = true;
      await Future.delayed(Duration(seconds: 3));
      _isStartingPKAnimation = false;
    });
  }

  void _showJoinAnimation(String userName) {
    _joinAnimationTimer?.cancel();
    _joinAnimationController.forward(from: 0.0);
    setState(() {
      _newJoinerName = userName;
    });
    _joinAnimationTimer = Timer(welcomeTime, () {
      if (mounted) {
        setState(() {
          _newJoinerName = null;
        });
      }
    });
  }

  Widget _buildJoinAnimationOverlay() {
    return Visibility(
      visible: _newJoinerName != null,
      child: Container(
        width: double.infinity,
        height: 100,
        margin: EdgeInsets.zero,
        color: Colors.transparent,
        child: SlideTransition(
          position: _joinAnimationOffset,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Image.asset("assets/animations/id_entry.gif", fit: BoxFit.cover),
              Center(
                child: Text(
                  '${_newJoinerName ?? ''} joined!',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    shadows: [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showGiftOverlay({
    required String senderName,
    String? senderPicture,
    required String giftAnimationUrl,
    required String giftImageUrl,
    bool isLuckyGift = false,
    int? hitCount,
    String? senderId,
  }) {
    _giftOverlayTimer?.cancel();

    setState(() {
      _currentGiftOverlay = GiftOverlay(
        senderName: senderName,
        senderPicture: senderPicture,
        giftImageUrl: giftImageUrl,
        luckyHitCount: hitCount,
        senderId: senderId,
      );

      if (!isLuckyGift) {
        _fullScreenGiftUrl = giftAnimationUrl;
      }
    });

    _giftOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentGiftOverlay = null;
        });
      }
    });
  }

  void _setupListeners() {
    _roomSubscription = LiveStreamService.getRoomStream(widget.roomID).listen((
      event,
    ) {
      if (event.snapshot.exists && mounted) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        setState(() {
          roomData = data;
          _participantCount = roomData['participantCount'] ?? 0;
          _roomNotice = roomData['notice'] ?? "";
        });

        if (widget.isHost && durationTimer == null) {
          startDurationTracking();
        }

        final newPKState = data['pkState'] != null
            ? Map<String, dynamic>.from(data['pkState'] as Map)
            : <String, dynamic>{'isPK': false};

        final bool isNowInPK = newPKState['isPK'] == true;

        if (isNowInPK && !_isPKMode) {
          if (!_isStartingPKAnimation) {
            _startPKBattleSequence(newPKState);
          }
        } else if (!isNowInPK && _isPKMode) {
          debugPrint("PK Mode ENDING");
          if (widget.isHost) {
            String opponentHostId = _pkState['opponentHostId'] ?? '';
            if (opponentHostId.isNotEmpty) {
              ZegoUIKit().stopPlayAnotherRoomAudioVideo(opponentHostId);
            }
          }
          _opponentParticipantsSubscription?.cancel();
          _pkTimer?.cancel();

          setState(() {
            _isPKMode = false;
            _pkState = {};
            _opponentParticipants = [];
            _pkTimerDisplay = "00:00";
          });
        }
      } else {
        if (mounted) context.pop();
      }
    });

    _messageSubscription = ZegoUIKit().getInRoomMessageStream().listen((
      message,
    ) {
      if (mounted) {
        setState(() {
          _messages.insert(
            0,
            ChatMessage(
              username: message.user.name,
              message: message.message,
              timestamp: DateTime.now(),
              userId: message.user.id,
            ),
          );
          _scrollToNewestMessage();
        });
      }
    });

    _participantsSubscription =
        LiveStreamService.getRoomParticipants(widget.roomID).listen((event) {
          if (!event.snapshot.exists) {
            if (mounted) setState(() => _participants = []);
            return;
          }
          final participantsMap = Map<dynamic, dynamic>.from(
            event.snapshot.value as Map,
          );
          final newParticipants = participantsMap.entries
              .map(
                (entry) =>
                    LiveStreamParticipant.fromRTDB(entry.key, entry.value),
              )
              .toList();

          if (_participants.isNotEmpty && _newJoinerName == null) {
            final oldParticipantIds = _participants
                .map((p) => p.userId)
                .toSet();
            final String hostId = roomData['hostId'] ?? '';

            final newGuests = newParticipants
                .where(
                  (p) =>
                      !oldParticipantIds.contains(p.userId) &&
                      p.userId != hostId,
                )
                .toList();

            if (newGuests.isNotEmpty) {
              _showJoinAnimation(newGuests.first.userName);
            }
          }

          final currentUser = _auth.currentUser!;
          final isNowJoined = newParticipants.any(
            (p) => p.userId == currentUser.uid && p.isOnSeat,
          );

          if (isNowJoined && !_isJoined) {
            debugPrint("Join request approved! Starting local audio stream.");
            ZegoUIKit().turnMicrophoneOn(true);
          }

          if (mounted) {
            setState(() {
              _participants = newParticipants;
              _isJoined = isNowJoined;
            });
          }
        });

    _emojiSubscription = LiveStreamService.getEmojiStream(widget.roomID).listen(
      (event) {
        if (!mounted || !event.snapshot.exists || event.snapshot.value == null)
          return;

        if (event.snapshot.value is! Map) return;
        final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
        final timestamp = data['timestamp'] as int? ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now - timestamp < 5000) {
          _showEmoji(
            senderId: data['senderId'] ?? '',
            senderName: data['senderName'] ?? 'Unknown',
            emojiUrl: data['emojiUrl'] ?? '',
            emojiName: data['emojiName'] ?? '',
          );
        }
      },
    );

    LiveStreamService.getGiftStream(widget.roomID).listen((event) {
      if (!mounted || !event.snapshot.exists || event.snapshot.value == null)
        return;

      if (event.snapshot.value is! Map) return;
      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final timestamp = (data['timestamp'] as int?) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Prevent double-firing (local cache vs online update)
      if (timestamp == 0 || (timestamp - _lastProcessedGiftTime).abs() < 1000) {
        return;
      }
      _lastProcessedGiftTime = timestamp;

      if (now - timestamp < 5000) {
        final String? giftCategory = data['category'] as String?;
        final bool isLuckyGift = giftCategory == 'Lucky';
        final int? hitCount = data['hitCount'] as int?;

        final int giftValue = data['giftValue'] as int? ?? 0;
        final String senderName = data['senderName'] ?? 'Unknown';
        final String? receiverName = data['receiverName'] as String?;

        if (mounted) {
          setState(() {
            String giftMessageText;
            if (receiverName != null && receiverName.isNotEmpty) {
              giftMessageText =
                  '$senderName sent $giftValue diamonds to $receiverName';
            } else {
              giftMessageText = '$senderName sent $giftValue diamonds';
            }

            _messages.insert(
              0,
              ChatMessage(
                userId: data['senderId'] ?? '',
                username: senderName,
                message: giftMessageText,
                timestamp: DateTime.now(),
                isGiftMessage: true,
                // Triggers the UI below
                giftValue: giftValue,
              ),
            );
          });
          _scrollToNewestMessage();
        }

        _showGiftOverlay(
          senderName: senderName,
          senderPicture: data['senderPicture'],
          giftAnimationUrl: data['giftAnimationUrl'] ?? '',
          giftImageUrl: data['giftImageUrl'] ?? '',
          isLuckyGift: isLuckyGift,
          hitCount: hitCount,
          senderId: data['senderId'],
        );
      }
    });

    if (widget.isHost) {
      _joinRequestsSubscription =
          LiveStreamService.getJoinRequestsStream(widget.roomID).listen((
            event,
          ) {
            if (!event.snapshot.exists) {
              if (mounted) setState(() => _joinRequests = []);
              return;
            }
            final requestsMap = Map<dynamic, dynamic>.from(
              event.snapshot.value as Map,
            );
            final requests = requestsMap.entries
                .map((entry) => JoinRequest.fromRTDB(entry.key, entry.value))
                .toList();
            if (mounted) setState(() => _joinRequests = requests);
          });

      _pkInvitesSubscription =
          LiveStreamService.getPKInvitesStream(widget.roomID).listen((invites) {
            debugPrint('Received PK invites: $invites');
            setState(() {
              _pendingInvites = invites;
            });

            final newInvite = invites.firstWhereOrNull(
              (invite) => !_dialogsShownForInviteIds.contains(invite.id),
            );

            if (newInvite != null) {
              _dialogsShownForInviteIds.add(newInvite.id);
              _showPKInviteDialog(newInvite);
            }
          });

      _globalRandomPKInvitesSubscription =
          LiveStreamService.getGlobalRandomPKInvitesStream().listen((invites) {
            if (invites.isEmpty) return;

            for (final invite in invites) {
              if (invite.senderRoomId == widget.roomID) continue;
              if (_dialogsShownForInviteIds.contains(invite.id)) continue;

              _dialogsShownForInviteIds.add(invite.id);

              if (_currentRandomPKDialogContext != null) {
                Navigator.of(_currentRandomPKDialogContext!).pop();
                _currentRandomPKDialogContext = null;
              }

              _showGlobalRandomPKInviteDialog(invite);
            }
          });

      _sentPKInvitesSubscription =
          LiveStreamService.getSentPKInvitesStream(widget.roomID).listen((
            acceptedInvites,
          ) {
            debugPrint('Received accepted PK invites: $acceptedInvites');

            final newAcceptedInvite = acceptedInvites.firstWhereOrNull(
              (invite) => !_dialogsShownForInviteIds.contains(invite.id),
            );

            if (newAcceptedInvite != null && !_isPKMode) {
              _dialogsShownForInviteIds.add(newAcceptedInvite.id);
            }
          });
    }
  }

  void _startPKTimer(DateTime endTime) {
    _pkTimer?.cancel();
    _pkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final now = DateTime.now();
      final remaining = endTime.difference(now);

      if (remaining.isNegative) {
        timer.cancel();
        setState(() {
          _pkTimerDisplay = "00:00";
        });
        if (widget.isHost && _isPKMode) {
          debugPrint("PK Timer finished. Ending battle.");
          LiveStreamService.endPKBattle(
            widget.roomID,
            _pkState['opponentRoomId'],
          );
        }
      } else {
        setState(() {
          _pkTimerDisplay = _formatDuration(remaining);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Future<void> _showGlobalRandomPKInviteDialog(PKInvite invite) async {
    int remainingSeconds = 5;
    late void Function(void Function()) builderRef;
    Timer? autoCloseTimer;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _currentRandomPKDialogContext = dialogContext;

        autoCloseTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
          if (remainingSeconds <= 1) {
            timer.cancel();
            _currentRandomPKDialogContext = null;
            Navigator.of(dialogContext).maybePop();
          } else {
            remainingSeconds--;
            builderRef(() {});
          }
        });

        return StatefulBuilder(
          builder: (ctx, setState) {
            builderRef = setState;
            return AlertDialog(
              backgroundColor: const Color(0xFF2d1b2b),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Text(
                    'Random PK Invitation',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${remainingSeconds}s',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                '${invite.senderHostName} wants to start a '
                '${invite.durationInMinutes}-minute PK. What do you want to do?',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _currentRandomPKDialogContext = null;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text(
                    'Ignore',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    _currentRandomPKDialogContext = null;
                    Navigator.of(dialogContext).pop();

                    try {
                      await LiveStreamService.acceptGlobalRandomPKInvite(
                        widget.roomID,
                        invite,
                      );
                      ZegoUIKit().startPlayAnotherRoomAudioVideo(
                        invite.senderRoomId,
                        invite.senderHostId,
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceAll('Exception: ', ''),
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'Accept',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    autoCloseTimer?.cancel();
    _currentRandomPKDialogContext = null;
  }

  Future<void> _showPKInviteDialog(PKInvite invite) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b2b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'PK Invitation',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${invite.senderHostName} wants to start a ${invite.durationInMinutes}-minute PK. What do you want to do?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              LiveStreamService.rejectPKInvite(widget.roomID, invite);
            },
            child: const Text(
              'Reject',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();

              LiveStreamService.acceptPKInvite(widget.roomID, invite);
              ZegoUIKit().startPlayAnotherRoomAudioVideo(
                invite.senderRoomId,
                invite.senderHostId,
              );
            },
            child: const Text('Accept', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEmoji({
    required String senderId,
    required String senderName,
    required String emojiUrl,
    required String emojiName,
  }) {
    _emojiTimer?.cancel();
    setState(() {
      _currentEmojiEvent = EmojiEvent(
        senderId: senderId,
        senderName: senderName,
        emojiUrl: emojiUrl,
        emojiName: emojiName,
      );
    });

    _emojiTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentEmojiEvent = null;
        });
      }
    });
  }

  bool _shouldShowEmoji(String userId) {
    return _currentEmojiEvent != null && _currentEmojiEvent!.senderId == userId;
  }

  Widget _buildEmojiOnAvatar(String userId, double size) {
    if (!_shouldShowEmoji(userId)) return const SizedBox.shrink();
    return Positioned.fill(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle),
        child: GiftImageWidget(
          imageUrl: _currentEmojiEvent!.emojiUrl,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Future<bool> _checkPermissions(List<Permission> permissions) async {
    await permissions.request();
    for (final permission in permissions) {
      if (!(await permission.status).isGranted) {
        return false;
      }
    }
    return true;
  }

  void _scrollToNewestMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.jumpTo(0.0);
      }
    });
  }

  Future<bool?> _showExitConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 110,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF212121).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(55),
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildExitDialogOption(
                  icon: Icons.keyboard_arrow_down,
                  color: Colors.purple,
                  label: 'Minimize',
                  onTap: () {
                    _isMinimizing = true;
                    context.read<AppCubit>().minimizeRoom(
                      MinimizedRoomData(
                        roomId: widget.roomID,
                        hostPicture: roomData['hostPicture'] ?? '',
                        hostName: roomData['hostName'] ?? 'Host',
                        isAudioRoom: false,
                        isHost: widget.isHost,
                      ),
                    );
                    Navigator.of(context).pop(false);
                    context.go(
                      Routes.home.path,
                    ); // Always go to Home when minimizing
                  },
                ),
                const SizedBox(height: 24),
                _buildExitDialogOption(
                  icon: Icons.power_settings_new,
                  color: Colors.red,
                  label: 'Exit',
                  onTap: () {
                    Navigator.of(context).pop(true);
                  },
                ),
                const SizedBox(height: 24),
                _buildExitDialogOption(
                  icon: Icons.close,
                  color: Colors.white.withValues(alpha: 0.2),
                  label: 'Cancel',
                  onTap: () {
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((shouldExit) {
      if (shouldExit == true) {
        if (!mounted) return shouldExit;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.home.path);
        }
      }
      return shouldExit;
    });
  }

  Widget _buildExitDialogOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_roomDoesNotExist) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF000000), Color(0xFF1a0a0a), Color(0xFF2d1b2b)],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  child: const Icon(
                    Icons.link_off_rounded,
                    size: 60,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Room Ended",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "The live session you are looking for\nhas ended or does not exist.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () => context.go(Routes.home.path),
                  child: const Text(
                    "Go to Homepage",
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        // Check if keyboard is open
        if (MediaQuery.of(context).viewInsets.bottom > 0) {
          // Keyboard is open, just close it
          FocusManager.instance.primaryFocus?.unfocus();
          return;
        }

        // Keyboard is closed, show exit confirmation
        await _showExitConfirmationDialog();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            if (!_isPKMode)
              Positioned.fill(
                child: _isInitialized
                    ? _buildVideoLayout()
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF000000),
                              Color(0xFF1a0a0a),
                              Color(0xFF2d1b2b),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.pink),
                        ),
                      ),
              ),
            if (_isInitialized)
              _isPKMode ? _buildPKModeLayout() : _buildStandardModeOverlay()
            else
              const SizedBox.shrink(),
            Visibility(
              visible: _isStartingPKAnimation,
              child: _buildPKStartingAnimation(),
            ),
            Center(child: _buildJoinAnimationOverlay()),
            _buildFullScreenGift(),
            _buildGiftOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildPKModeLayout() {
    return Column(
      children: [
        _buildAppBar(),
        _buildHostStatsRow(),
        Expanded(flex: 2, child: _buildPKVideoLayout()),
        _buildPKProgressBar(),
        _buildPKEmptySeats(),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(flex: 1, child: _buildChatSection()),
              SafeArea(top: false, child: _buildChatInput()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStandardModeOverlay() {
    return Column(
      children: [
        _buildAppBar(),
        _buildHostStatsRow(),
        Expanded(
          child: Stack(
            children: [
              Align(
                alignment: Alignment.bottomCenter,
                child: _buildChatSection(),
              ),
              _buildJoinCallOverlay(),
            ],
          ),
        ),
        SafeArea(top: false, child: _buildChatInput()),
      ],
    );
  }

  Widget _buildAppBar() {
    final String hostId = roomData['hostId'] ?? '';
    final String hostDisplayId = roomData['hostDisplayId'] ?? '';
    final String currentUserId = _auth.currentUser?.uid ?? '';

    // ADD THIS: Check if the current user is a guest (not the host)
    final bool isGuest = !widget.isHost && hostId != currentUserId;

    // Filter out the host to get the list of guests
    final guestParticipants = _participants
        .where((p) => p.userId != hostId)
        .toList();

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 12.0, 0, 6.0),
        child: Row(
          children: [
            // Host Info Section with capsule background - FLEXIBLE
            Flexible(
              child: GestureDetector(
                onTap: () {
                  if (hostId == currentUserId) return;
                  showProfileInfoBottomSheet(
                    context,
                    userId: hostId,
                    hostId: hostId,
                    roomId: widget.roomID,
                  );
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IntrinsicWidth(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 32, // radius 16 * 2
                            height: 32,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: NetworkImage(
                                    roomData['hostPicture'] ?? '',
                                  ),
                                ),
                                Positioned(
                                  width: 41.6, // 32 * 1.3
                                  height: 41.6,
                                  child: IgnorePointer(
                                    child: ActiveFrameWidget(
                                      userId: hostId,
                                      size: 41.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_isPKMode)
                                      Container(
                                        margin: const EdgeInsets.only(right: 4),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'PK',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    Flexible(
                                      child: AutoScrollText(
                                        alignment: Alignment.centerLeft,
                                        text: roomData["hostName"] ?? '',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'ID: $hostDisplayId',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 10,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // ADD THIS: Follow Button inside the capsule
                          if (isGuest)
                            StreamBuilder<bool>(
                              stream: ProfileService.isFollowing(hostId),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const SizedBox.shrink();
                                final bool isFollowing = snapshot.data ?? false;
                                if (isFollowing) return const SizedBox.shrink();

                                return Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: GestureDetector(
                                    onTap: () async {
                                      try {
                                        await ProfileService.followUser(hostId);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: Container(
                                      width:
                                          24, // Sized perfectly for the capsule
                                      height: 24,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.pink.shade400,
                                            Colors.pink.shade700,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),
            // Participant Avatars Stack
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 70),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: _buildParticipantAvatars(guestParticipants),
              ),
            ),

            const SizedBox(width: 6),

            // Participant Count Badge
            GestureDetector(
              onTap: () {
                showLiveStreamParticipantsBottomSheet(
                  context,
                  participants: _participants,
                  currentUserId: _auth.currentUser!.uid,
                  hostId: roomData['hostId'],
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      CupertinoIcons.person_2_fill,
                      color: Colors.pink,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _participantCount.toString(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Exit Button - FIXED AT RIGHT
            IconButton(
              icon: const Icon(
                Icons.exit_to_app_rounded,
                size: 24,
                color: Colors.grey,
              ),
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
              onPressed: _showExitConfirmationDialog,
              tooltip: 'Exit Room',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label, Color iconColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDurationChip() {
    return ValueListenableBuilder<Duration>(
      valueListenable: _currentDuration,
      builder: (context, duration, child) {
        final hours = duration.inHours.toString().padLeft(2, '0');
        final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
        final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time, color: Colors.pink, size: 14),
              const SizedBox(width: 4),
              Text(
                '$hours:$minutes:$seconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHostStatsRow() {
    final String hostId = roomData['hostId'] ?? '';
    if (hostId.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 0, 8.0, 8.0),
      child: Row(
        children: [
          // Duration timer chip for host
          if (widget.isHost) ...[buildDurationChip(), const SizedBox(width: 8)],
          StreamBuilder<int>(
            stream: _diamondsStreamCache.putIfAbsent(
              hostId,
              () => ProfileService.getMonthlyReceivedDiamondsStream(hostId),
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Row(
                  children: [
                    _buildStatChip(
                      Icons.diamond_outlined,
                      "...",
                      Colors.grey.shade700,
                    ),
                  ],
                );
              }

              final int dailyDiamonds = snapshot.data ?? 0;

              return GestureDetector(
                onTap: () {
                  // showGiftRankingBottomSheet(context, hostId);
                },
                child: Row(
                  children: [
                    _buildStatChip(
                      Icons.diamond_outlined,
                      formatViewCount(dailyDiamonds),
                      Colors.cyan.shade300,
                    ),
                  ],
                ),
              );
            },
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildPKProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 12,
              color: Colors.black45,
              child: Row(
                children: [
                  Expanded(flex: 1, child: Container(color: Colors.blue)),
                  Expanded(flex: 1, child: Container(color: Colors.red)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPKScoreChip(
                  _pkScoreBlue.toString(),
                  Colors.blue.shade300,
                ),
                _buildPKScoreChip(_pkScoreRed.toString(), Colors.red.shade300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPKScoreChip(String score, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Center(
        child: Text(
          score,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildPKTimerWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 1),
      ),
      child: Text(
        _pkTimerDisplay,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildPKEmptySeats() {
    Widget buildSeatIcon(int number) {
      return Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(
                Icons.event_seat_rounded,
                color: Colors.amber,
                size: 16,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            number.toString(),
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) => buildSeatIcon(index + 1)),
          ),
          const Spacer(),
          _buildPKTimerWidget(),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) => buildSeatIcon(index + 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildPKStartingAnimation() {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * .2,
              ),
              height: MediaQuery.of(context).size.height / 2,
              child: Image.asset(
                "assets/animations/pk_start.gif",
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHostVideo(LiveStreamParticipant host) {
    if (host.isCameraOn) {
      final zegoUser = ZegoUIKit().getUser(host.userId);
      return ClipRect(child: ZegoAudioVideoView(user: zegoUser));
    }
    return ClipRect(
      child: SizedBox.expand(
        child: Container(
          color: Colors.black.withValues(alpha: 0.5),
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage:
                    host.userPicture != null && host.userPicture!.isNotEmpty
                    ? NetworkImage(host.userPicture!)
                    : null,
                child: host.userPicture == null || host.userPicture!.isEmpty
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                ),
              ),
              const Icon(Icons.videocam_off, color: Colors.white, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuestAvatar(LiveStreamParticipant guest) {
    final borderRadius = BorderRadius.circular(10.0);
    const double itemWidth = 70;
    const double itemHeight = itemWidth * (4 / 3);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: SizedBox(
        width: itemWidth,
        height: itemHeight,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  image:
                      (guest.userPicture != null &&
                          guest.userPicture!.isNotEmpty)
                      ? DecorationImage(
                          image: NetworkImage(guest.userPicture!),
                          fit: BoxFit
                              .cover, // Ensures the image fills the 3:4 area
                        )
                      : null,
                  color: Colors.grey.shade800,
                ),
                child: (guest.userPicture == null || guest.userPicture!.isEmpty)
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              if (guest.isMuted)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Icon(
                    Icons.mic_off,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              // Updated emoji overlay to match the new size
              _buildEmojiOnAvatar(guest.userId, itemWidth),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoLayout() {
    final String hostId = roomData['hostId'];
    LiveStreamParticipant? host;
    final List<LiveStreamParticipant> guests = [];
    for (final p in _participants) {
      if (p.userId == hostId) {
        host = p;
      } else if (p.isOnSeat) {
        guests.add(p);
      }
    }
    return Stack(
      children: [
        Positioned.fill(
          child: host != null
              ? Stack(
                  children: [
                    _buildHostVideo(host),
                    if (_shouldShowEmoji(host.userId))
                      Center(
                        child: Container(
                          width: 150,
                          height: 150,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: GiftImageWidget(
                            imageUrl: _currentEmojiEvent!.emojiUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                  ],
                )
              : Container(
                  color: Colors.black,
                  child: const Center(
                    child: Text(
                      'Waiting for host...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
        ),
        Positioned(
          top: 180,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: guests.map((guest) => _buildGuestAvatar(guest)).toList(),
          ),
        ),
      ],
    );
  }

  // FIXED: PK Video layout with proper positioning using Row and BoxFit.cover
  Widget _buildPKVideoLayout() {
    return Row(
      children: [
        Expanded(
          child: _buildTeamHost(
            participants: _participants,
            hostName: roomData['hostName'] ?? 'Host A',
          ),
        ),
        Expanded(
          child: _buildTeamHost(
            participants: _opponentParticipants,
            hostName: _pkState['opponentHostName'] ?? 'Host B',
          ),
        ),
      ],
    );
  }

  Widget _buildTeamHost({
    required List<LiveStreamParticipant> participants,
    required String hostName,
  }) {
    if (participants.isEmpty) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            'Waiting for $hostName...',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final host = participants.first;
    return _buildHostVideoForPK(host);
  }

  // FIXED: Host video for PK with BoxFit.cover for no black bars
  Widget _buildHostVideoForPK(LiveStreamParticipant host) {
    if (host.isCameraOn) {
      final zegoUser = ZegoUIKit().getUser(host.userId);
      return SizedBox.expand(
        child: ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: ValueListenableBuilder<Size>(
              valueListenable: ZegoUIKit().getVideoSizeNotifier(host.userId),
              builder: (context, videoSize, _) {
                return SizedBox(
                  width: videoSize.width,
                  height: videoSize.height,
                  child: ZegoAudioVideoView(user: zegoUser),
                );
              },
            ),
          ),
        ),
      );
    }
    return Container(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 80, // radius 40 * 2
          height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage:
                    host.userPicture != null && host.userPicture!.isNotEmpty
                    ? NetworkImage(host.userPicture!)
                    : null,
                child: host.userPicture == null || host.userPicture!.isEmpty
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              Positioned(
                width: 104, // 80 * 1.3
                height: 104,
                child: IgnorePointer(
                  child: ActiveFrameWidget(userId: host.userId, size: 104),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullScreenGift() {
    if (_fullScreenGiftUrl == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 500),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Center(
              child: Transform.scale(scale: value, child: child),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Colors.pink.withValues(alpha: 0.3), Colors.transparent],
            ),
          ),
          child: GiftImageWidget(
            imageUrl: _fullScreenGiftUrl!,
            fit: BoxFit.contain,
            isFullScreenAnimation: true,
            onAnimationComplete: () {
              if (mounted) {
                setState(() {
                  _fullScreenGiftUrl = null;
                });
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildGiftOverlay() {
    if (_currentGiftOverlay == null) return const SizedBox.shrink();

    return Positioned(
      left: 20,
      top: MediaQuery.of(context).size.height * 0.5 - 40,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.scale(scale: value, child: child),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade900.withValues(alpha: 0.95),
                    Colors.pink.shade700.withValues(alpha: 0.95),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withValues(alpha: 0.6),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Sender's picture
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.pink, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 0.5,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child:
                                _currentGiftOverlay!.senderPicture != null &&
                                    _currentGiftOverlay!
                                        .senderPicture!
                                        .isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl:
                                        _currentGiftOverlay!.senderPicture!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.person,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                          ),
                        ),
                        if (_currentGiftOverlay!.senderId != null)
                          Positioned(
                            width: 44.2, // 34 * 1.3
                            height: 44.2,
                            child: IgnorePointer(
                              child: ActiveFrameWidget(
                                userId: _currentGiftOverlay!.senderId!,
                                size: 44.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name and gift text
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _currentGiftOverlay!.senderName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 3),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentGiftOverlay!.luckyHitCount != null
                            ? 'sent ${_currentGiftOverlay!.luckyHitCount} LUCKY gift!'
                            : 'sent a gift',
                        style: TextStyle(
                          color: _currentGiftOverlay!.luckyHitCount != null
                              ? Colors.yellow.shade200
                              : Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  // Gift icon
                  CachedNetworkImage(
                    imageUrl: _currentGiftOverlay!.giftImageUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.card_giftcard,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinCallOverlay() {
    return Visibility(
      visible: !_isJoined && !widget.isHost,
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20, right: 20),
          child: GestureDetector(
            onTap: () async {
              try {
                await LiveStreamService.requestToJoin(widget.roomID);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Request sent. Wait for host approval.'),
                      backgroundColor: Colors.pink,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.pink, width: 1.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset(
                  'assets/images/join_call.jpeg',
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Optimized method to get the level asset safely
  Widget _buildLevelBadge(String userId) {
    if (_userLevelCache.containsKey(userId)) {
      final level = _userLevelCache[userId]!;
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Image.asset(
          'assets/images/levels/rank_caifu_cf_$level.png',
          height: 18,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const SizedBox(width: 36, height: 18),
        ),
      );
    } else {
      // Fetch level silently and cache it to avoid spamming Firestore reads on scroll
      ProfileService.getUserProfile(userId)
          .then((doc) {
            if (doc.exists && mounted) {
              final data = doc.data() as Map<String, dynamic>;
              final int totalSent = data['totalSent'] ?? 0;
              setState(() {
                _userLevelCache[userId] = getSentLevel(totalSent);
              });
            }
          })
          .catchError((_) {});

      // Fallback placeholder while it's fetching
      return Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Image.asset(
          'assets/images/levels/rank_caifu_cf_1.png',
          height: 18,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              const SizedBox(width: 36, height: 18),
        ),
      );
    }
  }

  Widget _buildChatSection() {
    return Container(
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height * 0.25,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black.withValues(alpha: 0.2),
      ),
      child: ListView.builder(
        reverse: true,
        controller: _chatScrollController,
        padding: const EdgeInsets.all(12),
        itemCount: _messages.length + 1,
        itemBuilder: (context, index) {
          if (index == _messages.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 150,
                    child: Text(
                      "Any sexual or violation content is strictly prohibited. All violator will be banned. Do not expose your personal info such phone or location.",
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                  if (_roomNotice.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.pink.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.pink.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.campaign,
                            color: Colors.pink,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _roomNotice,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }

          final m = _messages[index];

          if (m.isGiftMessage) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.pink.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.diamond, color: Colors.cyan, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        m.message,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.pink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    showProfileInfoBottomSheet(
                      context,
                      userId: m.userId,
                      hostId: roomData['hostId'] ?? '',
                      roomId: widget.roomID,
                    );
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLevelBadge(m.userId),
                      Text(
                        "${m.username}: ",
                        style: TextStyle(
                          color: Colors.pink.shade300,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 0, top: 2),
                  child: Text(
                    m.message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildChatInput() {
    LiveStreamParticipant? currentUserParticipant;
    if (_isJoined) {
      try {
        currentUserParticipant = _participants.firstWhere(
          (p) => p.userId == _auth.currentUser!.uid,
        );
      } catch (e) {
        currentUserParticipant = null;
      }
    }
    final bool isCurrentlyMuted = currentUserParticipant?.isMuted ?? true;
    final int totalRequests = _joinRequests.length;

    const double buttonSize = 34.0;
    const double iconSize = 18.0;
    const double paddingRight = 6.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        10,
        8,
        10,
        8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Row(
        children: [
          if (!_isChatExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(right: paddingRight),
              child: GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  showLiveToolsBottomSheet(
                    context,
                    isHost: widget.isHost,
                    currentRoomId: widget.roomID,
                    hostName: roomData['hostName'] ?? 'Host',
                    pendingInvites: _pendingInvites,
                    musicManager: _musicPlayerManager,
                  );
                },
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: paddingRight),
              child: GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  final convertedParticipants = _participants.map((p) {
                    return _ConvertedParticipant(
                      userId: p.userId,
                      userName: p.userName,
                      userPicture: p.userPicture,
                    );
                  }).toList();

                  showGiftBottomSheet(
                    context,
                    roomId: widget.roomID,
                    participants: convertedParticipants,
                    hostId: roomData['hostId'] ?? '',
                  );
                },
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.2),
                  ),
                  child: const Icon(
                    CupertinoIcons.gift_fill,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
            if (_isJoined) ...[
              Padding(
                padding: const EdgeInsets.only(right: paddingRight),
                child: GestureDetector(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    showVideoLiveEmojiBottomSheet(context, widget.roomID);
                  },
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      CupertinoIcons.smiley,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: paddingRight),
                child: GestureDetector(
                  onTap: () {
                    final newMuteState = !isCurrentlyMuted;
                    LiveStreamService.toggleMuteState(
                      widget.roomID,
                      newMuteState,
                    );
                    ZegoUIKit().turnMicrophoneOn(!newMuteState);
                  },
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                    child: Icon(
                      isCurrentlyMuted
                          ? CupertinoIcons.mic_off
                          : CupertinoIcons.mic_fill,
                      color: isCurrentlyMuted ? Colors.white : Colors.pink,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
            ],
            if (widget.isHost)
              Padding(
                padding: const EdgeInsets.only(right: paddingRight),
                child: GestureDetector(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    showLiveStreamJoinRequestsBottomSheet(
                      context: context,
                      joinRequests: _joinRequests,
                      roomID: widget.roomID,
                    );
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: buttonSize,
                        height: buttonSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.2),
                        ),
                        child: const Icon(
                          CupertinoIcons.person_add_solid,
                          color: Colors.white,
                          size: iconSize,
                        ),
                      ),
                      if (totalRequests > 0)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.pink,
                            ),
                            child: Text(
                              totalRequests.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            if (_isJoined && !widget.isHost)
              Padding(
                padding: const EdgeInsets.only(right: paddingRight),
                child: GestureDetector(
                  onTap: () async {
                    FocusManager.instance.primaryFocus?.unfocus();
                    try {
                      ZegoUIKit().turnMicrophoneOn(false);
                      await LiveStreamService.leaveSeat(widget.roomID);
                    } catch (e) {
                      debugPrint("Error leaving call: $e");
                    }
                  },
                  child: Container(
                    width: buttonSize,
                    height: buttonSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                    ),
                    child: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
          ],
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: buttonSize,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.0,
                ),
              ),
              child: Center(
                child: TextField(
                  controller: _chatController,
                  focusNode: _chatFocusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Say something...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Colors.pink.shade400, Colors.pink.shade600],
                ),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final messageText = _chatController.text.trim();
    if (messageText.isEmpty) return;

    try {
      await ZegoUIKit().sendInRoomMessage(messageText);
      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            userId: _auth.currentUser!.uid,
            username: _currentUserName,
            message: messageText,
            timestamp: DateTime.now(),
          ),
        );
      });
      _chatController.clear();
      _scrollToNewestMessage();
      FocusManager.instance.primaryFocus?.unfocus();
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _sendJoinMessage() async {
    const messageText = "Just joined the room!";
    try {
      await ZegoUIKit().sendInRoomMessage(messageText);
      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              userId: _auth.currentUser!.uid,
              username: _currentUserName,
              message: messageText,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error sending join message: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.jumpTo(
          _chatScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Widget _buildParticipantAvatars(List<LiveStreamParticipant> participants) {
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    const double avatarSize = 20.0;
    const double overlap = 15.0;

    final participantsToShow = participants.take(5).toList();
    final double stackWidth =
        avatarSize + (participantsToShow.length - 1) * overlap;

    return SizedBox(
      width: stackWidth,
      height: avatarSize,
      child: Stack(
        children: participantsToShow
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final participant = entry.value;
              final double leftPosition = index * overlap;

              return Positioned(
                left: leftPosition,
                child: SizedBox(
                  width: avatarSize,
                  height: avatarSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: CircleAvatar(
                          radius: (avatarSize / 2) - 1,
                          backgroundImage:
                              participant.userPicture != null &&
                                  participant.userPicture!.isNotEmpty
                              ? NetworkImage(participant.userPicture!)
                              : null,
                          child:
                              (participant.userPicture == null ||
                                  participant.userPicture!.isEmpty)
                              ? const Icon(
                                  Icons.person,
                                  size: 12,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        width: avatarSize * 1.3,
                        height: avatarSize * 1.3,
                        child: IgnorePointer(
                          child: ActiveFrameWidget(
                            userId: participant.userId,
                            size: avatarSize * 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            })
            .toList()
            .reversed
            .toList(),
      ),
    );
  }
}

class _ConvertedParticipant {
  final String userId;
  final String userName;
  final String? userPicture;

  _ConvertedParticipant({
    required this.userId,
    required this.userName,
    this.userPicture,
  });
}
