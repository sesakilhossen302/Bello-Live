import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:go_router/go_router.dart';
import 'package:picture_live/core/utils/view_count.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/cubits/app_cubit.dart';

import '../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../core/widgets/GiftImageWidget.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../data/remote/firebase/app_services.dart';
import '../../data/remote/firebase/room_services.dart';
import '../../data/remote/firebase/profile_services.dart';
import '../../navigation/routes.dart';
import '../live_streaming/bottomsheets/profile_info_bottomsheet.dart';
import '../profile/profile_page.dart';
import 'bottomsheets/emoji_bottomsheet.dart';
import 'bottomsheets/gifts_bottomsheet.dart';
import 'bottomsheets/participants_bottomsheet.dart';
import 'bottomsheets/play_music_bottomsheet.dart';
import 'bottomsheets/requests_bottomsheet.dart';
import 'bottomsheets/audio_tools_bottomsheet.dart';
import 'bottomsheets/fans_ranking_bottomsheet.dart';

class CoHostRequest {
  final String requestId;
  final String userId;
  final String userName;
  final String? userPicture;

  CoHostRequest({
    required this.requestId,
    required this.userId,
    required this.userName,
    this.userPicture,
  });

  factory CoHostRequest.fromRTDB(String key, Map<dynamic, dynamic> data) {
    return CoHostRequest(
      requestId: key,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userPicture: data['userPicture'],
    );
  }
}

class SpeakerRequest {
  final String requestId;
  final String userId;
  final String userName;
  final String? userPicture;

  SpeakerRequest({
    required this.requestId,
    required this.userId,
    required this.userName,
    this.userPicture,
  });

  factory SpeakerRequest.fromRTDB(String key, Map<dynamic, dynamic> data) {
    return SpeakerRequest(
      requestId: key,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userPicture: data['userPicture'],
    );
  }
}

class RoomParticipant {
  final String userId;
  final String userName;
  final String? userPicture;
  final int seatNo;
  final bool isCoHost;
  final bool isMuted;
  final bool isLocked;
  final ZegoUIKitUser? zegoUser;

  RoomParticipant({
    required this.userId,
    required this.userName,
    this.userPicture,
    required this.seatNo,
    required this.isCoHost,
    required this.isMuted,
    this.isLocked = false,
    this.zegoUser,
  });

  factory RoomParticipant.fromRTDB(String key, Map<dynamic, dynamic> data) {
    return RoomParticipant(
      userId: data['userId'] ?? key,
      userName: data['userName'] ?? 'Unknown',
      userPicture: data.containsKey('userPicture') ? data['userPicture'] : null,
      seatNo: data['seatNo'] ?? -1,
      isCoHost: data['isCoHost'] ?? false,
      isMuted: data['isMuted'] ?? true,
      isLocked: data['isLocked'] ?? false,
    );
  }

  RoomParticipant copyWith({ZegoUIKitUser? zegoUser}) {
    return RoomParticipant(
      userId: userId,
      userName: userName,
      userPicture: userPicture,
      seatNo: seatNo,
      isCoHost: isCoHost,
      isMuted: isMuted,
      isLocked: isLocked,
      zegoUser: zegoUser ?? this.zegoUser,
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

class GiftNotification {
  final String senderName;
  final String recipientName;
  final String giftImageUrl;
  final int giftValue;
  final DateTime timestamp;

  GiftNotification({
    required this.senderName,
    required this.recipientName,
    required this.giftImageUrl,
    required this.giftValue,
    required this.timestamp,
  });
}

class GiftOverlay {
  final int? luckyHitCount;
  final String senderName;
  final String? senderPicture;
  final String giftImageUrl;
  final String? senderId;

  GiftOverlay({
    required this.senderName,
    this.senderPicture,
    required this.giftImageUrl,
    this.luckyHitCount,
    this.senderId,
  });
}

class AudioRoomPage extends StatefulWidget {
  final String roomID;
  final bool isHost;

  const AudioRoomPage({super.key, required this.roomID, required this.isHost});

  @override
  State<AudioRoomPage> createState() => _AudioRoomPageState();
}

class _AudioRoomPageState extends State<AudioRoomPage>
    with SingleTickerProviderStateMixin {
  late MusicPlayerManager _musicPlayerManager;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();
  bool _isChatExpanded = false;

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _roomSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _participantsSubscription;
  StreamSubscription? _speakerRequestsSubscription;
  StreamSubscription? _coHostRequestsSubscription;
  StreamSubscription? _emojiSubscription;
  StreamSubscription? _giftNotificationSubscription;

  final Map<String, Stream<int>> _diamondsStreamCache = {};

  // Cache to store user levels to avoid redundant Firestore reads while scrolling
  final Map<String, int> _userLevelCache = {};

  int _lastProcessedGiftTime = 0;

  late Map<String, dynamic> roomData;
  List<RoomParticipant> _participants = [];
  final List<ChatMessage> _messages = [];
  List<SpeakerRequest> _speakerRequests = [];
  List<CoHostRequest> _coHostRequests = [];
  int _participantCount = 0;
  bool _isInitialized = false;
  bool _isMoveAllowed = true;
  bool _isSeatApprovalRequired = true;
  bool _roomDoesNotExist = false;
  String _currentUserName = "Me";
  String _roomNotice = "";

  Duration welcomeTime = Duration(milliseconds: 3500);

  Timer? _joinAnimationTimer;
  String? _newJoinerName;

  EmojiEvent? _currentEmojiEvent;
  Timer? _emojiTimer;

  GiftOverlay? _currentGiftOverlay;
  Timer? _giftOverlayTimer;

  // --- Duration Timer Variables ---
  Timer? durationTimer;
  bool _isRoomEnded = false;
  final ValueNotifier<Duration> _currentDuration = ValueNotifier(Duration.zero);

  late AnimationController _joinAnimationController;
  late Animation<Offset> _joinAnimationOffset;

  String? _fullScreenGiftUrl;
  bool _isMinimizing = false;

  @override
  void initState() {
    super.initState();

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

    _chatFocusNode.addListener(_updateChatExpansion);
    _chatController.addListener(_updateChatExpansion);

    _musicPlayerManager = MusicPlayerManager();

    _initialize();
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
    _speakerRequestsSubscription?.cancel();
    _coHostRequestsSubscription?.cancel();
    _emojiSubscription?.cancel();
    _emojiTimer?.cancel();
    _giftNotificationSubscription?.cancel();

    _chatFocusNode.removeListener(_updateChatExpansion);
    _chatFocusNode.dispose();
    _chatController.removeListener(_updateChatExpansion);
    _chatController.dispose();
    _chatScrollController.dispose();
    _joinAnimationTimer?.cancel();

    durationTimer?.cancel();
    _currentDuration.dispose();

    _joinAnimationController.dispose();
    _musicPlayerManager.dispose();

    if (!_isMinimizing) {
      if (widget.isHost) {
        RoomService.deleteRoom(widget.roomID);
      } else {
        RoomService.leaveRoom(widget.roomID);
      }
      ZegoUIKit().leaveRoom();
      ZegoUIKit().logout();
      ZegoUIKit().uninit();
    }
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final roomDoc = await RoomService.getRoomInfo(widget.roomID);
      if (!roomDoc.exists) {
        if (mounted) {
          setState(() {
            _roomDoesNotExist = true;
          });
        }
        return;
      }
      roomData = Map<String, dynamic>.from(roomDoc.value as Map);
      _roomNotice = roomData['notice'] ?? "";

      final bool isLocked = roomData['isLocked'] ?? false;

      if (isLocked && !widget.isHost) {
        final bool? passwordCorrect = await _showPasswordDialog();
        if (passwordCorrect == true) {
          await _finishInitialization();
        }
      } else {
        await _finishInitialization();
      }
    } catch (e) {
      debugPrint('Error initializing audio room: $e');
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF2d1b2b),
            title: const Text(
              'Access Denied',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: Colors.pink)),
              ),
            ],
          ),
        );
        if (mounted) context.pop();
      }
    }
  }

  Future<void> _finishInitialization() async {
    if (!await _checkAudioPermissions()) {
      if (mounted) context.pop();
      return;
    }

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

    await ZegoUIKit().init(
      appID: await AppServices.getZegoAppId(),
      appSign: await AppServices.getZegoAppSign(),
      scenario: ZegoScenario.Default,
    );

    ZegoUIKit().login(currentUser.uid, _currentUserName);
    await ZegoUIKit().joinRoom(widget.roomID);

    ZegoUIKit().turnMicrophoneOn(widget.isHost);
    ZegoUIKit().setAudioOutputToSpeaker(true);
    ZegoUIKit().startPlayAllAudioVideo();

    if (!widget.isHost) {
      await RoomService.joinRoom(widget.roomID);
      _sendJoinMessage();
      _showJoinAnimation(_currentUserName);
    }

    _setupListeners();
    _musicPlayerManager.initialize();
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

  Future<bool?> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    final completer = Completer<bool?>();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        String? errorText;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF2d1b2b),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Password Required',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'This room is locked. Please enter the password to join.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Enter password",
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      errorText: errorText,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.pink),
                      ),
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    if (context.canPop()) context.pop();
                    completer.complete(false);
                  },
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Enter',
                    style: TextStyle(color: Colors.white),
                  ),
                  onPressed: () {
                    if (passwordController.text == roomData['password']) {
                      Navigator.of(dialogContext).pop();
                      completer.complete(true);
                    } else {
                      setState(
                        () =>
                            errorText = 'Incorrect password. Please try again.',
                      );
                      passwordController.clear();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    return completer.future;
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
    _roomSubscription = RoomService.getRoomStream(widget.roomID).listen((
      event,
    ) {
      if (event.snapshot.exists && mounted) {
        setState(() {
          roomData = Map<String, dynamic>.from(event.snapshot.value as Map);
          _participantCount = roomData['participantCount'] ?? 0;
          _isMoveAllowed = roomData['isMoveAllowed'] ?? true;
          _isSeatApprovalRequired = roomData['isSeatApprovalRequired'] ?? true;
          _roomNotice = roomData['notice'] ?? "";
        });

        if (widget.isHost && durationTimer == null) {
          startDurationTracking();
        }
      } else {
        if (mounted && !widget.isHost) {
          _handleRoomEnded();
        } else if (mounted && widget.isHost) {
          context.pop();
        }
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
              userId: message.user.id,
              username: message.user.name,
              message: message.message,
              timestamp: DateTime.now(),
            ),
          );
          _scrollToNewestMessage();
        });
      }
    });

    _participantsSubscription = RoomService.getRoomParticipants(widget.roomID)
        .listen((event) {
          if (!event.snapshot.exists) {
            if (mounted) setState(() => _participants = []);
            return;
          }

          final zegoUsers = ZegoUIKit().getAllUsers();
          final participantsMap = Map<dynamic, dynamic>.from(
            event.snapshot.value as Map,
          );

          final updatedParticipants = participantsMap.entries.map((entry) {
            final participant = RoomParticipant.fromRTDB(
              entry.key,
              entry.value,
            );
            try {
              final zegoUser = zegoUsers.firstWhere(
                (user) => user.id == participant.userId,
              );
              return participant.copyWith(zegoUser: zegoUser);
            } catch (e) {
              return participant;
            }
          }).toList();

          if (_participants.isNotEmpty && _newJoinerName == null) {
            final oldParticipantIds = _participants
                .map((p) => p.userId)
                .toSet();
            final String hostId = roomData['hostId'] ?? '';

            final newGuest = updatedParticipants.firstWhere(
              (p) =>
                  !oldParticipantIds.contains(p.userId) && p.userId != hostId,
              orElse: () => RoomParticipant(
                userId: '',
                userName: '',
                seatNo: -1,
                isCoHost: false,
                isMuted: true,
              ),
            );

            if (newGuest.userId.isNotEmpty) {
              _showJoinAnimation(newGuest.userName);
            }
          }

          if (mounted) {
            final currentUserId = _auth.currentUser!.uid;
            final oldCurrentUser = _participants.firstWhere(
              (p) => p.userId == currentUserId,
              orElse: () => RoomParticipant(
                userId: '',
                userName: '',
                seatNo: -1,
                isCoHost: false,
                isMuted: true,
              ),
            );
            final newCurrentUser = updatedParticipants.firstWhere(
              (p) => p.userId == currentUserId,
              orElse: () => RoomParticipant(
                userId: '',
                userName: '',
                seatNo: -1,
                isCoHost: false,
                isMuted: true,
              ),
            );

            if (newCurrentUser.userId.isEmpty && !widget.isHost) {
              // We were kicked!
              if (mounted) {
                _handleKicked();
              }
              return;
            }

            if (newCurrentUser.isMuted != oldCurrentUser.isMuted &&
                newCurrentUser.userId.isNotEmpty) {
              ZegoUIKit().turnMicrophoneOn(!newCurrentUser.isMuted);
            }
          }

          if (mounted) setState(() => _participants = updatedParticipants);
        });

    _emojiSubscription = RoomService.getEmojiStream(widget.roomID).listen((
      event,
    ) {
      if (!mounted || !event.snapshot.exists || event.snapshot.value == null)
        return;

      final data = event.snapshot.value as Map<dynamic, dynamic>;
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
    });

    // 2. This stream is the ONLY one that will handle gifts in the chat now.
    RoomService.getGiftStream(widget.roomID).listen((event) {
      if (!mounted || !event.snapshot.exists || event.snapshot.value == null)
        return;

      final data = event.snapshot.value as Map<dynamic, dynamic>;
      final timestamp = (data['timestamp'] as int?) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Prevent double-firing (local cache vs online update)
      // Ignores events that are within 1000ms of the last processed gift
      if (timestamp == 0 || (timestamp - _lastProcessedGiftTime).abs() < 600) {
        return;
      }
      _lastProcessedGiftTime = timestamp;

      if (now - timestamp < 5000) {
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
                giftValue: giftValue,
              ),
            );
          });
          _scrollToNewestMessage();
        }

        _showGiftOverlay(
          senderName: data['senderName'] ?? 'Unknown',
          senderPicture: data['senderPicture'],
          giftAnimationUrl: data['giftAnimationUrl'] ?? '',
          giftImageUrl: data['giftImageUrl'] ?? '',
          isLuckyGift: false,
          hitCount: hitCount,
          senderId: data['senderId'],
        );
      }
    });

    if (widget.isHost) {
      _speakerRequestsSubscription =
          RoomService.getSpeakerRequestsStream(widget.roomID).listen((event) {
            if (!event.snapshot.exists) {
              if (mounted) setState(() => _speakerRequests = []);
              return;
            }

            final requestsMap = Map<dynamic, dynamic>.from(
              event.snapshot.value as Map,
            );
            final requests = requestsMap.entries
                .map((entry) => SpeakerRequest.fromRTDB(entry.key, entry.value))
                .toList();

            if (mounted) setState(() => _speakerRequests = requests);
          });

      _coHostRequestsSubscription =
          RoomService.getCoHostRequestsStream(widget.roomID).listen((event) {
            if (!event.snapshot.exists) {
              if (mounted) setState(() => _coHostRequests = []);
              return;
            }

            final requestsMap = Map<dynamic, dynamic>.from(
              event.snapshot.value as Map,
            );
            final requests = requestsMap.entries
                .map((entry) => CoHostRequest.fromRTDB(entry.key, entry.value))
                .toList();

            if (mounted) setState(() => _coHostRequests = requests);
          });
    }
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

  void _showJoinAnimation(String userName) {
    _joinAnimationTimer?.cancel();
    _joinAnimationController.forward(from: 0.0);
    setState(() {
      _newJoinerName = userName;
    });
    _joinAnimationTimer = Timer(welcomeTime, () {
      setState(() {
        _newJoinerName = null;
      });
    });
  }

  // Helper methods for emoji display on avatars
  bool _shouldShowEmoji(String userId) {
    return _currentEmojiEvent != null && _currentEmojiEvent!.senderId == userId;
  }

  Widget _buildEmojiOnAvatar(String userId, double size) {
    if (!_shouldShowEmoji(userId)) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle),
      child: GiftImageWidget(
        imageUrl: _currentEmojiEvent!.emojiUrl,
        fit: BoxFit.contain,
      ),
    );
  }

  Future<void> _showSetPasswordDialog() async {
    final passwordController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2d1b2b),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Set Room Password',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter new password",
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.pink),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Set Password',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () async {
                final password = passwordController.text.trim();
                if (password.isEmpty) return;

                Navigator.of(dialogContext).pop();
                try {
                  await RoomService.setOrChangeRoomPassword(
                    widget.roomID,
                    password,
                  );
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Password has been set.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error setting password: $e')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPasswordManagementDialog() async {
    final bool isCurrentlyLocked = roomData['isLocked'] ?? false;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (isCurrentlyLocked) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: const Color(0xFF2d1b2b),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Manage Password',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'This room is currently password protected.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              child: const Text(
                'Remove Password',
                style: TextStyle(color: Colors.orangeAccent),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await RoomService.removeRoomPassword(widget.roomID);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Room is now public.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error removing password: $e')),
                  );
                }
              },
            ),
            TextButton(
              child: const Text(
                'Change Password',
                style: TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _showSetPasswordDialog();
              },
            ),
            TextButton(
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
      );
    } else {
      _showSetPasswordDialog();
    }
  }

  Future<bool> _checkAudioPermissions() async {
    PermissionStatus status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<bool?> _showLeaveSeatConfirmationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b2b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Seat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to leave your seat?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
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
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showExitConfirmationDialog() async {
    final currentUserId = _auth.currentUser!.uid;
    final myParticipant = _participants.firstWhere(
      (p) => p.userId == currentUserId,
      orElse: () => RoomParticipant(
        userId: '',
        userName: '',
        seatNo: -1,
        isCoHost: false,
        isMuted: true,
      ),
    );

    if (myParticipant.isLocked && !widget.isHost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You are locked and cannot exit the room.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

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
                        isAudioRoom: true,
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
      child: _isRoomEnded
          ? const Scaffold(backgroundColor: Colors.black)
          : Scaffold(
              resizeToAvoidBottomInset: false,
              body: StreamBuilder<DatabaseEvent>(
                stream: RoomService.getRoomStream(widget.roomID),
                builder: (context, snapshot) {
                  String? backgroundUrl;
                  if (snapshot.hasData && snapshot.data!.snapshot.exists) {
                    final data =
                        snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                    backgroundUrl = data['backgroundUrl'] as String?;
                  }

                  return Stack(
                    children: [
                      // Solid Background Color
                      Positioned.fill(
                        child: Container(color: const Color(0xFF2d1b2b)),
                      ),

                      SafeArea(
                        child: _isInitialized
                            ? Stack(
                                children: [
                                  Stack(
                                    children: [
                                      Column(
                                        children: [
                                          _buildAppBar(),
                                          _buildHostStatsRow(),
                                          Column(
                                            children: [
                                              _buildStreamerProfile(),
                                              _buildSeatsGrid(),
                                            ],
                                          ),
                                          Expanded(
                                            child: Container(
                                              margin: EdgeInsets.only(
                                                bottom: 60,
                                              ),
                                              child: Stack(
                                                children: [
                                                  _buildChatSection(),
                                                  _buildJoinCallOverlay(),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: _buildChatInput(),
                                      ),
                                    ],
                                  ),
                                  Center(child: _buildJoinAnimationOverlay()),
                                  _buildFullScreenGift(),
                                  _buildGiftOverlay(),
                                ],
                              )
                            : const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.pink,
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
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

  Widget _buildAppBar() {
    final String hostId = roomData['hostId'] ?? '';
    final String currentUserId = _auth.currentUser?.uid ?? '';
    final bool isGuest = !widget.isHost && hostId != currentUserId;

    final guestParticipants = _participants
        .where((p) => p.userId != hostId)
        .toList();

    return Padding(
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
                              AutoScrollText(
                                alignment: Alignment.centerLeft,
                                text: roomData["hostName"] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              StreamBuilder<DocumentSnapshot>(
                                stream: ProfileService.getUserProfileStream(
                                  hostId,
                                ),
                                builder: (context, snapshot) {
                                  String id = '';
                                  if (snapshot.hasData &&
                                      snapshot.data!.exists) {
                                    final data =
                                        snapshot.data!.data()
                                            as Map<String, dynamic>;
                                    id = data['displayId'] ?? "";
                                  }
                                  return Text(
                                    'ID: $id',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.7,
                                      ),
                                      fontSize: 10,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        // Follow Button - INSIDE CAPSULE
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
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    width: 24,
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

          // Participant Avatars
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
              showParticipantsBottomSheet(
                context,
                participants: _participants,
                currentUserId: _auth.currentUser!.uid,
                hostId: roomData['hostId'],
                roomId: widget.roomID,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

          GestureDetector(
            onTap: _showExitConfirmationDialog,
            child: Container(
              margin: const EdgeInsets.only(left: 6, right: 12),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 22,
                color: Colors.red,
              ),
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
              () => ProfileService.getUserDiamondsStream(hostId),
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
                  showFansRankingBottomSheet(context, hostId);
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

  Widget _buildParticipantAvatars(List<RoomParticipant> participants) {
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

  Widget _buildStreamerProfile() {
    RoomParticipant? host;
    try {
      host = _participants.firstWhere((p) => p.userId == roomData['hostId']);
    } catch (e) {
      host = null;
    }

    // Helper function to build the seat UI (Unchanged)
    Widget buildStreamerSeat({
      required String? imageUrl,
      required String name,
      required bool isMuted,
      required String userId,
      bool isHost = true,
    }) {
      final double size = 65.0;
      return Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.pink.shade300,
                            Colors.pink.shade500,
                            Colors.purple.shade400,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.pink.withValues(alpha: 0.4),
                            blurRadius: 25,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(3),
                      child: ClipOval(
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 40,
                              ),
                      ),
                    ),
                    Positioned(
                      width: size * 1.3,
                      height: size * 1.3,
                      child: IgnorePointer(
                        child: ActiveFrameWidget(
                          userId: userId,
                          size: size * 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isMuted)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.mic_off,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              _buildEmojiOnAvatar(userId, size),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: AutoScrollText(
              text: name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isHost ? Colors.pink : Colors.white,
                fontWeight: isHost ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
        ],
      );
    }

    RoomParticipant? coHost;
    try {
      coHost = _participants.firstWhere(
        (p) => p.isCoHost && p.userId != roomData['hostId'],
      );
    } catch (e) {
      coHost = null;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: 120, // Enough height for the avatars and names
        width: double.infinity,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Host Seat (Centered)
            GestureDetector(
              onTap: roomData['hostId'] == _auth.currentUser!.uid
                  ? null
                  : () {
                      showProfileInfoBottomSheet(
                        context,
                        userId: roomData['hostId'],
                        hostId: roomData['hostId'],
                        roomId: widget.roomID,
                      );
                    },
              child: buildStreamerSeat(
                imageUrl: roomData['hostPicture'],
                name: roomData['hostName'],
                isMuted: host?.isMuted ?? true,
                userId: roomData['hostId'],
                isHost: true,
              ),
            ),
            // Co-Host Seat
            Positioned(
              right: MediaQuery.of(context).size.width * 0.18,
              top: 5,
              child: GestureDetector(
                onTap: coHost == null
                    ? null
                    : () {
                        showProfileInfoBottomSheet(
                          context,
                          userId: coHost!.userId,
                          hostId: roomData['hostId'],
                          roomId: widget.roomID,
                          isSeated: true,
                          isCoHost: true,
                        );
                      },
                child: Column(
                  children: [
                    coHost != null
                        ? Transform.scale(
                            scale: 0.8, // Slightly smaller than host
                            child: buildStreamerSeat(
                              imageUrl: coHost.userPicture,
                              name: coHost.userName,
                              isMuted: coHost.isMuted,
                              userId: coHost.userId,
                              isHost: false,
                            ),
                          )
                        : Column(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.event_seat,
                                  color: Colors.white70,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Co-Host",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatsGrid() {
    const int seatCount = 8;
    final String currentUserId = _auth.currentUser!.uid;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 1,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
      ),
      itemCount: seatCount,
      itemBuilder: (context, index) {
        final seatNo = index + 1;
        RoomParticipant? participantOnSeat;
        try {
          participantOnSeat = _participants.firstWhere(
            (p) => p.seatNo == seatNo,
          );
        } catch (e) {
          participantOnSeat = null;
        }

        if (participantOnSeat != null) {
          return _buildOccupiedSeat(
            participantOnSeat,
            isCurrentUser: participantOnSeat.userId == currentUserId,
          );
        } else {
          return _buildEmptySeat(seatNo);
        }
      },
    );
  }

  Widget _buildEmptySeat(int seatNo) {
    final currentUser = _auth.currentUser!;
    RoomParticipant? currentUserParticipant;
    try {
      currentUserParticipant = _participants.firstWhere(
        (p) => p.userId == currentUser.uid,
      );
    } catch (e) {
      currentUserParticipant = null;
    }

    final lockedData = roomData['lockedSeats'];
    bool isLocked = false;
    if (lockedData is Map) {
      isLocked = lockedData['seat_$seatNo'] == true ||
          lockedData[seatNo.toString()] == true;
    } else if (lockedData is List) {
      if (seatNo < lockedData.length) {
        isLocked = lockedData[seatNo] == true;
      }
    }

    final bool canInteract = widget.isHost || (currentUserParticipant != null);
    final bool isListener = canInteract &&
        !widget.isHost &&
        currentUserParticipant?.seatNo == -1 &&
        currentUserParticipant?.isCoHost == false;
    final bool isSpeakerOrCoHost = canInteract &&
        !widget.isHost &&
        ((currentUserParticipant?.seatNo ?? -1) > 0 ||
            (currentUserParticipant?.isCoHost ?? false));

    IconData icon = isLocked ? Icons.lock : Icons.event_seat;
    Color iconColor = isLocked ? Colors.redAccent : Colors.pink;

    return GestureDetector(
      onTap: () async {
        if (!canInteract) return;
        if (widget.isHost) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF2d1b2b),
              title: Text(
                isLocked ? 'Unlock Seat $seatNo?' : 'Lock Seat $seatNo?',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              content: Text(
                isLocked
                    ? 'Allow participants to sit on seat $seatNo.'
                    : 'Prevent participants from sitting on seat $seatNo.',
                style: const TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLocked ? Colors.green : Colors.red,
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    if (isLocked) {
                      await RoomService.unlockSeat(widget.roomID, seatNo);
                    } else {
                      await RoomService.lockSeat(widget.roomID, seatNo);
                    }
                  },
                  child: Text(
                    isLocked ? 'Unlock' : 'Lock',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
          return;
        }

        if (currentUserParticipant?.isLocked == true && !widget.isHost) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You are locked and cannot change seats.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (isLocked) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This seat is locked by the host.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        try {
          if (isListener) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please click the "Join Call" button to request a seat.'),
                  backgroundColor: Colors.pink,
                ),
              );
            }
          } else if (isSpeakerOrCoHost) {
            if (_isMoveAllowed) {
              await RoomService.moveSeat(widget.roomID, seatNo);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'The host has disabled moving between seats.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          }
        } catch (e) {
          debugPrint("Error with seat action: $e");
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
          }
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.pink.withValues(alpha: 0.3),
                width: 2,
              ),
              color: Colors.black.withValues(alpha: 0.3),
            ),

            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Icon(icon, color: iconColor, size: 28),
                if (!isLocked)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                          spreadRadius: 1,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$seatNo',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildOccupiedSeat(
    RoomParticipant participant, {
    required bool isCurrentUser,
  }) {
    final canLeaveSeat =
        isCurrentUser && !widget.isHost && !participant.isLocked;
    return GestureDetector(
      onTap: !canLeaveSeat
          ? () {
              showProfileInfoBottomSheet(
                context,
                userId: participant.userId,
                hostId: roomData['hostId'],
                roomId: widget.roomID,
                isSeated: true,
              );
            }
          : () async {
              // Show confirmation dialog before leaving as requested
              final bool? shouldLeave =
                  await _showLeaveSeatConfirmationDialog();
              if (shouldLeave == true) {
                try {
                  await RoomService.leaveSeat(widget.roomID);
                  ZegoUIKit().turnMicrophoneOn(false);
                } catch (e) {
                  debugPrint("Error leaving seat: $e");
                }
              }
            },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 55,
                height: 55,
                child: participant.zegoUser == null
                    ? _buildAvatar(participant)
                    : StreamBuilder<double>(
                        stream: participant.zegoUser!.soundLevel,
                        builder: (context, snapshot) {
                          final isSpeaking = (snapshot.data ?? 0) > 10;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              _buildAvatar(participant, isSpeaking: isSpeaking),
                              if (isSpeaking)
                                Transform.scale(
                                  scale: 1.35,
                                  child: SVGAEasyPlayer(
                                    assetsName: "assets/svga/talking.svga",
                                    fit: BoxFit.cover,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
              Positioned(
                width: 71.5, // 55 * 1.3
                height: 71.5,
                child: IgnorePointer(
                  child: ActiveFrameWidget(
                    userId: participant.userId,
                    size: 71.5,
                  ),
                ),
              ),
              if (participant.isMuted)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.mic_off,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              _buildEmojiOnAvatar(participant.userId, 55),
            ],
          ),

          const SizedBox(height: 2),

          SizedBox(
            width: 70,
            child: AutoScrollText(
              text: participant.userName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),

          StreamBuilder<DocumentSnapshot>(
            stream: ProfileService.getUserProfileStream(participant.userId),
            builder: (context, snapshot) {
              int diamonds = 0;
              if (snapshot.hasData && snapshot.data!.exists) {
                final data = snapshot.data!.data() as Map<String, dynamic>;
                diamonds = data['diamonds'] ?? 0;
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.diamond_outlined,
                    color: Colors.cyan,
                    size: 10,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    formatViewCount(diamonds),
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(RoomParticipant participant, {bool isSpeaking = false}) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.pink.withValues(alpha: isSpeaking ? 0.8 : 0.4),
          width: 2,
        ),
      ),
      child: ClipOval(
        child:
            participant.userPicture != null &&
                participant.userPicture!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: participant.userPicture!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    _defaultAvatarContent(participant.userName),
              )
            : _defaultAvatarContent(participant.userName),
      ),
    );
  }

  Widget _defaultAvatarContent(String name) {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: Center(
        child: Text(
          name.isNotEmpty ? name.characters.first.toUpperCase() : "?",
          style: const TextStyle(color: Colors.white, fontSize: 20),
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
    final String currentUserId = _auth.currentUser!.uid;
    RoomParticipant? currentUserParticipant;
    try {
      currentUserParticipant = _participants.firstWhere(
        (p) => p.userId == currentUserId,
      );
    } catch (e) {
      currentUserParticipant = null;
    }
    final bool isListener =
        !widget.isHost &&
        (currentUserParticipant == null ||
            (currentUserParticipant.seatNo == -1 &&
                !currentUserParticipant.isCoHost));

    return Visibility(
      visible: isListener,
      child: Positioned(
        bottom: 8,
        right: 24,
        child: GestureDetector(
          onTap: () async {
            try {
              await RoomService.requestToBeSpeaker(widget.roomID);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Request sent. Please wait for host approval.',
                    ),
                    backgroundColor: Colors.pink,
                  ),
                );
              }
            } catch (e) {
              debugPrint("Error requesting to be speaker: $e");
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              // Matching the border radius of the image clip
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.pink, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/images/join_call.jpeg', // Replace with your actual path
                width: 48, // Adjust size as needed
                height: 48,
                fit: BoxFit.cover,
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
    return ListView.builder(
      reverse: true,
      controller: _chatScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      itemCount: _messages.length + 1,
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 250,
                  child: Text(
                    'Any sexual or violation content is strictly prohibited. All violator will be banned. Do not expose your personal info such phone or location.',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                    maxLines: 3,
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

        // Check if it's a gift message
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
                  // Diamond icon
                  const Icon(Icons.diamond, color: Colors.cyan, size: 16),
                  const SizedBox(width: 6),
                  // Gift message in accent color with both names highlighted
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

        // Regular chat message (Updated with Dynamic Level Badge)
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
                  children: [
                    _buildLevelBadge(m.userId),
                    SizedBox(
                      width: 120,
                      child: Text(
                        m.username,
                        style: TextStyle(
                          color: Colors.pink.shade300,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 0, top: 2),
                child: Text(
                  m.message,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatInput() {
    final String currentUserId = _auth.currentUser!.uid;
    RoomParticipant? currentUserParticipant;
    try {
      currentUserParticipant = _participants.firstWhere(
        (p) => p.userId == currentUserId,
      );
    } catch (e) {
      currentUserParticipant = null;
    }

    final bool isSpeakerOrCoHost = widget.isHost ||
        (currentUserParticipant != null &&
            (currentUserParticipant.seatNo > 0 ||
                currentUserParticipant.isCoHost));

    final bool isCurrentlyMuted = currentUserParticipant?.isMuted ?? true;
    final int totalRequests = _coHostRequests.length + _speakerRequests.length;

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!_isChatExpanded) ...[
            Padding(
              padding: const EdgeInsets.only(right: paddingRight),
              child: GestureDetector(
                onTap: () {
                  showAudioToolsBottomSheet(
                    context,
                    isHost: widget.isHost,
                    musicManager: _musicPlayerManager,
                    currentRoomId: widget.roomID,
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
                  showGiftBottomSheet(
                    context,
                    roomId: widget.roomID,
                    participants: _participants,
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
            if (isSpeakerOrCoHost)
              Padding(
                padding: const EdgeInsets.only(right: paddingRight),
                child: GestureDetector(
                  onTap: () {
                    FocusManager.instance.primaryFocus?.unfocus();
                    showEmojiBottomSheet(context, widget.roomID);
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
            if (isSpeakerOrCoHost)
              Padding(
                padding: const EdgeInsets.only(right: paddingRight),
                child: GestureDetector(
                  onTap: () {
                    final newMuteState = !isCurrentlyMuted;
                    RoomService.toggleMuteState(widget.roomID, newMuteState);
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
            if (widget.isHost)
              Padding(
                padding: const EdgeInsets.only(right: paddingRight),
                child: GestureDetector(
                  onTap: () => showAllRequestsBottomSheet(
                    context,
                    coHostRequests: _coHostRequests,
                    speakerRequests: _speakerRequests,
                    roomID: widget.roomID,
                    isMoveAllowed: _isMoveAllowed,
                    isSeatApprovalRequired: _isSeatApprovalRequired,
                  ),
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
                          Icons.call,
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
        _scrollToNewestMessage();
      }
    } catch (e) {
      debugPrint('Error sending join message: $e');
    }
  }

  void _scrollToNewestMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.jumpTo(0.0);
      }
    });
  }

  void _handleRoomEnded() {
    if (_isRoomEnded || !mounted) return;

    // Immediately stop streaming
    ZegoUIKit().leaveRoom();
    ZegoUIKit().logout();

    setState(() {
      _isRoomEnded = true;
      _isInitialized = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b2b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Live Ended',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'The host has ended the live stream.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.pop();
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.pink, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _handleKicked() {
    if (_isRoomEnded || !mounted) return;

    // Immediately stop streaming
    ZegoUIKit().leaveRoom();
    ZegoUIKit().logout();

    setState(() {
      _isRoomEnded = true;
      _isInitialized = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b2b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Removed',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have been removed from the room by the host.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.pop();
            },
            child: const Text(
              'OK',
              style: TextStyle(color: Colors.pink, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
