import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:picture_live/core/services/streaming_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/cubits/app_cubit.dart';

import '../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../core/widgets/GiftImageWidget.dart';
import '../../core/widgets/auto_scroll_text.dart';
import '../../core/widgets/network_svga_player.dart';
import '../../data/remote/firebase/room_services.dart';
import '../../data/remote/firebase/profile_services.dart';
import '../../core/widgets/vip_avatar_widget.dart';
import '../../core/services/vip_service.dart';
import '../../navigation/routes.dart';
import '../live_streaming/widgets/floating_youtube_player.dart';
import '../live_streaming/bottomsheets/profile_info_bottomsheet.dart';
import '../profile/profile_page.dart';
import 'bottomsheets/gifts_bottomsheet.dart';
import 'bottomsheets/participants_bottomsheet.dart';
import 'bottomsheets/play_music_bottomsheet.dart';
import 'bottomsheets/requests_bottomsheet.dart';
import 'bottomsheets/audio_tools_bottomsheet.dart';

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
  final int? coHostUntil;
  final bool isApprovedSpeaker;
  final int roomCoins;
  final bool isAdmin;
  final bool isChatMuted;
  final String displayId;
  final bool isModerator;
  final String? idEntryUrl;
  final String? vipType;

  RoomParticipant({
    required this.userId,
    required this.userName,
    this.userPicture,
    required this.displayId,
    required this.seatNo,
    required this.isCoHost,
    required this.isMuted,
    this.isLocked = false,
    this.coHostUntil,
    this.isApprovedSpeaker = false,
    this.roomCoins = 0,
    this.isAdmin = false,
    this.isChatMuted = false,
    this.isModerator = false,
    this.idEntryUrl,
    this.vipType,
  });

  factory RoomParticipant.fromRTDB(String key, Map<dynamic, dynamic> data) {
    return RoomParticipant(
      userId: data['userId'] ?? key,
      displayId: data['displayId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userPicture: data.containsKey('userPicture') ? data['userPicture'] : null,
      seatNo: data['seatNo'] ?? -1,
      isCoHost: data['isCoHost'] ?? false,
      isMuted: data['isMuted'] ?? true,
      isLocked: data['isLocked'] ?? false,
      coHostUntil: data['coHostUntil'] as int?,
      isApprovedSpeaker: data['isApprovedSpeaker'] ?? false,
      roomCoins: (data['roomCoins'] as num?)?.toInt() ?? 0,
      isAdmin: data['isAdmin'] ?? false,
      isChatMuted: data['isChatMuted'] ?? false,
      isModerator: data['isModerator'] == true || data['isStealth'] == true,
      idEntryUrl: data['idEntryUrl'] as String?,
      vipType: (data['vipType'] as String?) ??
          (data['vip'] is String ? data['vip'] as String : null) ??
          (data['isVvip'] == true ? 'vvip' : (data['isVip'] == true ? 'vip' : null)),
    );
  }

  RoomParticipant copyWith({
    int? coHostUntil,
    bool? isApprovedSpeaker,
    int? roomCoins,
    bool? isAdmin,
    bool? isChatMuted,
    bool? isModerator,
    String? idEntryUrl,
  }) {
    return RoomParticipant(
      userId: userId,
      displayId: displayId,
      userName: userName,
      userPicture: userPicture,
      seatNo: seatNo,
      isCoHost: isCoHost,
      isMuted: isMuted,
      isLocked: isLocked,
      coHostUntil: coHostUntil ?? this.coHostUntil,
      isApprovedSpeaker: isApprovedSpeaker ?? this.isApprovedSpeaker,
      roomCoins: roomCoins ?? this.roomCoins,
      isAdmin: isAdmin ?? this.isAdmin,
      isChatMuted: isChatMuted ?? this.isChatMuted,
      isModerator: isModerator ?? this.isModerator,
      idEntryUrl: idEntryUrl ?? this.idEntryUrl,
    );
  }
}

class ChatMessage {
  final String? id;
  final String userId;
  final String username;
  final String message;
  final DateTime timestamp;
  final bool isGiftMessage;
  final int? giftValue;
  final bool isJoinMessage;

  ChatMessage({
    this.id,
    required this.userId,
    required this.username,
    required this.message,
    required this.timestamp,
    this.isGiftMessage = false,
    this.giftValue,
    this.isJoinMessage = false,
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
  static String? currentRoomId;

  const AudioRoomPage({super.key, required this.roomID, required this.isHost});

  @override
  State<AudioRoomPage> createState() => _AudioRoomPageState();
}

class _AudioRoomPageState extends State<AudioRoomPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late MusicPlayerManager _musicPlayerManager;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();
  bool _isChatExpanded = false;
  bool _isCommentsHidden = false;
  final List<FloatingEmoji> _floatingEmojis = [];
  bool? _localMuteOverride;

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  StreamSubscription? _roomSubscription;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _participantsSubscription;
  StreamSubscription? _speakerRequestsSubscription;
  StreamSubscription? _coHostRequestsSubscription;
  StreamSubscription? _emojiSubscription;
  StreamSubscription? _giftNotificationSubscription;
  StreamSubscription? _callInviteSubscription;
  bool _isCallInviteDialogShowing = false;

  final Map<String, Stream<int>> _balanceStreamCache = {};

  // Cache to store user levels to avoid redundant Firestore reads while scrolling
  final Map<String, int> _userLevelCache = {};
  final Map<String, String> _userPictureCache = {};

  int _lastProcessedGiftTime = 0;

  Map<String, dynamic> roomData = {};
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
  bool _isCurrentModerator = false;

  Duration welcomeTime = Duration(milliseconds: 3500);

  Timer? _joinAnimationTimer;
  String? _newJoinerName;
  String? _newJoinerIdEntryUrl;

  Timer? _leavePopupTimer;
  String? _leaverName;
  String? _leaverId;

  EmojiEvent? _currentEmojiEvent;
  Timer? _emojiTimer;

  GiftOverlay? _currentGiftOverlay;
  Timer? _giftOverlayTimer;
  Timer? _coHostElapsedTimer;

  // --- Duration Timer Variables ---
  Timer? durationTimer;
  bool _isRoomEnded = false;
  final ValueNotifier<Duration> _currentDuration = ValueNotifier(Duration.zero);

  late AnimationController _joinAnimationController;
  late Animation<Offset> _joinAnimationOffset;

  String? _fullScreenGiftUrl;
  int? _fullScreenGiftDuration;
  bool _isMinimizing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AudioRoomPage.currentRoomId = widget.roomID;

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

    // Initialize chat stream and restore previous comments from history
    _initChat();

    _musicPlayerManager = MusicPlayerManager();

    _initialize();
  }

  void _initChat() {
    // 1. Immediately restore messages from StreamingService history if available
    _syncMessagesFromHistory();

    // 2. Set up listener for real-time messages from stream
    _messageSubscription?.cancel();
    _messageSubscription = StreamingService.instance.chatMessagesStream.listen((message) {
      if (!mounted) return;
      _addChatMessageToUI(
        ChatMessage(
          id: message.id,
          userId: message.userId,
          username: message.userName,
          message: message.message,
          timestamp: message.timestamp,
          isGiftMessage: message.isGiftMessage,
          giftValue: message.giftValue,
          isJoinMessage: message.isJoinMessage,
        ),
      );
    });

    // 3. Query Firebase Realtime Database in background to ensure all previous comments are loaded
    StreamingService.instance
        .fetchPastComments(widget.roomID, isVideo: false)
        .then((_) {
      if (mounted) {
        _syncMessagesFromHistory();
      }
    });
  }

  void _syncMessagesFromHistory() {
    final history = StreamingService.instance.messageHistory;
    if (history.isEmpty) return;

    bool hasNew = false;
    for (final m in history) {
      final bool alreadyExists = _messages.any((existing) =>
          (existing.id != null && m.id.isNotEmpty && existing.id == m.id) ||
          (existing.userId == m.userId &&
              existing.message == m.message &&
              existing.timestamp.difference(m.timestamp).abs().inSeconds < 4));

      if (!alreadyExists) {
        _messages.add(
          ChatMessage(
            id: m.id,
            userId: m.userId,
            username: m.userName,
            message: m.message,
            timestamp: m.timestamp,
            isGiftMessage: m.isGiftMessage,
            giftValue: m.giftValue,
            isJoinMessage: m.isJoinMessage,
          ),
        );
        hasNew = true;
      }
    }

    if (hasNew) {
      // Sort descending (newest at index 0) for reverse ListView
      _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) {
        setState(() {});
        _scrollToNewestMessage();
      }
    }
  }

  void _addChatMessageToUI(ChatMessage newMsg) {
    final bool alreadyExists = _messages.any((m) =>
        (m.id != null && newMsg.id != null && m.id == newMsg.id) ||
        (m.userId == newMsg.userId &&
            m.message == newMsg.message &&
            m.timestamp.difference(newMsg.timestamp).abs().inSeconds < 4));

    if (!alreadyExists) {
      setState(() {
        _messages.insert(0, newMsg);
      });
      _scrollToNewestMessage();
    }
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
    if (AudioRoomPage.currentRoomId == widget.roomID) {
      AudioRoomPage.currentRoomId = null;
    }
    _roomSubscription?.cancel();
    _messageSubscription?.cancel();
    _participantsSubscription?.cancel();
    _speakerRequestsSubscription?.cancel();
    _coHostRequestsSubscription?.cancel();
    _emojiSubscription?.cancel();
    _emojiTimer?.cancel();
    _coHostElapsedTimer?.cancel();
    _giftNotificationSubscription?.cancel();
    _callInviteSubscription?.cancel();
    WakelockPlus.disable();

    _chatFocusNode.removeListener(_updateChatExpansion);
    _chatFocusNode.dispose();
    _chatController.removeListener(_updateChatExpansion);
    _chatController.dispose();
    _chatScrollController.dispose();
    _joinAnimationTimer?.cancel();

    durationTimer?.cancel();
    _currentDuration.dispose();

    WidgetsBinding.instance.removeObserver(this);

    _joinAnimationController.dispose();
    _musicPlayerManager.dispose();

    final bool isMinimizingNow = _isMinimizing;

    if (!isMinimizingNow) {
      try {
        context.read<AppCubit>().closeMinimizedRoom();
      } catch (_) {}
      if (widget.isHost) {
        RoomService.deleteRoom(widget.roomID);
      } else {
        RoomService.leaveRoom(widget.roomID);
      }
      StreamingService.instance.disconnect();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      RoomService.pausePresence(widget.roomID, widget.isHost);
    } else if (state == AppLifecycleState.resumed) {
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        RoomService.resumePresence(widget.roomID, uid, isHost: widget.isHost);
      }
    }
  }

  Future<void> _initialize() async {
    WakelockPlus.enable();
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
      final String? password = roomData['password']?.toString();

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        _isCurrentModerator = await ProfileService.isUserModerator(currentUser.uid);
      }

      if (isLocked && !widget.isHost && !_isCurrentModerator) {
        if (password != null && password.isNotEmpty) {
          final bool? passwordCorrect = await _showPasswordDialog();
          if (passwordCorrect == true) {
            await _finishInitialization();
          } else {
            if (mounted) context.pop();
          }
        } else {
          // Direct room lock without password
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Room is lock',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
            context.pop();
          }
          return;
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

    final bool isResuming = (StreamingService.instance.currentRoomName == widget.roomID);

    await StreamingService.instance.connectRoom(
      roomName: widget.roomID,
      userId: currentUser.uid,
      userName: _currentUserName,
      role: widget.isHost ? 'HOST' : 'PARTICIPANT',
      isVideo: false,
      isHost: widget.isHost,
    );
    _syncMessagesFromHistory();

    if (!widget.isHost) {
      await RoomService.joinRoom(widget.roomID);
      if (!_isCurrentModerator && !isResuming) {
        _sendJoinMessage();
        
        final userDoc = await ProfileService.getUserProfile(currentUser.uid);
        String? idEntryUrl;
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>;
          final addOns = data['activeAddOns'] as Map<String, dynamic>? ?? {};
          final now = DateTime.now();
          
          Map<String, dynamic>? idEntryData;
          for (var entry in addOns.entries) {
            final key = entry.key.toLowerCase().replaceAll(' ', '');
            if (key.contains('entry') || key.contains('ride') || key.contains('vehicle')) {
              idEntryData = entry.value as Map<String, dynamic>?;
              break;
            }
          }
          
          if (idEntryData != null) {
            final expiry = idEntryData['expiresAt'] as Timestamp?;
            if (expiry == null || expiry.toDate().isAfter(now)) {
              idEntryUrl = idEntryData['imageUrl'] as String?;
            }
          }
        }
        _showJoinAnimation(_currentUserName, idEntryUrl: idEntryUrl);
      }
    }

    _setupListeners();
    _musicPlayerManager.initialize(widget.roomID);

    if (widget.isHost) {
      try {
        final currentBg = roomData['backgroundUrl'] as String?;
        if (currentBg == null || currentBg.isEmpty) {
          final userDoc = await ProfileService.getUserProfile(currentUser.uid);
          if (userDoc.exists) {
            final uData = userDoc.data() as Map<String, dynamic>;
            String? activeBg;
            if (uData.containsKey('activeAddOns')) {
              final addOns = uData['activeAddOns'] as Map<String, dynamic>? ?? {};
              final now = DateTime.now();
              for (var entry in addOns.entries) {
                final cat = entry.key.toLowerCase().trim();
                if (cat.contains('screen') || cat.contains('skin')) {
                  final itemData = entry.value as Map<String, dynamic>?;
                  if (itemData != null) {
                    final expiry = itemData['expiresAt'] as Timestamp?;
                    if (expiry == null || expiry.toDate().isAfter(now)) {
                      final url = itemData['imageUrl'] as String?;
                      if (url != null && url.isNotEmpty) {
                        activeBg = url;
                        break;
                      }
                    }
                  }
                }
              }
            }
            if (activeBg == null || activeBg.isEmpty) {
              activeBg = uData['preferredRoomSkin'] as String?;
            }
            if (activeBg != null && activeBg.isNotEmpty) {
              await RoomService.updateRoomBackground(widget.roomID, activeBg);
            }
          }
        }
      } catch (e) {
        debugPrint("Error syncing room screen on init: $e");
      }
    }

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
    int? durationSec,
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
        _fullScreenGiftDuration = durationSec;
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
        if (mounted) {
          _handleRoomEnded();
        }
      }
    });

    _syncMessagesFromHistory();

    StreamingService.instance.dataMessagesStream.listen((data) {
      if (!mounted) return;
      if (data['type'] == 'emoji') {
        final senderId = data['userId'] as String? ?? '';
        if (senderId == _auth.currentUser?.uid) return;
        final emoji = data['emoji'] as String? ?? '';
        if (emoji.isNotEmpty) {
          _showFloatingEmoji(emoji, senderName: data['userName'] as String?);
        }
      }
    });

    _participantsSubscription = RoomService.getRoomParticipants(widget.roomID)
        .listen((event) {
          if (!event.snapshot.exists) {
            if (mounted) setState(() => _participants = []);
            return;
          }

          final participantsMap = Map<dynamic, dynamic>.from(
            event.snapshot.value as Map,
          );

          final updatedParticipants = participantsMap.entries.map((entry) {
            return RoomParticipant.fromRTDB(
              entry.key,
              entry.value,
            );
          }).toList();

          for (final p in updatedParticipants) {
            if (p.vipType != null && p.vipType!.isNotEmpty) {
              VipService.setVipType(p.userId, p.vipType);
            } else {
              VipService.getVipType(p.userId).then((res) {
                if (res != null && mounted) setState(() {});
              });
            }
          }

          if (_participants.isNotEmpty && _newJoinerName == null) {
            final oldParticipantIds = _participants
                .map((p) => p.userId)
                .toSet();
            final String hostId = roomData['hostId'] ?? '';

            final newGuest = updatedParticipants.firstWhere(
              (p) =>
                  !oldParticipantIds.contains(p.userId) &&
                  p.userId != hostId &&
                  !p.isModerator,
              orElse: () => RoomParticipant(
                userId: '',
                displayId: '',
                userName: '',
                seatNo: -1,
                isCoHost: false,
                isMuted: true,
              ),
            );

            if (newGuest.userId.isNotEmpty && !newGuest.isModerator) {
              final displayIdText = newGuest.displayId.isNotEmpty ? newGuest.displayId : newGuest.userId.substring(0, 6);
              _showJoinAnimation('${newGuest.userName} (ID: $displayIdText)', idEntryUrl: newGuest.idEntryUrl);
              
              if (mounted) {
                setState(() {
                  _messages.insert(
                    0,
                    ChatMessage(
                      userId: newGuest.userId,
                      username: '${newGuest.userName} (ID: $displayIdText)',
                      message: 'entered the live room',
                      timestamp: DateTime.now(),
                      isJoinMessage: true,
                    ),
                  );
                });
                _scrollToNewestMessage();
              }
            }
            
            final newParticipantIds = updatedParticipants.map((p) => p.userId).toSet();
            final leftGuest = _participants.firstWhere(
              (p) => !newParticipantIds.contains(p.userId) && p.userId != hostId,
              orElse: () => RoomParticipant(
                userId: '',
                displayId: '',
                userName: '',
                seatNo: -1,
                isCoHost: false,
                isMuted: true,
              ),
            );

            if (leftGuest.userId.isNotEmpty) {
              final displayIdText = leftGuest.displayId.isNotEmpty ? leftGuest.displayId : leftGuest.userId.substring(0, 6);
              if (mounted) {
                _showLeavePopup(leftGuest.userName, displayIdText);
              }
            }
          }

          if (mounted) {
            final currentUserId = _auth.currentUser!.uid;
            final oldCurrentUser = _participants.firstWhere(
              (p) => p.userId == currentUserId,
              orElse: () => RoomParticipant(
                userId: '',
                displayId: '',
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
                displayId: '',
                userName: '',
                seatNo: -1,
                isCoHost: false,
                isMuted: true,
              ),
            );

            final bool isMinimizingNow = _isMinimizing ||
                (mounted && context.read<AppCubit>().state.minimizedRoom?.roomId == widget.roomID);

            if (oldCurrentUser.userId.isNotEmpty && newCurrentUser.userId.isEmpty && !widget.isHost && !_isCurrentModerator && !isMinimizingNow && !_isRoomEnded) {
              // We were kicked!
              if (mounted) {
                _handleKicked();
              }
              return;
            }

            if (newCurrentUser.userId.isNotEmpty) {
              final bool canSpeak =
                  widget.isHost ||
                  newCurrentUser.isApprovedSpeaker ||
                  newCurrentUser.isCoHost ||
                  newCurrentUser.seatNo > 0;
              if (canSpeak) {
                if (newCurrentUser.isMuted != oldCurrentUser.isMuted || oldCurrentUser.seatNo != newCurrentUser.seatNo) {
                  StreamingService.instance.setMicrophoneEnabled(!newCurrentUser.isMuted);
                }
              } else {
                StreamingService.instance.setMicrophoneEnabled(false);
              }
            }
          }

          if (mounted) {
            setState(() {
              _participants = updatedParticipants;
              _localMuteOverride = null;
            });
            _updateCoHostElapsedTimer();
            if (widget.isHost) {
              final occupiedSeats = <int>{};
              final hasHidden = updatedParticipants.any(
                (p) =>
                    p.isApprovedSpeaker &&
                    p.seatNo == -1 &&
                    p.userId != _auth.currentUser?.uid,
              );
              for (var p in updatedParticipants) {
                if (p.seatNo > 0) {
                  occupiedSeats.add(p.seatNo);
                }
              }
              bool hasEmptySeat = false;
              for (int i = 1; i <= 15; i++) {
                if (!occupiedSeats.contains(i)) {
                  hasEmptySeat = true;
                  break;
                }
              }
              if (hasEmptySeat && hasHidden) {
                RoomService.promoteHiddenSpeakers(widget.roomID);
              }
            }
          }
        });

    _emojiSubscription = RoomService.getEmojiStream(widget.roomID).listen((
      event,
    ) {
      if (!mounted || !event.snapshot.exists || event.snapshot.value == null) {
        return;
      }

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
      if (!mounted || !event.snapshot.exists || event.snapshot.value == null) {
        return;
      }

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

            final giftChatMsg = ChatMessage(
              userId: data['senderId'] ?? '',
              username: senderName,
              message: giftMessageText,
              timestamp: DateTime.now(),
              isGiftMessage: true,
              giftValue: giftValue,
            );
            _messages.insert(0, giftChatMsg);
            StreamingService.instance.addChatMessage(
              StreamingChatMessage(
                id: 'gift_${DateTime.now().millisecondsSinceEpoch}_${data['senderId']}',
                userId: data['senderId'] ?? '',
                userName: senderName,
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
          durationSec: data['duration'] as int?,
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

            if (mounted) {
              final bool hasNewRequest =
                  requests.length > _speakerRequests.length;
              setState(() => _speakerRequests = requests);

              if (hasNewRequest) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('New seat request received!'),
                    backgroundColor: Colors.pink,
                    action: SnackBarAction(
                      label: 'View',
                      textColor: Colors.white,
                      onPressed: () {
                        showAllRequestsBottomSheet(
                          context,
                          coHostRequests: _coHostRequests,
                          speakerRequests: _speakerRequests,
                          roomID: widget.roomID,
                          isMoveAllowed: _isMoveAllowed,
                          isSeatApprovalRequired: _isSeatApprovalRequired,
                        );
                      },
                    ),
                  ),
                );
              }
            }
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

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null && !widget.isHost) {
      _callInviteSubscription =
          RoomService.getCallInviteStream(widget.roomID, currentUserId).listen((event) {
            if (!event.snapshot.exists || event.snapshot.value == null) return;
            final data = event.snapshot.value;
            if (data is Map) {
              final hostName = (data['hostName'] as String?) ?? 'Host';
              _showCallInviteDialog(hostName, currentUserId);
            }
          });
    }
  }

  void _showCallInviteDialog(String hostName, String myUserId) {
    if (_isCallInviteDialogShowing || !mounted) return;
    _isCallInviteDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1F1D2B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.phone_in_talk, color: Colors.greenAccent, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Seat Call Invitation',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          '$hostName invited you to take a seat on the call!',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              _isCallInviteDialogShowing = false;
              await RoomService.rejectCallInvite(widget.roomID, myUserId);
            },
            child: const Text('Decline', style: TextStyle(color: Colors.redAccent, fontSize: 15)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.mic, color: Colors.white, size: 18),
            label: const Text('Accept & Speak', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              _isCallInviteDialogShowing = false;
              try {
                await RoomService.acceptCallInvite(widget.roomID, myUserId);
                await StreamingService.instance.setMicrophoneEnabled(true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Joined seat call successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error joining seat: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
          ),
        ],
      ),
    ).then((_) {
      _isCallInviteDialogShowing = false;
    });
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

  void _showJoinAnimation(String userName, {String? idEntryUrl}) {
    _joinAnimationTimer?.cancel();
    _joinAnimationController.forward(from: 0.0);
    setState(() {
      _newJoinerName = userName;
      _newJoinerIdEntryUrl = idEntryUrl;
    });
    
    bool isSvga = idEntryUrl != null && idEntryUrl.toLowerCase().endsWith('.svga');
    if (!isSvga) {
      _joinAnimationTimer = Timer(welcomeTime, () {
        if (mounted) {
          setState(() {
            _newJoinerName = null;
            _newJoinerIdEntryUrl = null;
          });
        }
      });
    }
  }

  void _hideJoinAnimation() {
    if (mounted) {
      setState(() {
        _newJoinerName = null;
        _newJoinerIdEntryUrl = null;
      });
    }
  }

  void _showLeavePopup(String userName, String displayId) {
    _leavePopupTimer?.cancel();
    setState(() {
      _leaverName = userName;
      _leaverId = displayId;
    });
    _leavePopupTimer = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _leaverName = null;
          _leaverId = null;
        });
      }
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
        displayId: '',
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
                    Navigator.of(context).pop(false);
                    _exitAndEndAudioRoom();
                  },
                ),
                if (_isCurrentModerator) ...[
                  const SizedBox(height: 24),
                  _buildExitDialogOption(
                    icon: Icons.cancel_presentation_rounded,
                    color: Colors.red.shade900,
                    label: 'Close Room',
                    onTap: () {
                      Navigator.of(context).pop(false);
                      _showModeratorCloseDialog();
                    },
                  ),
                ],
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
        _exitAndEndAudioRoom();
      }
      return shouldExit;
    });
  }

  Future<void> _exitAndEndAudioRoom() async {
    _isMinimizing = false;
    _isRoomEnded = true;
    if (AudioRoomPage.currentRoomId == widget.roomID) {
      AudioRoomPage.currentRoomId = null;
    }

    try {
      if (mounted) {
        context.read<AppCubit>().closeMinimizedRoom();
      }
    } catch (_) {}

    try {
      if (widget.isHost) {
        await RoomService.deleteRoom(widget.roomID);
      } else {
        final uid = _auth.currentUser?.uid;
        if (uid != null) {
          try {
            await RoomService.leaveSeat(widget.roomID);
          } catch (_) {}
        }
        await RoomService.leaveRoom(widget.roomID);
      }
    } catch (e) {
      debugPrint("Error deleting/leaving audio room on exit: $e");
    }

    try {
      await StreamingService.instance.disconnect();
    } catch (e) {
      debugPrint("Error disconnecting streaming on exit: $e");
    }

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    if (mounted) {
      context.go(Routes.home.path);
    }
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

  Future<void> _showModeratorCloseDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b2b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('Close Audio Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'As a moderator, are you sure you want to force close this audio room? The room will be terminated for all participants and the host.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Close Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await RoomService.deleteRoom(widget.roomID);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio room closed by moderator.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          context.go(Routes.home.path);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error closing room: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
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
              backgroundColor: Colors.transparent,
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
                      // Base gradient background
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFF2E0442), Color(0xFF1F022D), Color(0xFF14011D)],
                            ),
                          ),
                        ),
                      ),
                      // Active Room Screen / Skin from host's ID
                      if (backgroundUrl != null && backgroundUrl.isNotEmpty)
                        Positioned.fill(
                          child: CachedNetworkImage(
                            imageUrl: backgroundUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const SizedBox.shrink(),
                            errorWidget: (context, url, error) => const SizedBox.shrink(),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
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
                                          _buildSeatsGrid(),
                                          Expanded(
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 60,
                                              ),
                                              child: Stack(
                                                children: [
                                                  _buildChatSection(),
                                                  _buildJoinCallOverlay(),
                                                  if (_isCommentsHidden) _buildShowCommentsButton(),
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
                                      _buildRightActionButtons(),
                                    ],
                                  ),
                                  Center(child: _buildJoinAnimationOverlay()),
                                  Center(child: _buildLeavePopupOverlay()),
                                   _buildFullScreenGift(),
                                   _buildGiftOverlay(),

                                   if (_isInitialized && !_isChatExpanded) _buildEmojiColumnOverlay(),
                                   if (_isInitialized) _buildFloatingEmojis(),
                                   if (_isInitialized) FloatingYoutubePlayer(roomId: widget.roomID, isHost: widget.isHost),
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
      child: IgnorePointer(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          margin: EdgeInsets.zero,
          color: Colors.transparent,
          child: SlideTransition(
            position: _joinAnimationOffset,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (_newJoinerIdEntryUrl != null && _newJoinerIdEntryUrl!.isNotEmpty)
                if (_newJoinerIdEntryUrl!.toLowerCase().endsWith('.svga'))
                  NetworkSVGAPlayer(
                    imageUrl: _newJoinerIdEntryUrl!,
                    fit: BoxFit.cover,
                    onFinished: _hideJoinAnimation,
                  )
                else
                  Image.network(
                    _newJoinerIdEntryUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Image.asset("assets/animations/id_entry.gif", fit: BoxFit.cover),
                  )
              else
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
      ),
    );
  }

  Widget _buildLeavePopupOverlay() {
    return AnimatedOpacity(
      opacity: _leaverName != null ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xCC1A0A0A),
                Color(0xCC2D1B2B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4081), Color(0xFFFF79A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF4081).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  CupertinoIcons.square_arrow_right,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  '${_leaverName ?? ''} (${_leaverId ?? ''}) left',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: 0.5,
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
        .where((p) => p.userId != hostId && !p.isModerator)
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
                        VipAvatarWidget(
                          userId: hostId,
                          userPicture: roomData['hostPicture'],
                          avatarSize: 32,
                          directVipType: roomData['vipType'] ?? roomData['vip'],
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
                              ValueListenableBuilder<Duration>(
                                valueListenable: _currentDuration,
                                builder: (context, duration, child) {
                                  final hours = duration.inHours.toString().padLeft(2, '0');
                                  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
                                  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
                                  return Text(
                                    '$hours:$minutes:$seconds',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
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
                              if (!snapshot.hasData) {
                                return const SizedBox.shrink();
                              }
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
            constraints: const BoxConstraints(maxWidth: 80),
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
                participants: _participants.where((p) => !p.isModerator && p.userId != hostId).toList(),
                currentUserId: _auth.currentUser!.uid,
                hostId: hostId,
                roomId: widget.roomID,
                isCurrentUserAdmin: _isCurrentModerator || _participants.firstWhere((p) => p.userId == _auth.currentUser!.uid, orElse: () => RoomParticipant(userId: '', displayId: '', userName: '', seatNo: -1, isCoHost: false, isMuted: false)).isAdmin,
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
                    (guestParticipants.isNotEmpty
                            ? guestParticipants.length
                            : (_participantCount > 1 ? _participantCount - 1 : 0))
                        .toString(),
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

          if (_isCurrentModerator) ...[
            GestureDetector(
              onTap: _showModeratorCloseDialog,
              child: Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.cancel_presentation_rounded,
                  size: 22,
                  color: Colors.redAccent,
                ),
              ),
            ),
          ],

          GestureDetector(
            onTap: _showExitConfirmationDialog,
            child: Container(
              margin: const EdgeInsets.only(left: 6, right: 10),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF23032F),
                border: Border.all(color: const Color(0xFFFF1744), width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF1744).withValues(alpha: 0.4),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(
                Icons.power_settings_new,
                size: 18,
                color: Color(0xFFFF1744),
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

  String formatViewCount(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  Widget _buildHostStatsRow() {
    return const SizedBox(height: 2);
  }

  Widget _buildParticipantAvatars(List<RoomParticipant> participants) {
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    const double avatarSize = 22.0;
    const double overlap = 16.0;

    final participantsToShow = participants.where((p) => !p.isModerator).take(4).toList();

    final double stackWidth =
        avatarSize + (participantsToShow.length - 1) * overlap;

    return SizedBox(
      width: stackWidth,
      height: avatarSize + 6,
      child: Stack(
        clipBehavior: Clip.none,
        children: participantsToShow
            .asMap()
            .entries
            .map((entry) {
              final index = entry.key;
              final participant = entry.value;
              final double leftPosition = index * overlap;

              return Positioned(
                left: leftPosition,
                top: 3,
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
                          border: Border.all(color: const Color(0xFFFFD700), width: 1),
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
                                  size: 11,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        top: -5,
                        child: Image.asset(
                          'assets/images/VIP PNG.png',
                          width: avatarSize * 1.1,
                          height: avatarSize * 1.1,
                          fit: BoxFit.contain,
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

  Widget _buildSeatsGrid() {
    final double screenWidth = MediaQuery.of(context).size.width;
    const double horizontalPadding = 10.0;
    final double availableWidth = screenWidth - (horizontalPadding * 2);
    const double spacing = 6.0;
    // 4 columns: 3 gaps of 6px = 18px
    final double colWidth = (availableWidth - (spacing * 3)) / 4;
    final double seatHeight = colWidth * 1.28;
    final double hostWidth = (colWidth * 2) + spacing;
    final double hostHeight = (seatHeight * 2) + spacing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 4.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top 2 Rows: Host (2x2 on left) + Guest Seats 2, 3, 4, 5 (2x2 on right)
          SizedBox(
            height: hostHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Host Card (Spans col 1-2, row 1-2)
                SizedBox(
                  width: hostWidth,
                  height: hostHeight,
                  child: _buildHostSeatCard(hostWidth, hostHeight),
                ),
                const SizedBox(width: spacing),
                // Right 2x2 for Seats 2, 3 (Row 1) and Seats 4, 5 (Row 2)
                SizedBox(
                  width: hostWidth,
                  height: hostHeight,
                  child: Column(
                    children: [
                      // Row 1: Seats 2 & 3
                      Row(
                        children: [
                          _buildSeatCard(seatNo: 2, width: colWidth, height: seatHeight),
                          const SizedBox(width: spacing),
                          _buildSeatCard(seatNo: 3, width: colWidth, height: seatHeight),
                        ],
                      ),
                      const SizedBox(height: spacing),
                      // Row 2: Seats 4 & 5
                      Row(
                        children: [
                          _buildSeatCard(seatNo: 4, width: colWidth, height: seatHeight),
                          const SizedBox(width: spacing),
                          _buildSeatCard(seatNo: 5, width: colWidth, height: seatHeight),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: spacing),
          // Bottom Row: Seats 6, 7, 8, 9 (Row 3 across all 4 columns)
          Row(
            children: [
              _buildSeatCard(seatNo: 6, width: colWidth, height: seatHeight),
              const SizedBox(width: spacing),
              _buildSeatCard(seatNo: 7, width: colWidth, height: seatHeight),
              const SizedBox(width: spacing),
              _buildSeatCard(seatNo: 8, width: colWidth, height: seatHeight),
              const SizedBox(width: spacing),
              _buildSeatCard(seatNo: 9, width: colWidth, height: seatHeight),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHostSeatCard(double width, double height) {
    final String hostId = roomData['hostId'] ?? '';
    final String hostName = roomData['hostName'] ?? 'Host';
    final String? hostPicture = roomData['hostPicture'];
    RoomParticipant? hostParticipant;
    try {
      hostParticipant = _participants.firstWhere((p) => p.userId == hostId);
    } catch (_) {
      hostParticipant = null;
    }
    final bool isMuted = hostParticipant?.isMuted ?? false;
    final double avatarSize = width * 0.44;
    final String? hostVip = (roomData['vipType'] as String?) ?? VipService.getVipTypeSync(hostId);
    final bool hasHostVip = hostVip != null && hostVip.isNotEmpty;
    final bool isHostVvip = hasHostVip && hostVip.toLowerCase().contains('vvip');

    return GestureDetector(
      onTap: () {
        showProfileInfoBottomSheet(
          context,
          userId: hostId,
          hostId: hostId,
          roomId: widget.roomID,
          isSeated: true,
          isCurrentUserAdmin: _participants.firstWhere(
            (p) => p.userId == _auth.currentUser!.uid,
            orElse: () => RoomParticipant(userId: '', displayId: '', userName: '', seatNo: -1, isCoHost: false, isMuted: false),
          ).isAdmin,
        );
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF28073D).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE91E63),
            width: 1.8,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE91E63).withValues(alpha: 0.25),
              blurRadius: 6,
              spreadRadius: 0.5,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Stack(
          children: [
            // Top Stats Strip: Host label, Diamonds, Stars, Viewers
            StreamBuilder<int>(
              stream: _balanceStreamCache.putIfAbsent(
                'diamonds_$hostId',
                () => ProfileService.getUserDiamondsStream(hostId),
              ),
              builder: (context, snapshot) {
                final int hostBalance = snapshot.data ?? 0;
                final int starLevel = hostBalance >= 100000 ? hostBalance ~/ 100000 : 1;
                final int viewerCount = _participantCount > 0 ? _participantCount : 1;

                return Row(
                  children: [
                    const Text(
                      'Host',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.diamond, color: Color(0xFF00E5FF), size: 12),
                    const SizedBox(width: 2),
                    Text(
                      formatViewCount(hostBalance),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.star, color: Colors.amber, size: 12),
                    const SizedBox(width: 1),
                    Text(
                      '$starLevel',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.remove_red_eye, color: Colors.white70, size: 12),
                    const SizedBox(width: 2),
                    Text(
                      '$viewerCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
            ),

            // Center Host Avatar
            Center(
              child: SizedBox(
                width: avatarSize * 1.5,
                height: avatarSize * 1.5,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    StreamBuilder<List<String>>(
                      stream: StreamingService.instance.activeSpeakersStream,
                      builder: (context, snapshot) {
                        final isSpeaking = !isMuted && (snapshot.data ?? []).contains(hostId);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: avatarSize,
                              height: avatarSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSpeaking ? const Color(0xFF00E5FF) : const Color(0xFFE91E63),
                                  width: 2.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isSpeaking ? const Color(0xFF00E5FF) : const Color(0xFFE91E63))
                                        .withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: hostPicture != null && hostPicture.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: hostPicture,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      )
                                    : const Icon(Icons.person, color: Colors.white, size: 32),
                              ),
                            ),
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

                    // VIP / VVIP Frame (Only if host has VIP) or Active Frame
                    if (hasHostVip)
                      Positioned(
                        top: (avatarSize - (avatarSize * 1.823)) / 2 - (avatarSize * 0.1644),
                        left: (avatarSize - (avatarSize * 1.823)) / 2,
                        width: avatarSize * 1.823,
                        height: avatarSize * 1.823,
                        child: IgnorePointer(
                          child: Image.asset(
                            isHostVvip ? 'assets/images/VVIP PNG.png' : 'assets/images/VIP PNG.png',
                            width: avatarSize * 1.823,
                            height: avatarSize * 1.823,
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    else
                      // Active Frame
                      Positioned(
                        width: avatarSize * 1.3,
                        height: avatarSize * 1.3,
                        child: IgnorePointer(
                          child: ActiveFrameWidget(userId: hostId, size: avatarSize * 1.3),
                        ),
                      ),

                    // Muted Indicator
                    if (isMuted)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.mic_off, color: Colors.white, size: 12),
                        ),
                      ),

                    _buildEmojiOnAvatar(hostId, avatarSize),
                  ],
                ),
              ),
            ),

            // Bottom Capsule Pill with Mini Avatar, Name, and Diamonds
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StreamBuilder<int>(
                stream: _balanceStreamCache.putIfAbsent(
                  'diamonds_$hostId',
                  () => ProfileService.getUserDiamondsStream(hostId),
                ),
                builder: (context, snapshot) {
                  final int hostBalance = snapshot.data ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14011D).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF4A156D).withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 8,
                          backgroundImage: hostPicture != null && hostPicture.isNotEmpty
                              ? NetworkImage(hostPicture)
                              : null,
                          child: (hostPicture == null || hostPicture.isEmpty)
                              ? const Icon(Icons.person, size: 9, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            hostName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.diamond, color: Color(0xFF00E5FF), size: 10),
                        const SizedBox(width: 2),
                        Text(
                          formatViewCount(hostBalance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeatCard({
    required int seatNo,
    required double width,
    required double height,
  }) {
    final currentUserId = _auth.currentUser!.uid;
    RoomParticipant? participant;
    try {
      participant = _participants.firstWhere((p) => p.seatNo == seatNo);
    } catch (_) {
      participant = null;
    }

    final lockedData = roomData['lockedSeats'];
    bool isLocked = false;
    if (lockedData is Map) {
      isLocked = lockedData['seat_$seatNo'] == true || lockedData[seatNo.toString()] == true;
    } else if (lockedData is List) {
      if (seatNo < lockedData.length) {
        isLocked = lockedData[seatNo] == true;
      }
    }

    if (participant != null) {
      return _buildOccupiedSeatCard(
        seatNo: seatNo,
        participant: participant,
        width: width,
        height: height,
        isCurrentUser: participant.userId == currentUserId,
        isLocked: isLocked,
      );
    } else {
      return _buildEmptySeatCard(
        seatNo: seatNo,
        width: width,
        height: height,
        isLocked: isLocked,
      );
    }
  }

  Widget _buildOccupiedSeatCard({
    required int seatNo,
    required RoomParticipant participant,
    required double width,
    required double height,
    required bool isCurrentUser,
    required bool isLocked,
  }) {
    final canLeaveSeat = isCurrentUser && !widget.isHost && !participant.isLocked;
    final double avatarSize = width * 0.50;
    final String? guestVip = participant.vipType ?? VipService.getVipTypeSync(participant.userId);
    final bool hasGuestVip = guestVip != null && guestVip.isNotEmpty;
    final bool isGuestVvip = hasGuestVip && guestVip.toLowerCase().contains('vvip');

    return GestureDetector(
      onTap: !canLeaveSeat
          ? () {
              final participantMap = _participants.firstWhere(
                (p) => p.userId == _auth.currentUser!.uid,
                orElse: () => RoomParticipant(userId: '', displayId: '', userName: '', seatNo: -1, isCoHost: false, isMuted: false),
              );
              showProfileInfoBottomSheet(
                context,
                userId: participant.userId,
                hostId: roomData['hostId'] ?? '',
                roomId: widget.roomID,
                isSeated: true,
                isCurrentUserAdmin: participantMap.isAdmin,
                isCurrentUserModerator: _isCurrentModerator,
              );
            }
          : () async {
              final bool? shouldLeave = await _showLeaveSeatConfirmationDialog();
              if (shouldLeave == true) {
                try {
                  await RoomService.leaveSeat(widget.roomID);
                  StreamingService.instance.setMicrophoneEnabled(false);
                } catch (e) {
                  debugPrint("Error leaving seat: $e");
                }
              }
            },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF28073D).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF4A156D).withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            // Top Row: Seat Number on Left, (x) on Right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0x80000000),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$seatNo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: (widget.isHost || _isCurrentModerator)
                      ? () => _showSeatUserBottomSheet(seatNo, isLocked)
                      : null,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0x33FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.close, size: 10, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),

            // Center Avatar with Speaking & VIP badge
            Center(
              child: SizedBox(
                width: avatarSize * 1.4,
                height: avatarSize * 1.4,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    StreamBuilder<List<String>>(
                      stream: StreamingService.instance.activeSpeakersStream,
                      builder: (context, snapshot) {
                        final isSpeaking = !participant.isMuted &&
                            (snapshot.data ?? []).contains(participant.userId);
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: avatarSize,
                              height: avatarSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSpeaking
                                      ? const Color(0xFF00E5FF)
                                      : Colors.pinkAccent.withValues(alpha: 0.6),
                                  width: 2.0,
                                ),
                              ),
                              child: ClipOval(
                                child: participant.userPicture != null &&
                                        participant.userPicture!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: participant.userPicture!,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(
                                          Icons.person,
                                          size: 20,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.person, size: 20, color: Colors.white),
                              ),
                            ),
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

                    // VIP / VVIP Frame (Only if guest has VIP) or Active Frame
                    if (hasGuestVip)
                      Positioned(
                        top: (avatarSize - (avatarSize * 1.823)) / 2 - (avatarSize * 0.1644),
                        left: (avatarSize - (avatarSize * 1.823)) / 2,
                        width: avatarSize * 1.823,
                        height: avatarSize * 1.823,
                        child: IgnorePointer(
                          child: Image.asset(
                            isGuestVvip ? 'assets/images/VVIP PNG.png' : 'assets/images/VIP PNG.png',
                            width: avatarSize * 1.823,
                            height: avatarSize * 1.823,
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                    else
                      // Active Frame
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

                    // Muted Indicator
                    if (participant.isMuted)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.mic_off, color: Colors.white, size: 9),
                        ),
                      ),

                    _buildEmojiOnAvatar(participant.userId, avatarSize),
                  ],
                ),
              ),
            ),

            // Bottom Capsule Pill with Mini Avatar, Name, and Diamonds
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StreamBuilder<int>(
                stream: ProfileService.getUserDiamondsStream(participant.userId),
                builder: (context, snapshot) {
                  final userBalance = snapshot.data ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14011D).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF4A156D).withValues(alpha: 0.6),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 6,
                          backgroundImage: participant.userPicture != null &&
                                  participant.userPicture!.isNotEmpty
                              ? NetworkImage(participant.userPicture!)
                              : null,
                          child: (participant.userPicture == null || participant.userPicture!.isEmpty)
                              ? const Icon(Icons.person, size: 7, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            participant.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.diamond, color: Color(0xFF00E5FF), size: 9),
                        const SizedBox(width: 1),
                        Text(
                          formatViewCount(userBalance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySeatCard({
    required int seatNo,
    required double width,
    required double height,
    required bool isLocked,
  }) {
    final currentUser = _auth.currentUser!;
    RoomParticipant? currentUserParticipant;
    try {
      currentUserParticipant = _participants.firstWhere((p) => p.userId == currentUser.uid);
    } catch (_) {
      currentUserParticipant = null;
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

    final double avatarSize = width * 0.50;

    return GestureDetector(
      onTap: () async {
        if (!canInteract) return;
        if (widget.isHost || _isCurrentModerator) {
          _showSeatUserBottomSheet(seatNo, isLocked);
          return;
        }

        if (currentUserParticipant?.isLocked == true && !widget.isHost) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You are locked and cannot change seats.'), backgroundColor: Colors.red),
            );
          }
          return;
        }

        final bool hasVip = await ProfileService.hasKingOrRoyalPackage(currentUser.uid);

        if (isLocked && !hasVip) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This seat is locked by the host.'), backgroundColor: Colors.red),
            );
          }
          return;
        }

        try {
          if (isListener) {
            if (hasVip) {
              await RoomService.joinCallImmediately(widget.roomID, targetSeatNo: seatNo);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('VIP privilege: Seated on seat $seatNo directly!'), backgroundColor: Colors.green),
                );
              }
              return;
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please tap the Call icon to request a seat.'), backgroundColor: Colors.orange),
              );
            }
            return;
          } else if (isSpeakerOrCoHost) {
            if (_isMoveAllowed) {
              await RoomService.moveSeat(widget.roomID, seatNo);
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('The host has disabled moving between seats.'), backgroundColor: Colors.orange),
                );
              }
            }
          }
        } catch (e) {
          debugPrint("Error with seat action: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
          }
        }
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFF28073D).withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF4A156D).withValues(alpha: 0.35),
            width: 0.8,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            // Top Row: Seat Number on Left, (x) or lock on Right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0x80000000),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$seatNo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: (widget.isHost || _isCurrentModerator)
                      ? () => _showSeatUserBottomSheet(seatNo, isLocked)
                      : null,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Color(0x33FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isLocked ? Icons.lock : Icons.close,
                        size: 9,
                        color: isLocked ? Colors.redAccent : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Center Empty Icon / Mic
            Center(
              child: Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isLocked ? Colors.redAccent.withValues(alpha: 0.5) : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    isLocked ? Icons.lock : CupertinoIcons.mic,
                    color: isLocked ? Colors.redAccent : Colors.white54,
                    size: avatarSize * 0.45,
                  ),
                ),
              ),
            ),

            // Bottom Capsule Pill
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF14011D).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isLocked ? 'Locked' : 'Empty',
                    style: TextStyle(
                      color: isLocked ? Colors.redAccent : Colors.white54,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSeatUserBottomSheet(int seatNo, bool isLocked) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF28073D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Seat $seatNo Options',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            ListTile(
              leading: Icon(
                isLocked ? Icons.lock_open : Icons.lock,
                color: isLocked ? Colors.greenAccent : Colors.redAccent,
              ),
              title: Text(
                isLocked ? 'Unlock Seat' : 'Lock Seat',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                Navigator.pop(context);
                try {
                  if (isLocked) {
                    await RoomService.unlockSeat(widget.roomID, seatNo);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Seat $seatNo unlocked'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    await RoomService.lockSeat(widget.roomID, seatNo);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Seat $seatNo locked'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildRightActionButtons() {
    final bool isRoomLocked = roomData['isLocked'] == true;
    return Positioned(
      right: 12,
      bottom: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cyan Share Button
          GestureDetector(
            onTap: () {
              final roomId = widget.roomID;
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1F022D),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Share Room',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: const Icon(Icons.copy, color: Color(0xFF00E5FF)),
                          title: Text('Room ID: $roomId', style: const TextStyle(color: Colors.white)),
                          trailing: const Text('Copy', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: roomId));
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Room ID copied!'), backgroundColor: Colors.green),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.share, color: Color(0xFF00E5FF), size: 19),
            ),
          ),
          const SizedBox(height: 10),

          // Gold Lock Button
          GestureDetector(
            onTap: () async {
              if (!widget.isHost) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Only host can lock the room.'), backgroundColor: Colors.orange),
                );
                return;
              }
              final bool newLock = !isRoomLocked;
              try {
                await RoomService.toggleRoomLock(widget.roomID, newLock);
                setState(() {
                  roomData['isLocked'] = newLock;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(newLock ? 'Room is locked!' : 'Room is unlocked!'),
                      backgroundColor: newLock ? Colors.redAccent : Colors.green,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error toggle lock: $e');
              }
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                isRoomLocked ? Icons.lock : Icons.lock_open,
                color: const Color(0xFFFFD700),
                size: 19,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Purple Settings Button
          GestureDetector(
            onTap: () {
              showAudioToolsBottomSheet(
                context,
                isHost: widget.isHost || (_participants.firstWhere((p) => p.userId == _auth.currentUser!.uid, orElse: () => RoomParticipant(userId: '', displayId: '', userName: '', seatNo: -1, isCoHost: false, isMuted: false)).isAdmin),
                musicManager: _musicPlayerManager,
                currentRoomId: widget.roomID,
                hostId: roomData['hostId'] ?? '',
              );
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFAB47BC).withValues(alpha: 0.2),
                border: Border.all(color: const Color(0xFFCE93D8), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFAB47BC).withValues(alpha: 0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Icon(Icons.settings, color: Color(0xFFE1BEE7), size: 19),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(RoomParticipant participant, {bool isSpeaking = false, double size = 55}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
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
            displayDuration: Duration(seconds: _fullScreenGiftDuration ?? 10),
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
    if (widget.isHost) return const SizedBox.shrink();

    final String currentUserId = _auth.currentUser!.uid;
    RoomParticipant? currentUserParticipant;
    try {
      currentUserParticipant = _participants.firstWhere(
        (p) => p.userId == currentUserId,
      );
    } catch (e) {
      currentUserParticipant = null;
    }

    final bool isSpeakerOrCoHost =
        (currentUserParticipant != null &&
            (currentUserParticipant.seatNo > 0 ||
                currentUserParticipant.isCoHost));

    if (isSpeakerOrCoHost) return const SizedBox.shrink();

    return Positioned(
      bottom: 20,
      right: 64,
      child: GestureDetector(
        onTap: () async {
          try {
            final bool hasVip = await ProfileService.hasKingOrRoyalPackage(currentUserId);
            if (hasVip) {
              await RoomService.joinCallImmediately(widget.roomID);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('VIP privilege: Seated directly!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              return;
            }

            await RoomService.requestToBeSpeaker(widget.roomID);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Request to sit sent to the host!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $e')),
              );
            }
          }
        },
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.pink.shade400, Colors.pink.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Icon(
              Icons.phone_in_talk,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  // Method to render user level tag matching screenshot
  Widget _buildLevelBadge(String userId) {
    if (!_userLevelCache.containsKey(userId)) {
      ProfileService.getUserProfile(userId)
          .then((doc) {
            if (doc.exists && mounted) {
              final data = doc.data() as Map<String, dynamic>;
              final int totalSent = data['totalSent'] ?? 0;
              setState(() {
                _userLevelCache[userId] = getSentLevel(totalSent);
                if (data['photoUrl'] != null) {
                  _userPictureCache[userId] = data['photoUrl'];
                }
              });
            }
          })
          .catchError((_) {});
    }

    final int level = _userLevelCache[userId] ?? 1;
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
        ),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8F00).withValues(alpha: 0.3),
            blurRadius: 3,
          ),
        ],
      ),
      child: Text(
        'L.v. $level',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildShowCommentsButton() {
    return Positioned(
      left: 14,
      bottom: 8,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isCommentsHidden = false;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1B2A).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1E88E5), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white, size: 14),
              SizedBox(width: 5),
              Text(
                'Show comments',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatSection() {
    return AnimatedSlide(
      offset: _isCommentsHidden ? const Offset(-1.2, 0.0) : Offset.zero,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: _isCommentsHidden ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 250),
        child: IgnorePointer(
          ignoring: _isCommentsHidden,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity < -120) {
                // Swiped right-to-left -> hide comments
                setState(() {
                  _isCommentsHidden = true;
                });
              } else if (velocity > 120) {
                // Swiped left-to-right -> show comments
                setState(() {
                  _isCommentsHidden = false;
                });
              }
            },
            child: ListView.builder(
              reverse: true,
              controller: _chatScrollController,
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 60.0, 8.0),
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
                    style: TextStyle(
                      color: Colors.white70, 
                      fontSize: 10,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 3,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
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
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 3,
                                  offset: Offset(1, 1),
                                ),
                              ],
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
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 3,
                            offset: Offset(1, 1),
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

        // Check if it's a join message
        if (m.isJoinMessage) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () {
                showProfileInfoBottomSheet(
                  context,
                  userId: m.userId,
                  hostId: roomData['hostId'] ?? '',
                  roomId: widget.roomID,
                  isCurrentUserAdmin: _participants.firstWhere((p) => p.userId == _auth.currentUser!.uid, orElse: () => RoomParticipant(userId: '', displayId: '', userName: '', seatNo: -1, isCoHost: false, isMuted: false)).isAdmin,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.purpleAccent.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildChatAvatar(m.userId, m.username),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            m.username,
                            style: TextStyle(
                              color: Colors.lightBlue.shade300,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              shadows: const [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 3,
                                  offset: Offset(1, 1),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildLevelBadge(m.userId),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 3,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Regular chat message (Deep Purple Card with Purple Glow Border matching screenshot)
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1B032A).withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.85),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                    blurRadius: 6,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      showProfileInfoBottomSheet(
                        context,
                        userId: m.userId,
                        hostId: roomData['hostId'] ?? '',
                        roomId: widget.roomID,
                        isCurrentUserAdmin: _participants.firstWhere(
                          (p) => p.userId == _auth.currentUser!.uid,
                          orElse: () => RoomParticipant(userId: '', displayId: '', userName: '', seatNo: -1, isCoHost: false, isMuted: false),
                        ).isAdmin,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _buildChatAvatar(m.userId, m.username),
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
                            _buildLevelBadge(m.userId),
                            Flexible(
                              child: Text(
                                m.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black87,
                                      blurRadius: 3,
                                      offset: Offset(1, 1),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          m.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 3,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
    ),
    ),
    ),
    );
  }

  Widget _buildChatAvatar(String userId, String username) {
    final pictureUrl = _userPictureCache[userId];
    const double size = 26.0;
    return SizedBox(
      width: size + 6,
      height: size + 6,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
              border: Border.all(color: const Color(0xFFFFD700), width: 1.0),
            ),
            child: ClipOval(
              child: pictureUrl != null && pictureUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: pictureUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _defaultChatAvatar(username),
                    )
                  : _defaultChatAvatar(username),
            ),
          ),
          Positioned(
            bottom: -3,
            right: -3,
            child: Image.asset(
              'assets/images/VVIP PNG.png',
              width: 17,
              height: 17,
              fit: BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultChatAvatar(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name.characters.first.toUpperCase() : "?",
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
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

    final bool isSpeakerOrCoHost =
        widget.isHost ||
        (currentUserParticipant != null &&
            (currentUserParticipant.seatNo > 0 ||
                currentUserParticipant.isCoHost));

    final bool isCurrentlyMuted =
        _localMuteOverride ?? (currentUserParticipant?.isMuted ?? true);
    final int totalRequests = _coHostRequests.length + _speakerRequests.length;

    const double buttonSize = 34.0;
    const double iconSize = 18.0;
    const double paddingRight = 6.0;

    final mediaQuery = MediaQuery.of(context);
    final double safeBottom = math.max(
      mediaQuery.padding.bottom,
      mediaQuery.viewPadding.bottom,
    );
    final double bottomPadding = mediaQuery.viewInsets.bottom > 0
        ? 10.0 + mediaQuery.viewInsets.bottom
        : math.max(26.0, 12.0 + safeBottom);

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 8, 10, bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Chat Input Capsule
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              height: 40.0,
              padding: const EdgeInsets.only(left: 6, right: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B032A).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: const Color(0xFF7B1FA2).withValues(alpha: 0.65),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7B1FA2).withValues(alpha: 0.2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      focusNode: _chatFocusNode,
                      textInputAction: TextInputAction.send,
                      style: const TextStyle(color: Colors.white, fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'Say hi',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _sendMessage,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          if (!_isChatExpanded) ...[
            // 1. Pink Gift Button
            GestureDetector(
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                final hostId = roomData['hostId'] ?? '';
                final hostName = roomData['hostName'] ?? 'Host';
                final hostPicture = roomData['hostPicture'];

                final List<RoomParticipant> giftParticipants = List.from(
                  _participants,
                );
                final bool hasHost = giftParticipants.any(
                  (p) => p.userId == hostId,
                );
                if (!hasHost && hostId.isNotEmpty) {
                  giftParticipants.insert(
                    0,
                    RoomParticipant(
                      userId: hostId,
                      displayId: '',
                      userName: hostName,
                      userPicture: hostPicture,
                      seatNo: 0,
                      isCoHost: false,
                      isMuted: false,
                    ),
                  );
                }

                showGiftBottomSheet(
                  context,
                  roomId: widget.roomID,
                  participants: giftParticipants,
                  hostId: hostId,
                );
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE91E63).withValues(alpha: 0.25),
                  border: Border.all(color: const Color(0xFFE91E63), width: 1.5),
                ),
                child: const Icon(
                  CupertinoIcons.gift_fill,
                  color: Color(0xFFE91E63),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 2. Green Call Button
            GestureDetector(
              onTap: () async {
                if (widget.isHost) {
                  showAllRequestsBottomSheet(
                    context,
                    coHostRequests: _coHostRequests,
                    speakerRequests: _speakerRequests,
                    roomID: widget.roomID,
                    isMoveAllowed: _isMoveAllowed,
                    isSeatApprovalRequired: _isSeatApprovalRequired,
                  );
                } else if (isSpeakerOrCoHost) {
                  final newMuteState = !isCurrentlyMuted;
                  setState(() {
                    _localMuteOverride = newMuteState;
                  });
                  try {
                    await StreamingService.instance.setMicrophoneEnabled(!newMuteState);
                    await RoomService.toggleMuteState(widget.roomID, newMuteState);
                  } catch (e) {
                    debugPrint('Error toggling mute state: $e');
                  }
                } else {
                  // Listener request
                  try {
                    final bool hasVip = await ProfileService.hasKingOrRoyalPackage(currentUserId);
                    if (hasVip) {
                      await RoomService.joinCallImmediately(widget.roomID);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('VIP privilege: Seated directly!'), backgroundColor: Colors.green),
                        );
                      }
                      return;
                    }
                    await RoomService.requestToBeSpeaker(widget.roomID);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Call request sent to host!'), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    debugPrint('Error requesting call: $e');
                  }
                }
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                      border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
                    ),
                    child: Icon(
                      isSpeakerOrCoHost
                          ? (isCurrentlyMuted ? CupertinoIcons.mic_off : CupertinoIcons.mic_fill)
                          : Icons.call,
                      color: const Color(0xFF4CAF50),
                      size: 18,
                    ),
                  ),
                  if (widget.isHost && totalRequests > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.redAccent,
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
            const SizedBox(width: 8),

            // 3. Pink Heart Button
            GestureDetector(
              onTap: () {
                _sendEmojiMessage('❤️');
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF2E93).withValues(alpha: 0.25),
                  border: Border.all(color: const Color(0xFFFF2E93), width: 1.5),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Color(0xFFFF2E93),
                  size: 18,
                ),
              ),
            ),
          ],
          if (_isChatExpanded)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () {
                  _chatFocusNode.unfocus();
                  _chatController.clear();
                },
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    final messageText = _chatController.text.trim();
    if (messageText.isEmpty) return;
    
    // Check if the current user is chat muted
    final String currentUserId = _auth.currentUser?.uid ?? '';
    RoomParticipant? currentUserParticipant;
    try {
      currentUserParticipant = _participants.firstWhere((p) => p.userId == currentUserId);
    } catch (_) {}
    
    if (currentUserParticipant != null && currentUserParticipant.isChatMuted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have been muted in the chat.'), backgroundColor: Colors.red),
      );
      return;
    }

    final String msgId = DateTime.now().millisecondsSinceEpoch.toString();
    _chatController.clear();
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isCommentsHidden = false;
      _messages.insert(
        0,
        ChatMessage(
          id: msgId,
          userId: currentUserId,
          username: _currentUserName,
          message: messageText,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToNewestMessage();

    try {
      await StreamingService.instance.sendChatMessage(
        messageText,
        roomId: widget.roomID,
        isVideo: false,
        customId: msgId,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  void _sendJoinMessage() async {
    const messageText = "Just joined the room!";
    final String msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final String currentUserId = _auth.currentUser?.uid ?? '';

    if (mounted) {
      setState(() {
        _messages.insert(
          0,
          ChatMessage(
            id: msgId,
            userId: currentUserId,
            username: _currentUserName,
            message: messageText,
            timestamp: DateTime.now(),
            isJoinMessage: true,
          ),
        );
      });
      _scrollToNewestMessage();
    }

    try {
      await StreamingService.instance.sendChatMessage(
        messageText,
        roomId: widget.roomID,
        isVideo: false,
        customId: msgId,
      );
    } catch (e) {
      debugPrint('Error sending join message: $e');
    }
  }

  void _scrollToNewestMessage({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        try {
          if (animated &&
              _chatScrollController.position.hasPixels &&
              _chatScrollController.offset > 0.0) {
            _chatScrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutQuad,
            );
          } else {
            _chatScrollController.jumpTo(0.0);
          }
        } catch (_) {
          if (_chatScrollController.hasClients) {
            _chatScrollController.jumpTo(0.0);
          }
        }
      }
    });
  }

  void _handleRoomEnded() {
    if (_isRoomEnded || !mounted) return;

    // Immediately stop streaming
    StreamingService.instance.disconnect();

    setState(() {
      _isRoomEnded = true;
      _isInitialized = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('The room has been closed by admin.'),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 4),
      ),
    );

    context.go(Routes.home.path);
  }

  void _handleKicked() {
    if (_isRoomEnded || !mounted) return;

    // Immediately stop streaming
    StreamingService.instance.disconnect();

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



  void _updateCoHostElapsedTimer() {
    if (!_isInitialized) return;
    final currentUserId = _auth.currentUser?.uid;
    final bool isUserCoHost = _participants.any(
      (p) => p.userId == currentUserId && p.isCoHost == true,
    );

    if (isUserCoHost) {
      _coHostElapsedTimer ??= Timer.periodic(const Duration(seconds: 30), (
        timer,
      ) async {
        final hostId = roomData['hostId'] ?? '';
        if (hostId.isNotEmpty && currentUserId != null) {
          await RoomService.updateCoHostElapsedTime(
            widget.roomID,
            hostId,
            currentUserId,
            30 * 1000,
          );
        }
      });
    } else {
      _coHostElapsedTimer?.cancel();
      _coHostElapsedTimer = null;
    }
  }
  Widget _buildEmojiColumnOverlay() {
    final mediaQuery = MediaQuery.of(context);
    final double safeBottom = math.max(
      mediaQuery.padding.bottom,
      mediaQuery.viewPadding.bottom,
    );
    final double chatInputBottom = math.max(26.0, 12.0 + safeBottom);
    final double bottomOffset = 54.0 + chatInputBottom;

    return Positioned(
      right: 12,
      bottom: bottomOffset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEmojiButton('❤️'),
          const SizedBox(height: 10),
          _buildEmojiButton('👍'),
          const SizedBox(height: 10),
          _buildEmojiButton('😂'),
        ],
      ),
    );
  }

  Widget _buildEmojiButton(String emoji) {
    return GestureDetector(
      onTap: () => _sendEmojiMessage(emoji),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF2C384E).withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }

  void _sendEmojiMessage(String emoji) async {
    try {
      _showFloatingEmoji(emoji, senderName: _currentUserName);
      await StreamingService.instance.sendEmoji(
        emoji,
        roomId: widget.roomID,
        isVideo: false,
      );
    } catch (e) {
      debugPrint('Error sending emoji message: $e');
    }
  }

  void _showFloatingEmoji(String emoji, {String? senderName}) {
    if (!mounted) return;
    final key = UniqueKey();
    setState(() {
      _floatingEmojis.add(FloatingEmoji(
        emoji: emoji,
        key: key,
        leftOffset: 10.0 + (DateTime.now().millisecondsSinceEpoch % 30),
        senderName: senderName,
      ));
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _floatingEmojis.removeWhere((e) => e.key == key);
        });
      }
    });
  }

  Widget _buildFloatingEmojis() {
    final double bottomOffset = 64.0 + MediaQuery.of(context).padding.bottom;

    return Positioned(
      right: 56,
      bottom: bottomOffset,
      width: 100,
      height: 300,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: _floatingEmojis.map((e) => _FloatingEmojiWidget(
            key: e.key,
            emoji: e.emoji,
            leftOffset: e.leftOffset,
            senderName: e.senderName,
          )).toList(),
        ),
      ),
    );
  }
}

class CoHostOption {
  final String title;
  final int coins;
  final Duration duration;

  const CoHostOption({
    required this.title,
    required this.coins,
    required this.duration,
  });
}

class CoHostTimer extends StatefulWidget {
  final int coHostUntil;
  final String roomId;
  final String userId;

  const CoHostTimer({
    super.key,
    required this.coHostUntil,
    required this.roomId,
    required this.userId,
  });

  @override
  State<CoHostTimer> createState() => _CoHostTimerState();
}

class _CoHostTimerState extends State<CoHostTimer> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _startTimer();
  }

  @override
  void didUpdateWidget(CoHostTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coHostUntil != widget.coHostUntil) {
      _timer?.cancel();
      _calculateRemaining();
      _startTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateRemaining() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = widget.coHostUntil - now;
    if (diff <= 0) {
      _remaining = Duration.zero;
      _onExpired();
    } else {
      _remaining = Duration(milliseconds: diff);
    }
  }

  void _onExpired() {
    _timer?.cancel();
    RoomService.removeCoHost(widget.roomId, widget.userId).catchError((e) {
      debugPrint("Error removing expired co-host: $e");
    });
  }

  void _startTimer() {
    if (_remaining == Duration.zero) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _calculateRemaining();
      });
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours >= 1) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    } else {
      final minutes = duration.inMinutes.toString().padLeft(2, '0');
      final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _formatDuration(_remaining),
        style: const TextStyle(
          color: Colors.cyanAccent,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _CoHostPurchaseDialogContent extends StatefulWidget {
  final String roomId;
  final String hostId;

  const _CoHostPurchaseDialogContent({
    required this.roomId,
    required this.hostId,
  });

  @override
  State<_CoHostPurchaseDialogContent> createState() =>
      __CoHostPurchaseDialogContentState();
}

class __CoHostPurchaseDialogContentState
    extends State<_CoHostPurchaseDialogContent> {
  int _selectedIndex = 0;
  bool _isLoading = false;

  final List<CoHostOption> _options = const [
    CoHostOption(title: '2 Hours', coins: 20000, duration: Duration(hours: 2)),
    CoHostOption(title: '3 Hours', coins: 50000, duration: Duration(hours: 3)),
    CoHostOption(title: '6 Hours', coins: 100000, duration: Duration(hours: 6)),
    CoHostOption(
      title: '12 Hours',
      coins: 400000,
      duration: Duration(hours: 12),
    ),
    CoHostOption(
      title: '1 Month',
      coins: 1000000,
      duration: Duration(days: 30),
    ),
  ];

  String _formatCoins(int count) {
    if (count == 20000) return '20,000';
    if (count == 50000) return '50,000';
    if (count == 100000) return '1,00,000';
    if (count == 400000) return '4,00,000';
    if (count == 1000000) return '10,00,000';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final selectedOption = _options[_selectedIndex];

    return StreamBuilder<int>(
      stream: ProfileService.getCurrentUserBalanceStream(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0;
        final hasEnough = balance >= selectedOption.coins;

        return AlertDialog(
          backgroundColor: const Color(0xFF2d1b2b),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.pink.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          title: const Row(
            children: [
              Icon(Icons.event_seat, color: Colors.pink, size: 24),
              SizedBox(width: 8),
              Text(
                'Become Co-Host',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your Balance:',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.diamond,
                            color: Colors.cyanAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            balance.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select a duration (Transfer to Host):',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _options.length,
                  itemBuilder: (ctx, index) {
                    final option = _options[index];
                    final isSelected = _selectedIndex == index;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.pink.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? Colors.pink
                                : Colors.white.withValues(alpha: 0.1),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              option.title,
                              style: TextStyle(
                                color: isSelected ? Colors.pink : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.diamond,
                                  color: Colors.cyan,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatCoins(option.coins),
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.pink
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_isLoading || !hasEnough)
                        ? null
                        : () async {
                            setState(() {
                              _isLoading = true;
                            });
                            try {
                              await RoomService.purchaseCoHostSeat(
                                roomId: widget.roomId,
                                hostId: widget.hostId,
                                coinPrice: selectedOption.coins,
                                duration: selectedOption.duration,
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Successfully joined as Co-Host for ${selectedOption.title}!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                setState(() {
                                  _isLoading = false;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Purchase failed: ${e.toString().replaceAll('Exception: ', '')}',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      disabledBackgroundColor: Colors.grey.shade800,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            hasEnough ? 'Purchase' : 'Low Balance',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class FloatingEmoji {
  final String emoji;
  final Key key;
  final double leftOffset;
  final String? senderName;

  FloatingEmoji({required this.emoji, required this.key, required this.leftOffset, this.senderName});
}

class _FloatingEmojiWidget extends StatefulWidget {
  final String emoji;
  final double leftOffset;
  final String? senderName;

  const _FloatingEmojiWidget({
    super.key,
    required this.emoji,
    required this.leftOffset,
    this.senderName,
  });

  @override
  State<_FloatingEmojiWidget> createState() => _FloatingEmojiWidgetState();
}

class _FloatingEmojiWidgetState extends State<_FloatingEmojiWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _positionAnimation = Tween<double>(begin: 0, end: -250).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.5, 1.0)),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: widget.leftOffset,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _positionAnimation.value),
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.emoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  if (widget.senderName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.senderName!,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

