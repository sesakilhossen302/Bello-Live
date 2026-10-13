import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_svga/flutter_svga.dart';
import 'package:picture_live/core/services/streaming_service.dart';
import 'package:collection/collection.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/cubits/app_cubit.dart';
import '../../core/widgets/active_frame_widget.dart'; // Added the ActiveFrameWidget import
import '../../core/widgets/GiftImageWidget.dart'; // For GiftImageWidget
import 'widgets/floating_youtube_player.dart';
import '../../core/widgets/network_svga_player.dart';
import '../../data/remote/firebase/live_streaming_services.dart';
import '../../data/remote/firebase/profile_services.dart';
import '../../core/widgets/vip_avatar_widget.dart';
import '../../core/services/vip_service.dart';
import '../../navigation/routes.dart';
import '../profile/profile_page.dart';
import '../streaming/audio_room_page.dart';
import 'bottomsheets/invite_pk_bottomsheet.dart';
import 'bottomsheets/profile_info_bottomsheet.dart';
import 'bottomsheets/call_and_views_bottomsheet.dart';
import 'bottomsheets/emoji_bottomsheet.dart';
import '../../ui/streaming/bottomsheets/rocket_config_bottomsheet.dart';

import '../../ui/streaming/bottomsheets/play_music_bottomsheet.dart';
import '../streaming/bottomsheets/room_skin.dart';
import 'bottomsheets/video_gifts_bottomsheet.dart';
import '../../ui/streaming/bottomsheets/fans_ranking_bottomsheet.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// --- MODELS ---
class LiveStreamParticipant {
  final String userId;
  final String userName;
  final String? userPicture;
  final bool isMuted;
  final bool isCameraOn;
  final bool isOnSeat;
  final bool isLocked;
  final String? gender;
  final bool isModerator;
  final bool isAdmin;
  final bool isCoHost;
  final String? idEntryUrl;
  final String? callType;
  final String? vipType;

  LiveStreamParticipant({
    required this.userId,
    required this.userName,
    this.userPicture,
    required this.isMuted,
    required this.isCameraOn,
    required this.isOnSeat,
    this.isLocked = false,
    this.gender,
    this.isModerator = false,
    this.isAdmin = false,
    this.isCoHost = false,
    this.idEntryUrl,
    this.callType,
    this.vipType,
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
      isLocked: data['isLocked'] ?? false,
      gender: data['gender'],
      isModerator: data['isModerator'] == true || data['isStealth'] == true,
      isAdmin: data['isAdmin'] == true,
      isCoHost: data['isCoHost'] == true,
      idEntryUrl: data['idEntryUrl'] as String?,
      vipType:
          (data['vipType'] as String?) ??
          (data['vip'] is String ? data['vip'] as String : null) ??
          (data['isVvip'] == true
              ? 'vvip'
              : (data['isVip'] == true ? 'vip' : null)),
    );
  }
}

class JoinRequest {
  final String requestId;
  final String userId;
  final String userName;
  final String? userPicture;
  final String? gender;
  final String callType;

  JoinRequest({
    required this.requestId,
    required this.userId,
    required this.userName,
    this.userPicture,
    this.gender,
    this.callType = 'audio',
  });

  factory JoinRequest.fromRTDB(String key, Map<dynamic, dynamic> data) {
    return JoinRequest(
      requestId: key,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userPicture: data['userPicture'],
      gender: data['gender'],
      callType: data['callType'] ?? 'audio',
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
  final int? userLevel;

  ChatMessage({
    this.id,
    required this.userId,
    required this.username,
    required this.message,
    required this.timestamp,
    this.isGiftMessage = false,
    this.giftValue,
    this.userLevel,
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late MusicPlayerManager _musicPlayerManager;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();
  bool _isChatExpanded = false;
  bool _isCommentsHidden = false;

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
  StreamSubscription? _callInviteSubscription;
  StreamSubscription? _commentsEnabledSubscription;
  StreamSubscription? _userDocSubscription;
  bool _isCommentsEnabled = true;
  bool _isCallInviteDialogShowing = false;
  BuildContext? _currentRandomPKDialogContext;
  final Map<String, Stream<int>> _diamondsStreamCache = {};

  // Cache to store user levels to avoid redundant Firestore reads while scrolling
  final Map<String, int> _userLevelCache = {};
  final Map<String, String> _userPictureCache = {};

  int _lastProcessedGiftTime = 0;

  // State Variables
  Map<String, dynamic> roomData = {};
  List<LiveStreamParticipant> _participants = [];
  final List<ChatMessage> _messages = [];
  final List<FloatingEmoji> _floatingEmojis = [];
  List<JoinRequest> _joinRequests = [];
  List<PKInvite> _pendingInvites = [];
  int _participantCount = 0;
  bool _isInitialized = false;
  bool _isDiamondLocked = false;
  late bool _isJoined;
  bool? _localMuteOverride;
  bool _roomDoesNotExist = false;
  String _currentUserName = "Me";
  final Set<String> _dialogsShownForInviteIds = {};
  String _roomNotice = "";
  bool _isRoomEnded = false;
  bool _isCurrentModerator = false;
  bool _isRightMenuExpanded = false;
  bool _isSpeakerMuted = false;

  // --- Join Animation Variables ---
  final Duration welcomeTime = const Duration(milliseconds: 3500);
  Timer? _joinAnimationTimer;
  String? _newJoinerName;
  String? _newJoinerPicture;
  String? _newJoinerId;
  String? _newJoinerIdEntryUrl;
  late AnimationController _joinAnimationController;
  late Animation<Offset> _joinAnimationOffset;

  // PK State Variables
  bool _isPKMode = false;
  Map<String, dynamic> _pkState = {};
  bool _isMinimizing = false;
  List<LiveStreamParticipant> _opponentParticipants = [];

  Timer? _pkTimer;
  String _pkTimerDisplay = "00:00";

  int _pkScoreBlue = 0;
  int _pkScoreRed = 0;
  bool _isPKResultShowing = false;

  bool _isStartingPKAnimation = false;

  // Emoji State
  EmojiEvent? _currentEmojiEvent;
  Timer? _emojiTimer;

  GiftOverlay? _currentGiftOverlay;
  Timer? _giftOverlayTimer;
  String? _fullScreenGiftUrl;
  int? _fullScreenGiftDuration;

  // --- Duration Timer Variables ---
  Timer? durationTimer;
  final ValueNotifier<Duration> _currentDuration = ValueNotifier(Duration.zero);

  // --- Package Badge Cache ---
  final Map<String, String?> _packageBadgeCache = {};
  final Map<String, Future<String?>> _packageBadgeFetchFutures = {};

  Future<String?> _fetchPackageBadgeUrl(String userId) async {
    if (_packageBadgeCache.containsKey(userId))
      return _packageBadgeCache[userId];
    if (_packageBadgeFetchFutures.containsKey(userId)) {
      return await _packageBadgeFetchFutures[userId];
    }
    final Future<String?> future = () async {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null && data.containsKey('activeAddOns')) {
            final addOns = data['activeAddOns'] as Map<String, dynamic>;
            final now = DateTime.now();
            for (var entry in addOns.entries) {
              if (entry.key.toLowerCase().contains('package')) {
                final itemData = entry.value as Map<String, dynamic>?;
                if (itemData != null) {
                  final expiry = itemData['expiresAt'] as Timestamp?;
                  if (expiry == null || expiry.toDate().isAfter(now)) {
                    final url = itemData['imageUrl'] as String?;
                    _packageBadgeCache[userId] = url;
                    return url;
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
      _packageBadgeCache[userId] = null;
      return null;
    }();
    _packageBadgeFetchFutures[userId] = future;
    final result = await future;
    _packageBadgeFetchFutures.remove(userId);
    return result;
  }

  Future<void> _checkModeratorStatus() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;
    try {
      // Clear any stale cached moderator value
      ProfileService.clearModeratorCache();
      bool isMod = false;

      // 1. Check user document directly in Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final role = data['role']?.toString().toLowerCase().trim() ?? '';
        final userField = data['user']?.toString().toLowerCase().trim() ?? '';
        final isM = data['isModerator'] == true || data['ismoderator'] == true;
        // Strictly check for moderator role only (do NOT include admin or host)
        if (role == 'moderator' ||
            role == 'mod' ||
            userField == 'moderator' ||
            userField == 'mod' ||
            isM) {
          isMod = true;
        }
      }

      if (mounted && _isCurrentModerator != isMod) {
        setState(() {
          _isCurrentModerator = isMod;
        });
      }

      // 2. Listen to real-time changes on the user's document
      _userDocSubscription?.cancel();
      _userDocSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots()
          .listen((snapshot) {
        if (!mounted || !snapshot.exists) return;
        final data = snapshot.data() ?? {};
        final role = data['role']?.toString().toLowerCase().trim() ?? '';
        final userField = data['user']?.toString().toLowerCase().trim() ?? '';
        final isM = data['isModerator'] == true || data['ismoderator'] == true;
        final bool modNow = (role == 'moderator' ||
            role == 'mod' ||
            userField == 'moderator' ||
            userField == 'mod' ||
            isM);
        if (mounted && _isCurrentModerator != modNow) {
          setState(() {
            _isCurrentModerator = modNow;
          });
        }
      });
    } catch (e) {
      debugPrint('Error checking moderator status: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isJoined = widget.isHost;
    _musicPlayerManager = MusicPlayerManager();
    _isSpeakerMuted = StreamingService.instance.isSpeakerMuted;

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
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 1.2,
      ),
      TweenSequenceItem(
        tween: ConstantTween<Offset>(const Offset(0.0, 0.0)),
        weight: 2.6,
      ),
      TweenSequenceItem(
        tween: Tween<Offset>(
          begin: const Offset(0.0, 0.0),
          end: const Offset(-1.5, 0.0),
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 1.2,
      ),
    ]).animate(_joinAnimationController);

    // Chat Focus Listeners
    _chatFocusNode.addListener(_updateChatExpansion);
    _chatController.addListener(_updateChatExpansion);

    // Initialize chat stream and restore previous comments from history
    _initChat();

    WakelockPlus.enable();
    _checkModeratorStatus();
    _initialize();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
    );
  }

  void _initChat() {
    // 1. Immediately restore messages from StreamingService history if available
    _syncMessagesFromHistory();

    // 2. Set up listener for real-time messages from stream
    _messageSubscription?.cancel();
    _messageSubscription = StreamingService.instance.chatMessagesStream.listen((
      message,
    ) {
      if (!mounted) return;
      if (message.userLevel != null && message.userLevel! > 0) {
        _userLevelCache[message.userId] = message.userLevel!;
      }
      _addChatMessageToUI(
        ChatMessage(
          id: message.id,
          userId: message.userId,
          username: message.userName,
          message: message.message,
          timestamp: message.timestamp,
          isGiftMessage: message.isGiftMessage,
          giftValue: message.giftValue,
          userLevel: message.userLevel,
        ),
      );
    });

    // 3. Query Firebase Realtime Database in background to ensure all previous comments are loaded
    StreamingService.instance
        .fetchPastComments(widget.roomID, isVideo: true)
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
      final bool alreadyExists = _messages.any(
        (existing) =>
            (existing.id != null && m.id.isNotEmpty && existing.id == m.id) ||
            (existing.userId == m.userId &&
                existing.message == m.message &&
                existing.timestamp.difference(m.timestamp).abs().inSeconds < 4),
      );

      if (!alreadyExists) {
        if (m.userLevel != null && m.userLevel! > 0) {
          _userLevelCache[m.userId] = m.userLevel!;
        }
        _messages.add(
          ChatMessage(
            id: m.id,
            userId: m.userId,
            username: m.userName,
            message: m.message,
            timestamp: m.timestamp,
            isGiftMessage: m.isGiftMessage,
            giftValue: m.giftValue,
            userLevel: m.userLevel,
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
    final bool alreadyExists = _messages.any(
      (m) =>
          (m.id != null && newMsg.id != null && m.id == newMsg.id) ||
          (m.userId == newMsg.userId &&
              m.message == newMsg.message &&
              m.timestamp.difference(newMsg.timestamp).abs().inSeconds < 4),
    );

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
    _callInviteSubscription?.cancel();
    _commentsEnabledSubscription?.cancel();
    _userDocSubscription?.cancel();
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

    WidgetsBinding.instance.removeObserver(this);

    final bool isMinimizingNow = _isMinimizing;

    if (!isMinimizingNow) {
      try {
        context.read<AppCubit>().closeMinimizedRoom();
      } catch (_) {}
      if (widget.isHost) {
        if (_isPKMode && _pkState.containsKey('opponentRoomId')) {
          LiveStreamService.endPKBattle(
            widget.roomID,
            _pkState['opponentRoomId'],
          );

          String opponentHostId = _pkState['opponentHostId'] ?? '';
          if (opponentHostId.isNotEmpty) {
            StreamingService.instance.disconnectOpponentPKRoom();
          }
        }
        LiveStreamService.deleteRoom(widget.roomID);
      } else {
        LiveStreamService.leaveRoom(widget.roomID);
      }
      StreamingService.instance.disconnect();
    } else {
      StreamingService.instance.pauseCameraForMinimize();
    }
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      StreamingService.instance.pauseCameraForMinimize();
      LiveStreamService.pausePresence(widget.roomID, widget.isHost);
    } else if (state == AppLifecycleState.resumed) {
      final uid = _auth.currentUser?.uid;
      LiveStreamParticipant? me;
      if (uid != null) {
        try {
          me = _participants.firstWhere((p) => p.userId == uid);
        } catch (_) {}
      }

      final bool shouldCameraBeOn = me != null
          ? me.isCameraOn
          : StreamingService.instance.isCameraOn;

      if (shouldCameraBeOn) {
        StreamingService.instance.resumeCameraFromMinimize(
          isHost: widget.isHost,
        );
      } else {
        StreamingService.instance.setCameraEnabled(false);
      }

      if (uid != null) {
        LiveStreamService.resumePresence(
          widget.roomID,
          uid,
          isHost: widget.isHost,
        );
      }
    }
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

      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await _checkModeratorStatus();
      }

      final bool isLocked = roomData['isLocked'] ?? false;
      if (isLocked && !widget.isHost && !_isCurrentModerator) {
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

      _musicPlayerManager.initialize(widget.roomID);
      await _finishInitialization();
    } catch (e) {
      debugPrint('Error initializing live stream: $e');
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
    final currentUser = _auth.currentUser!;
    try {
      final userDoc = await ProfileService.getUserProfile(currentUser.uid);
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _currentUserName = data['displayName'] ?? "Unknown";
          final dynamic totalSentRaw = data['totalSent'];
          final int totalSent = totalSentRaw is num
              ? totalSentRaw.toInt()
              : (int.tryParse(totalSentRaw?.toString() ?? '0') ?? 0);
          int lvl = 1;
          if (data['userLevel'] is num) {
            lvl = (data['userLevel'] as num).toInt();
          } else if (data['level'] is num) {
            lvl = (data['level'] as num).toInt();
          } else {
            lvl = getSentLevel(totalSent);
          }
          if (lvl <= 0) lvl = 1;
          _userLevelCache[currentUser.uid] = lvl;
          if (data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty) {
            _userPictureCache[currentUser.uid] = data['photoUrl'];
          }
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

    // Check existing participant data in RTDB to preserve camera state if re-entering/resuming
    bool? existingCameraState;
    try {
      final pSnap = await LiveStreamService.getRoomParticipant(
        widget.roomID,
        currentUser.uid,
      );
      if (pSnap.exists && pSnap.value is Map) {
        final pMap = Map<dynamic, dynamic>.from(pSnap.value as Map);
        if (pMap.containsKey('isCameraOn')) {
          existingCameraState = pMap['isCameraOn'] == true;
        }
      }
    } catch (e) {
      debugPrint('Error getting existing participant camera state: $e');
    }

    final bool isResuming =
        (StreamingService.instance.currentRoomName == widget.roomID);

    await StreamingService.instance.connectRoom(
      roomName: widget.roomID,
      userId: currentUser.uid,
      userName: _currentUserName,
      role: widget.isHost ? 'HOST' : 'PARTICIPANT',
      isVideo: true,
      isHost: widget.isHost,
      initialCameraOn: existingCameraState,
    );
    _syncMessagesFromHistory();

    if (widget.isHost) {
      if (!isResuming && existingCameraState == null) {
        await LiveStreamService.toggleCameraState(widget.roomID, true);
        await StreamingService.instance.setCameraEnabled(true);
      } else {
        final bool targetCameraOn =
            existingCameraState ?? StreamingService.instance.isCameraOn;
        if (targetCameraOn) {
          await StreamingService.instance.resumeCameraFromMinimize(
            isHost: true,
          );
        } else {
          await StreamingService.instance.setCameraEnabled(false);
        }
      }
    } else {
      await LiveStreamService.joinRoom(widget.roomID);
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
            if (key.contains('entry') ||
                key.contains('ride') ||
                key.contains('vehicle')) {
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
        _showJoinAnimation(
          _currentUserName,
          currentUser.photoURL,
          currentUser.uid,
          idEntryUrl: idEntryUrl,
        );
      }
    }

    _setupListeners();

    if (widget.isHost) {
      try {
        final currentBg = roomData['backgroundUrl'] as String?;
        if (currentBg == null || currentBg.isEmpty) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          if (userDoc.exists) {
            final uData = userDoc.data() as Map<String, dynamic>;
            String? activeBg;
            if (uData.containsKey('activeAddOns')) {
              final addOns =
                  uData['activeAddOns'] as Map<String, dynamic>? ?? {};
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
              await LiveStreamService.updateRoomBackground(
                widget.roomID,
                activeBg,
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Error syncing room screen on live room init: $e");
      }
    }

    if (durationTimer == null) {
      startDurationTracking();
    }

    setState(() => _isInitialized = true);
  }

  int? _roomStartTimestamp;

  int _extractRoomStartTime() {
    final raw = roomData['createdAt'];
    if (raw is num) return raw.toInt();
    if (raw is Timestamp) return raw.millisecondsSinceEpoch;
    if (raw is String) {
      final dt = DateTime.tryParse(raw);
      if (dt != null) return dt.millisecondsSinceEpoch;
      final n = num.tryParse(raw);
      if (n != null) return n.toInt();
    }
    return 0;
  }

  void startDurationTracking() {
    final extracted = _extractRoomStartTime();
    if (extracted > 0) {
      _roomStartTimestamp = extracted;
    } else if (_roomStartTimestamp == null || _roomStartTimestamp == 0) {
      _roomStartTimestamp = DateTime.now().millisecondsSinceEpoch;
    }

    final initialElapsed = math.max(
      0,
      DateTime.now().millisecondsSinceEpoch - _roomStartTimestamp!,
    );
    _currentDuration.value = Duration(milliseconds: initialElapsed);

    durationTimer?.cancel();
    durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final latestCreated = _extractRoomStartTime();
      if (latestCreated > 0 && latestCreated != _roomStartTimestamp) {
        _roomStartTimestamp = latestCreated;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = math.max(0, now - _roomStartTimestamp!);
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

    // Everyone (hosts and viewers) must pull the opponent's stream to see them
    String opponentRoomId = newPKState['opponentRoomId'] ?? '';
    String opponentHostId = newPKState['opponentHostId'] ?? '';
    if (opponentRoomId.isNotEmpty && opponentHostId.isNotEmpty) {
      debugPrint(
        "Starting to play opponent's stream: $opponentHostId from room $opponentRoomId",
      );
      StreamingService.instance.connectOpponentPKRoom(
        opponentRoomId: opponentRoomId,
        opponentHostId: opponentHostId,
      );
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

    setState(() {
      _isPKMode = true;
      _isStartingPKAnimation = true;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isStartingPKAnimation = false;
        });
      }
    });
  }

  void _showJoinAnimation(
    String userName,
    String? userPicture,
    String userId, {
    String? idEntryUrl,
  }) {
    _joinAnimationTimer?.cancel();
    _joinAnimationController.forward(from: 0.0);
    setState(() {
      _newJoinerName = userName;
      _newJoinerPicture = userPicture;
      _newJoinerId = userId;
      _newJoinerIdEntryUrl = idEntryUrl;
    });

    bool isSvga =
        idEntryUrl != null && idEntryUrl.toLowerCase().endsWith('.svga');
    if (!isSvga) {
      _joinAnimationTimer = Timer(welcomeTime, () {
        if (mounted) {
          setState(() {
            _newJoinerName = null;
            _newJoinerPicture = null;
            _newJoinerId = null;
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
        _newJoinerPicture = null;
        _newJoinerId = null;
        _newJoinerIdEntryUrl = null;
      });
    }
  }

  Widget _buildJoinAnimationOverlay() {
    return Visibility(
      visible: _newJoinerName != null,
      child: IgnorePointer(
        child: SlideTransition(
          position: _joinAnimationOffset,
          child:
              _newJoinerIdEntryUrl != null && _newJoinerIdEntryUrl!.isNotEmpty
              ? Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.transparent,
                  child: Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
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
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                "assets/animations/id_entry.gif",
                                fit: BoxFit.cover,
                              ),
                        ),
                      // Floating luxury badge at the bottom of the animation
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(left: 12, bottom: 80),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xE61A0A0A),
                                Color(0xE64A148C),
                                Color(0xE6880E4F),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: const Color(
                                0xFFFFD700,
                              ).withValues(alpha: 0.9),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFD700,
                                ).withValues(alpha: 0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Avatar + ActiveFrame
                              SizedBox(
                                width: 42,
                                height: 42,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFFFD700),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child:
                                            _newJoinerPicture != null &&
                                                _newJoinerPicture!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: _newJoinerPicture!,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    const Icon(
                                                      Icons.person,
                                                      color: Colors.white,
                                                      size: 22,
                                                    ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(
                                                          Icons.person,
                                                          color: Colors.white,
                                                          size: 22,
                                                        ),
                                              )
                                            : const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                      ),
                                    ),
                                    if (_newJoinerId != null)
                                      Positioned(
                                        width: 54.6,
                                        height: 54.6,
                                        child: IgnorePointer(
                                          child: ActiveFrameWidget(
                                            userId: _newJoinerId!,
                                            size: 54.6,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _newJoinerName ?? '',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            shadows: [
                                              BoxShadow(
                                                color: Colors.black87,
                                                blurRadius: 4,
                                                offset: Offset(0, 1),
                                              ),
                                            ],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          Icons.military_tech,
                                          color: Color(0xFFFFD700),
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                    const Text(
                                      'Arrived with luxury ride! ✨',
                                      style: TextStyle(
                                        color: Color(0xFFFFE082),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(left: 12, bottom: 80),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xE61A0A0A),
                          Color(0xE64A148C),
                          Color(0xE6880E4F),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: const Color(0xFFFFD700).withValues(alpha: 0.85),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Avatar with Frame
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFFD700),
                                    width: 1.5,
                                  ),
                                ),
                                child: ClipOval(
                                  child:
                                      _newJoinerPicture != null &&
                                          _newJoinerPicture!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: _newJoinerPicture!,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 20,
                                              ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                ),
                              ),
                              if (_newJoinerId != null)
                                Positioned(
                                  width: 52,
                                  height: 52,
                                  child: IgnorePointer(
                                    child: ActiveFrameWidget(
                                      userId: _newJoinerId!,
                                      size: 52,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _newJoinerName ?? '',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      shadows: [
                                        BoxShadow(
                                          color: Colors.black87,
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.auto_awesome,
                                    color: Color(0xFFFFD700),
                                    size: 14,
                                  ),
                                ],
                              ),
                              const Text(
                                'Entered the live room ✨',
                                style: TextStyle(
                                  color: Color(0xFFFFE082),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
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

        if (durationTimer == null) {
          startDurationTracking();
        } else {
          final latestCreated = _extractRoomStartTime();
          if (latestCreated > 0 && latestCreated != _roomStartTimestamp) {
            _roomStartTimestamp = latestCreated;
          }
        }

        final newPKState = data['pkState'] != null
            ? Map<String, dynamic>.from(data['pkState'] as Map)
            : <String, dynamic>{'isPK': false};

        final bool isNowInPK = newPKState['isPK'] == true;

        if (isNowInPK) {
          if (newPKState['scores'] != null && newPKState['scores'] is Map) {
            final scores = Map<dynamic, dynamic>.from(
              newPKState['scores'] as Map,
            );
            setState(() {
              _pkScoreBlue = (scores['blue'] as num? ?? 0).toInt();
              _pkScoreRed = (scores['red'] as num? ?? 0).toInt();
            });
          }
          if (!_isPKMode && !_isStartingPKAnimation) {
            _startPKBattleSequence(newPKState);
          }
        } else if (!isNowInPK && _isPKMode) {
          debugPrint("PK Mode ENDING");

          StreamingService.instance.disconnectOpponentPKRoom();

          _opponentParticipantsSubscription?.cancel();
          _pkTimer?.cancel();

          setState(() {
            _isPKMode = false;
            _pkState = {};
            _opponentParticipants = [];
            _pkTimerDisplay = "00:00";
            _pkScoreBlue = 0;
            _pkScoreRed = 0;
          });
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

    _participantsSubscription = LiveStreamService.getRoomParticipants(widget.roomID).listen((
      event,
    ) {
      if (!event.snapshot.exists) {
        if (mounted) setState(() => _participants = []);
        return;
      }
      final participantsMap = Map<dynamic, dynamic>.from(
        event.snapshot.value as Map,
      );
      final newParticipants = participantsMap.entries
          .map(
            (entry) => LiveStreamParticipant.fromRTDB(entry.key, entry.value),
          )
          .toList();

      for (final p in newParticipants) {
        if (p.vipType != null && p.vipType!.isNotEmpty) {
          VipService.setVipType(p.userId, p.vipType);
        } else {
          VipService.getVipType(p.userId).then((res) {
            if (res != null && mounted) setState(() {});
          });
        }
      }

      if (_participants.isNotEmpty && _newJoinerName == null) {
        final oldParticipantIds = _participants.map((p) => p.userId).toSet();
        final String hostId = _isInitialized ? (roomData['hostId'] ?? '') : '';

        final newGuests = newParticipants
            .where(
              (p) =>
                  !oldParticipantIds.contains(p.userId) &&
                  p.userId != hostId &&
                  !p.isModerator,
            )
            .toList();

        if (newGuests.isNotEmpty) {
          _showJoinAnimation(
            newGuests.first.userName,
            newGuests.first.userPicture,
            newGuests.first.userId,
            idEntryUrl: newGuests.first.idEntryUrl,
          );
        }
      }

      final currentUser = _auth.currentUser!;
      final myParticipant = newParticipants.firstWhere(
        (p) => p.userId == currentUser.uid,
        orElse: () => LiveStreamParticipant(
          userId: '',
          userName: '',
          isMuted: true,
          isCameraOn: false,
          isOnSeat: false,
        ),
      );

      if (myParticipant.userId.isNotEmpty && myParticipant.isModerator) {
        if (!_isCurrentModerator && mounted) {
          setState(() {
            _isCurrentModerator = true;
          });
        }
      }

      // Only treat as kicked if the user was PREVIOUSLY confirmed in _participants
      // and we are not currently minimizing/minimized
      final bool wasAlreadyInRoom = _participants.any(
        (p) => p.userId == currentUser.uid,
      );
      final bool isMinimizingNow =
          _isMinimizing ||
          (mounted &&
              context.read<AppCubit>().state.minimizedRoom?.roomId ==
                  widget.roomID);

      if (wasAlreadyInRoom &&
          myParticipant.userId.isEmpty &&
          !widget.isHost &&
          !_isCurrentModerator &&
          !isMinimizingNow &&
          !_isRoomEnded) {
        // We were kicked!
        if (mounted) {
          _handleKicked();
        }
        return;
      }

      // Handle remote mute/unmute and camera off when demoted or seat changes
      if (myParticipant.userId.isNotEmpty && _participants.isNotEmpty) {
        final oldMe = _participants.firstWhere(
          (p) => p.userId == currentUser.uid,
          orElse: () => myParticipant,
        );
        if (myParticipant.isMuted != oldMe.isMuted) {
          StreamingService.instance.setMicrophoneEnabled(
            !myParticipant.isMuted,
          );
        }
        if (!myParticipant.isCameraOn && oldMe.isCameraOn) {
          StreamingService.instance.setCameraEnabled(false);
        }
      }

      final isNowJoined = myParticipant.isOnSeat;

      if (!widget.isHost && isNowJoined && !_isJoined) {
        debugPrint(
          "Guest seat joined/restored! Call type: ${myParticipant.callType}, isCameraOn: ${myParticipant.isCameraOn}",
        );
        StreamingService.instance.setMicrophoneEnabled(!myParticipant.isMuted);
        if (myParticipant.callType == 'video' && myParticipant.isCameraOn) {
          Permission.camera.request().then((status) {
            if (status.isGranted) {
              StreamingService.instance.setCameraEnabled(true);
              LiveStreamService.toggleCameraState(widget.roomID, true);
            }
          });
        } else {
          StreamingService.instance.setCameraEnabled(false);
          LiveStreamService.toggleCameraState(widget.roomID, false);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                myParticipant.callType == 'video'
                    ? 'Host accepted your request! You are live on Video Call.'
                    : 'Host accepted your request! You are live on Audio Call.',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (!widget.isHost && !isNowJoined && _isJoined) {
        debugPrint("Demoted from seat or left seat. Turning off mic & camera.");
        StreamingService.instance.setMicrophoneEnabled(false);
        StreamingService.instance.setCameraEnabled(false);
      }

      if (mounted) {
        setState(() {
          _participants = newParticipants;
          _isJoined = isNowJoined;
          _localMuteOverride = null;
        });
      }
    });

    _commentsEnabledSubscription =
        LiveStreamService.getCommentsEnabledStream(widget.roomID).listen((
          event,
        ) {
          if (!mounted ||
              !event.snapshot.exists ||
              event.snapshot.value == null)
            return;
          final enabled = event.snapshot.value as bool? ?? true;
          if (_isCommentsEnabled != enabled) {
            setState(() {
              _isCommentsEnabled = enabled;
            });
          }
        });

    _emojiSubscription = LiveStreamService.getEmojiStream(widget.roomID).listen(
      (event) {
        if (!mounted ||
            !event.snapshot.exists ||
            event.snapshot.value == null) {
          return;
        }

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
      if (!mounted || !event.snapshot.exists || event.snapshot.value == null) {
        return;
      }

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

            final giftChatMsg = ChatMessage(
              userId: data['senderId'] ?? '',
              username: senderName,
              message: giftMessageText,
              timestamp: DateTime.now(),
              isGiftMessage: true,
              // Triggers the UI below
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
          senderName: senderName,
          senderPicture: data['senderPicture'],
          giftAnimationUrl: data['giftAnimationUrl'] ?? '',
          giftImageUrl: data['giftImageUrl'] ?? '',
          isLuckyGift: isLuckyGift,
          hitCount: hitCount,
          senderId: data['senderId'],
          durationSec: data['duration'] as int?,
        );

        if (_isPKMode &&
            _pkState.containsKey('opponentRoomId') &&
            giftValue > 0) {
          final isBlue = (_pkState['role'] == 'sender');
          LiveStreamService.addPKPoints(
            widget.roomID,
            _pkState['opponentRoomId'],
            giftValue,
            isBlueTeam: isBlue,
          );
        }
      }
    });

    _joinRequestsSubscription =
        LiveStreamService.getJoinRequestsStream(widget.roomID).listen((event) {
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

    if (widget.isHost) {
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

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId != null && !widget.isHost) {
      _callInviteSubscription =
          LiveStreamService.getCallInviteStream(
            widget.roomID,
            currentUserId,
          ).listen((event) {
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
              child: const Icon(
                Icons.phone_in_talk,
                color: Colors.greenAccent,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Call Invitation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          '$hostName invited you to join the live call!',
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              _isCallInviteDialogShowing = false;
              await LiveStreamService.rejectCallInvite(widget.roomID, myUserId);
            },
            child: const Text(
              'Decline',
              style: TextStyle(color: Colors.redAccent, fontSize: 15),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.call, color: Colors.white, size: 18),
            label: const Text(
              'Accept Call',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              _isCallInviteDialogShowing = false;
              try {
                await LiveStreamService.acceptCallInvite(
                  widget.roomID,
                  myUserId,
                );
                await StreamingService.instance.setMicrophoneEnabled(true);
                if (mounted) {
                  setState(() {
                    _isJoined = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Joined call successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error joining call: $e'),
                      backgroundColor: Colors.red,
                    ),
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
        if (_isPKMode && !_isPKResultShowing) {
          _showPKResultDialog();
        }
      } else {
        setState(() {
          _pkTimerDisplay = _formatDuration(remaining);
        });
      }
    });
  }

  void _showPKResultDialog() {
    if (_isPKResultShowing || !mounted) return;
    _isPKResultShowing = true;

    final isSender = (_pkState['role'] == 'sender');
    final myScore = isSender ? _pkScoreBlue : _pkScoreRed;
    final opponentScore = isSender ? _pkScoreRed : _pkScoreBlue;
    final bool isWinner = myScore > opponentScore;
    final bool isTie = myScore == opponentScore;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isWinner
                    ? [
                        const Color(0xFF1B5E20),
                        const Color(0xFF2E7D32),
                        const Color(0xFF388E3C),
                      ]
                    : isTie
                    ? [const Color(0xFF37474F), const Color(0xFF455A64)]
                    : [
                        const Color(0xFFB71C1C),
                        const Color(0xFFC62828),
                        const Color(0xFFD32F2F),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isWinner ? const Color(0xFFFFD700) : Colors.white24,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isWinner ? Colors.amber : Colors.red).withValues(
                    alpha: 0.5,
                  ),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isWinner
                      ? Icons.emoji_events_rounded
                      : isTie
                      ? Icons.handshake_rounded
                      : Icons.sentiment_dissatisfied_rounded,
                  color: isWinner ? const Color(0xFFFFD700) : Colors.white,
                  size: 64,
                ),
                const SizedBox(height: 12),
                Text(
                  isWinner
                      ? 'VICTORY!'
                      : isTie
                      ? 'DRAW!'
                      : 'DEFEAT',
                  style: TextStyle(
                    color: isWinner ? const Color(0xFFFFD700) : Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isWinner
                      ? 'Congratulations! You won the PK battle!'
                      : isTie
                      ? 'It is a tie! Both hosts fought well!'
                      : 'Better luck next time!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'Blue Team',
                            style: TextStyle(
                              color: Colors.blueAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_pkScoreBlue',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      Column(
                        children: [
                          const Text(
                            'Red Team',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_pkScoreRed',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (widget.isHost && _isPKMode) {
                      LiveStreamService.endPKBattle(
                        widget.roomID,
                        _pkState['opponentRoomId'] ?? '',
                      );
                    }
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      _isPKResultShowing = false;
    });

    // Auto dismiss after 6 seconds if not manually closed
    Future.delayed(const Duration(seconds: 6), () {
      if (_isPKResultShowing && mounted) {
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        if (widget.isHost && _isPKMode) {
          LiveStreamService.endPKBattle(
            widget.roomID,
            _pkState['opponentRoomId'] ?? '',
          );
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
                      StreamingService.instance.connectOpponentPKRoom(
                        opponentRoomId: invite.senderRoomId,
                        opponentHostId: invite.senderHostId,
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
              StreamingService.instance.connectOpponentPKRoom(
                opponentRoomId: invite.senderRoomId,
                opponentHostId: invite.senderHostId,
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

  void _showEndPKConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b2b),
        title: const Text(
          'End PK Battle',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to end the current PK battle?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(context);
              LiveStreamService.endPKBattle(
                widget.roomID,
                _pkState['opponentRoomId'] ?? '',
              );
            },
            child: const Text(
              'End Battle',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showExitConfirmationDialog() async {
    final currentUserId = _auth.currentUser!.uid;
    final myParticipant = _participants.firstWhere(
      (p) => p.userId == currentUserId,
      orElse: () => LiveStreamParticipant(
        userId: '',
        userName: '',
        isOnSeat: false,
        isMuted: true,
        isCameraOn: false,
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
                    StreamingService.instance.pauseCameraForMinimize();
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
                    Navigator.of(context).pop(false);
                    _exitAndEndLiveRoom();
                  },
                ),
                if (!widget.isHost && _isCurrentModerator) ...[
                  const SizedBox(height: 24),
                  _buildExitDialogOption(
                    icon: Icons.close_rounded,
                    color: Colors.red.shade900,
                    label: 'Close Live',
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
        _exitAndEndLiveRoom();
      }
      return shouldExit;
    });
  }

  Future<void> _exitAndEndLiveRoom() async {
    _isMinimizing = false;
    _isRoomEnded = true;

    try {
      if (mounted) {
        context.read<AppCubit>().closeMinimizedRoom();
      }
    } catch (_) {}

    try {
      if (widget.isHost) {
        if (_isPKMode && _pkState.containsKey('opponentRoomId')) {
          try {
            await LiveStreamService.endPKBattle(
              widget.roomID,
              _pkState['opponentRoomId'],
            );
          } catch (e) {
            debugPrint("Error ending PK battle: $e");
          }

          try {
            final String opponentHostId = _pkState['opponentHostId'] ?? '';
            if (opponentHostId.isNotEmpty) {
              await StreamingService.instance.disconnectOpponentPKRoom();
            }
          } catch (e) {
            debugPrint("Error disconnecting opponent PK room: $e");
          }
        }
        await LiveStreamService.deleteRoom(widget.roomID);
      } else {
        final uid = _auth.currentUser?.uid;
        if (uid != null) {
          try {
            await LiveStreamService.leaveCall(widget.roomID, uid);
          } catch (_) {}
        }
        await LiveStreamService.leaveRoom(widget.roomID);
      }
    } catch (e) {
      debugPrint("Error exiting live room: $e");
    }

    try {
      await StreamingService.instance.disconnect();
    } catch (e) {
      debugPrint("Error disconnecting streaming service: $e");
    }

    try {
      await WakelockPlus.disable();
    } catch (_) {}

    try {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
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
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
            SizedBox(width: 8),
            Text(
              'Close Live Stream',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: const Text(
          'As a moderator, are you sure you want to force close this live stream? The broadcast will be terminated for all participants and viewers.',
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Close Live',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        _isMinimizing = false;
        _isRoomEnded = true;

        try {
          if (mounted) {
            context.read<AppCubit>().closeMinimizedRoom();
          }
        } catch (_) {}

        if (_isPKMode && _pkState.containsKey('opponentRoomId')) {
          try {
            await LiveStreamService.endPKBattle(
              widget.roomID,
              _pkState['opponentRoomId'],
            );
          } catch (e) {
            debugPrint("Error ending PK battle: $e");
          }

          try {
            final String opponentHostId = _pkState['opponentHostId'] ?? '';
            if (opponentHostId.isNotEmpty) {
              await StreamingService.instance.disconnectOpponentPKRoom();
            }
          } catch (e) {
            debugPrint("Error disconnecting opponent PK room: $e");
          }
        }

        await LiveStreamService.deleteRoom(widget.roomID);

        try {
          await StreamingService.instance.disconnect();
        } catch (e) {
          debugPrint("Error disconnecting streaming service: $e");
        }

        try {
          await WakelockPlus.disable();
        } catch (_) {}

        try {
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values,
          );
        } catch (_) {}

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Live stream closed by moderator.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          context.go(Routes.home.path);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error closing live: $e'),
              backgroundColor: Colors.red,
            ),
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
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  // 1. Global Room Theme / Skin Background
                  Positioned.fill(
                    child:
                        roomData['backgroundUrl'] != null &&
                            (roomData['backgroundUrl'] as String).isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: roomData['backgroundUrl'] as String,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const SizedBox.shrink(),
                            errorWidget: (context, url, error) =>
                                const SizedBox.shrink(),
                          )
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF28073D),
                                  Color(0xFF16032B),
                                  Color(0xFF0D011A),
                                ],
                              ),
                            ),
                          ),
                  ),
                  // 2. Full-Screen Host Video (when single host and NOT in PK mode)
                  if (!_isPKMode && _isInitialized)
                    _buildBackgroundVideoIfSingleHost(),

                  if (_isInitialized)
                    _isPKMode
                        ? _buildPKModeLayout()
                        : _buildStandardModeOverlay()
                  else
                    const Center(
                      child: CircularProgressIndicator(color: Colors.pink),
                    ),
                  Visibility(
                    visible: _isStartingPKAnimation,
                    child: _buildPKStartingAnimation(),
                  ),
                  Center(child: _buildJoinAnimationOverlay()),
                  _buildFullScreenGift(),
                  _buildGiftOverlay(),

                  if (_isInitialized && !_isChatExpanded) _buildRightToolbar(),
                  if (_isInitialized) _buildFloatingEmojis(),
                  if (_isInitialized)
                    FloatingYoutubePlayer(
                      roomId: widget.roomID,
                      isHost: widget.isHost,
                    ),
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
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildChatSection(),
              _buildJoinCallOverlay(),
              if (_isCommentsHidden) _buildShowCommentsButton(),
            ],
          ),
        ),
        _buildChatInput(),
      ],
    );
  }

  Widget _buildStandardModeOverlay() {
    final String hostId = roomData['hostId'] ?? '';
    final seatedGuests = _participants
        .where((p) => p.isOnSeat && p.userId != hostId)
        .toList();
    final bool isSingleHost = seatedGuests.isEmpty;

    final mediaQuery = MediaQuery.of(context);
    final double safeBottom = math.max(
      mediaQuery.padding.bottom,
      mediaQuery.viewPadding.bottom,
    );
    final double bottomPadding = mediaQuery.viewInsets.bottom > 0
        ? 10.0 + mediaQuery.viewInsets.bottom
        : math.max(26.0, 12.0 + safeBottom);
    final double chatBottomMargin = 50.0 + bottomPadding;

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              _buildAppBar(),
              _buildHostStatsRow(),
              if (!isSingleHost)
                _buildDynamicVideoGrid()
              else
                SizedBox(height: mediaQuery.size.height * 0.38),
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(bottom: chatBottomMargin),
                  child: Stack(
                    fit: StackFit.expand,
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
        ),
        Positioned(bottom: 0, left: 0, right: 0, child: _buildChatInput()),
      ],
    );
  }

  Widget _buildAppBar() {
    if (!_isInitialized) return const SizedBox.shrink();
    final String hostId = roomData['hostId'] ?? '';
    final String currentUserId = _auth.currentUser?.uid ?? '';

    // ADD THIS: Check if the current user is a guest (not the host)
    final bool isGuest = !widget.isHost && hostId != currentUserId;

    // Filter out the host and moderators to get the list of visible guests
    final guestParticipants = _participants
        .where((p) => p.userId != hostId && !p.isModerator)
        .toList();

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).viewPadding.top),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12.0, 8.0, 12.0, 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Host Info Section with clean capsule background
            GestureDetector(
              onTap: () {
                if (hostId == currentUserId) return;
                showProfileInfoBottomSheet(
                  context,
                  userId: hostId,
                  hostId: hostId,
                  roomId: widget.roomID,
                );
              },
              child: Container(
                height: 40,
                padding: const EdgeInsets.fromLTRB(3, 3, 8, 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VipAvatarWidget(
                      userId: hostId,
                      userPicture: roomData['hostPicture'],
                      avatarSize: 28,
                      frameScale: 1.45,
                      directVipType: roomData['vipType'] ?? roomData['vip'],
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        maxWidth: 140,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isPKMode)
                                Container(
                                  margin: const EdgeInsets.only(right: 3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: const Text(
                                    'PK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Flexible(
                                child: Text(
                                  (roomData["hostName"] != null &&
                                          (roomData["hostName"] as String)
                                              .isNotEmpty)
                                      ? roomData["hostName"]
                                      : 'Host',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ValueListenableBuilder<Duration>(
                                valueListenable: _currentDuration,
                                builder: (context, duration, child) {
                                  final hours = duration.inHours;
                                  final minutes = (duration.inMinutes % 60)
                                      .toString()
                                      .padLeft(2, '0');
                                  final seconds = (duration.inSeconds % 60)
                                      .toString()
                                      .padLeft(2, '0');
                                  final timeStr = hours > 0
                                      ? '${hours.toString().padLeft(2, "0")}:$minutes:$seconds'
                                      : '$minutes:$seconds';
                                  return Text(
                                    timeStr,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 9.0,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              StreamBuilder<int>(
                                stream: _diamondsStreamCache.putIfAbsent(
                                  hostId,
                                  () => ProfileService.getUserDiamondsStream(hostId),
                                ),
                                builder: (context, snapshot) {
                                  final diamonds = snapshot.data ?? 0;
                                  final viewersCount = guestParticipants.isNotEmpty
                                      ? guestParticipants.length
                                      : (_participantCount > 1
                                          ? _participantCount - 1
                                          : 0);

                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.diamond,
                                        color: Color(0xFFFFD54F),
                                        size: 9.5,
                                      ),
                                      const SizedBox(width: 1.5),
                                      Text(
                                        _formatNumber(diamonds),
                                        style: const TextStyle(
                                          color: Color(0xFFFFD54F),
                                          fontSize: 9.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        CupertinoIcons.person_2_fill,
                                        color: Colors.pinkAccent,
                                        size: 9.0,
                                      ),
                                      const SizedBox(width: 1.5),
                                      Text(
                                        viewersCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

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
                            padding: const EdgeInsets.only(left: 4.0),
                            child: GestureDetector(
                              onTap: () async {
                                try {
                                  await ProfileService.followUser(hostId);
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              child: Container(
                                width: 22,
                                height: 22,
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
            const SizedBox(width: 6),

            // Viewers Avatars Line (Scrollable, takes all middle available space)
            Expanded(
              child: GestureDetector(
                onTap: () => _openCallAndViewsBottomSheet(initialTab: 0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: _buildParticipantAvatars(guestParticipants),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Top-right Speaker Mute/Unmute Button (Image 1 & 2)
            _buildCircleActionButton(
              size: 34,
              onTap: () async {
                final newMute = !_isSpeakerMuted;
                setState(() => _isSpeakerMuted = newMute);
                await StreamingService.instance.setSpeakerMuted(newMute);
              },
              child: Icon(
                _isSpeakerMuted
                    ? CupertinoIcons.speaker_slash_fill
                    : CupertinoIcons.speaker_2_fill,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 6),

            if (!widget.isHost && _isCurrentModerator) ...[
              _buildCircleActionButton(
                size: 38,
                onTap: _showModeratorCloseDialog,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE11D48), Color(0xFF9F1239)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: const Color(0xFFFF4D6D),
                  width: 1.5,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Top-right Exit Button (Image 1 & 2)
            GestureDetector(
              onTap: _showExitConfirmationDialog,
              child: Container(
                margin: const EdgeInsets.only(left: 6, right: 10),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF23032F),
                  border: Border.all(
                    color: const Color(0xFFFF1744),
                    width: 1.8,
                  ),
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
    return const SizedBox(height: 2);
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
                  Expanded(
                    flex: _pkScoreBlue + _pkScoreRed > 0 ? _pkScoreBlue : 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue, Color(0xFF64B5F6)],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: _pkScoreBlue + _pkScoreRed > 0 ? _pkScoreRed : 1,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFE57373), Colors.red],
                        ),
                      ),
                    ),
                  ),
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

  Widget _buildBackgroundVideoIfSingleHost() {
    final String hostId = roomData['hostId'] ?? '';
    final seatedGuests = _participants
        .where((p) => p.isOnSeat && p.userId != hostId)
        .toList();
    if (seatedGuests.isNotEmpty) return const SizedBox.shrink();

    LiveStreamParticipant? host;
    for (final p in _participants) {
      if (p.userId == hostId) {
        host = p;
        break;
      }
    }

    final hostParticipant =
        host ??
        LiveStreamParticipant(
          userId: hostId,
          userName: roomData['hostName'] ?? 'Host',
          userPicture: roomData['hostPicture'],
          isMuted: false,
          isCameraOn: true,
          isOnSeat: true,
          vipType: roomData['vipType'] as String?,
        );

    return Positioned.fill(
      child: _buildParticipantVideo(hostParticipant, isFullScreen: true),
    );
  }

  Widget _buildDynamicVideoGrid() {
    final String hostId = roomData['hostId'] ?? '';
    LiveStreamParticipant? host;
    final List<LiveStreamParticipant> guests = [];

    for (final p in _participants) {
      if (p.userId == hostId) {
        host = p;
      } else if (p.isOnSeat) {
        guests.add(p);
      }
    }

    final hostParticipant =
        host ??
        LiveStreamParticipant(
          userId: hostId,
          userName: roomData['hostName'] ?? 'Host',
          userPicture: roomData['hostPicture'],
          isMuted: false,
          isCameraOn: true,
          isOnSeat: true,
          vipType: roomData['vipType'] as String?,
        );

    final allParticipants = [hostParticipant, ...guests];
    final count = allParticipants.length;

    if (count <= 1) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;

    if (count == 2) {
      return Container(
        height: screenHeight * 0.38,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _buildParticipantVideo(allParticipants[0])),
            const SizedBox(width: 6),
            Expanded(child: _buildParticipantVideo(allParticipants[1])),
          ],
        ),
      );
    } else if (count == 3) {
      return Container(
        height: screenHeight * 0.44,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildParticipantVideo(allParticipants[0])),
                  const SizedBox(width: 6),
                  Expanded(child: _buildParticipantVideo(allParticipants[1])),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildParticipantVideo(allParticipants[2])),
                  const SizedBox(width: 6),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (count == 4) {
      return Container(
        height: screenHeight * 0.44,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildParticipantVideo(allParticipants[0])),
                  const SizedBox(width: 6),
                  Expanded(child: _buildParticipantVideo(allParticipants[1])),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildParticipantVideo(allParticipants[2])),
                  const SizedBox(width: 6),
                  Expanded(child: _buildParticipantVideo(allParticipants[3])),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (count == 5) {
      return Container(
        height: screenHeight * 0.46,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildParticipantVideo(allParticipants[0])),
                  const SizedBox(width: 4),
                  Expanded(child: _buildParticipantVideo(allParticipants[1])),
                  const SizedBox(width: 4),
                  Expanded(child: _buildParticipantVideo(allParticipants[2])),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildParticipantVideo(allParticipants[3])),
                  const SizedBox(width: 4),
                  Expanded(child: _buildParticipantVideo(allParticipants[4])),
                  const SizedBox(width: 4),
                  const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (count == 6) {
      return Container(
        height: screenHeight * 0.46,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildParticipantVideo(allParticipants[0])),
                  const SizedBox(width: 4),
                  Expanded(child: _buildParticipantVideo(allParticipants[1])),
                  const SizedBox(width: 4),
                  Expanded(child: _buildParticipantVideo(allParticipants[2])),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _buildParticipantVideo(allParticipants[3])),
                  const SizedBox(width: 4),
                  Expanded(child: _buildParticipantVideo(allParticipants[4])),
                  const SizedBox(width: 4),
                  Expanded(child: _buildParticipantVideo(allParticipants[5])),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      // 7 or more participants: 3-column rows
      final row1 = allParticipants.take(3).toList();
      final row2 = allParticipants.skip(3).take(3).toList();
      final row3 = allParticipants.skip(6).take(3).toList();
      final row4 = allParticipants.skip(9).take(3).toList();

      return Container(
        height: row4.isNotEmpty ? screenHeight * 0.54 : screenHeight * 0.48,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: i < row1.length
                          ? _buildParticipantVideo(row1[i])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Expanded(
                      child: i < row2.length
                          ? _buildParticipantVideo(row2[i])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
            if (row3.isNotEmpty) ...[
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: i < row3.length
                            ? _buildParticipantVideo(row3[i])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (row4.isNotEmpty) ...[
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 4),
                      Expanded(
                        child: i < row4.length
                            ? _buildParticipantVideo(row4[i])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildParticipantVideo(
    LiveStreamParticipant participant, {
    bool isFullScreen = false,
  }) {
    final String hostId = roomData['hostId'] ?? '';
    final bool isHost = participant.userId == hostId;
    final bool isCurrentUser = participant.userId == _auth.currentUser?.uid;

    final bool isCameraActive = (widget.isHost && isHost && isCurrentUser)
        ? StreamingService.instance.isCameraOn
        : (isCurrentUser
              ? (participant.isCameraOn && StreamingService.instance.isCameraOn)
              : (isHost
                    ? (participant.isCameraOn == true)
                    : participant.isCameraOn));

    final String? userVip =
        participant.vipType ??
        (isHost ? (roomData['vipType'] as String?) : null) ??
        VipService.getVipTypeSync(participant.userId);
    final bool hasVip = userVip != null && userVip.isNotEmpty;
    final bool isVvip = hasVip && userVip.toLowerCase().contains('vvip');

    final String? userPicture =
        participant.userPicture ?? (isHost ? roomData['hostPicture'] : null);
    final String userName = participant.userName.isNotEmpty
        ? participant.userName
        : (isHost ? (roomData['hostName'] ?? 'Host') : 'User');

    Widget content = Stack(
      children: [
        // 1. Live Video Stream (when Camera ON)
        if (isCameraActive)
          Positioned.fill(
            child: (isCurrentUser && widget.isHost)
                ? StreamingService.instance.buildVideoView(
                    participant.userId,
                    fit: BoxFit.cover,
                  )
                : _SafeParticipantVideoWidget(participant: participant),
          ),

        // 2. Avatar with blur background & talking SVGA (when Camera OFF)
        if (!isCameraActive)
          Positioned.fill(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (userPicture != null && userPicture.isNotEmpty)
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                      child: CachedNetworkImage(
                        imageUrl: userPicture,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const SizedBox.shrink(),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: Container(color: Colors.black.withValues(alpha: 0.45)),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final double cardMinSide = math.min(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final double avatarSize = isFullScreen
                        ? 100.0
                        : math.max(36.0, cardMinSide * 0.38);

                    return StreamBuilder<List<String>>(
                      stream: StreamingService.instance.activeSpeakersStream,
                      builder: (context, snapshot) {
                        final isSpeaking =
                            !participant.isMuted &&
                            (snapshot.data ?? []).contains(participant.userId);

                        return Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: avatarSize,
                              height: avatarSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSpeaking
                                      ? const Color(0xFF00E5FF)
                                      : (isHost
                                            ? const Color(0xFFE91E63)
                                            : const Color(0xFF9C27B0)),
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (isSpeaking
                                                ? const Color(0xFF00E5FF)
                                                : (isHost
                                                      ? const Color(0xFFE91E63)
                                                      : const Color(
                                                          0xFF9C27B0,
                                                        )))
                                            .withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child:
                                    (userPicture != null &&
                                        userPicture.isNotEmpty)
                                    ? CachedNetworkImage(
                                        imageUrl: userPicture,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) => const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                          size: 28,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 28,
                                      ),
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
                            if (hasVip)
                              Positioned(
                                top:
                                    (avatarSize - (avatarSize * 1.823)) / 2 -
                                    (avatarSize * 0.1644),
                                left: (avatarSize - (avatarSize * 1.823)) / 2,
                                child: IgnorePointer(
                                  child: Image.asset(
                                    isVvip
                                        ? 'assets/images/vvip.png'
                                        : 'assets/images/vip.png',
                                    width: avatarSize * 1.823,
                                    height: avatarSize * 1.823,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),

        // 3. Name & Diamond balance pill (Bottom-left, if not fullscreen)
        if (!isFullScreen)
          Positioned(
            left: 4,
            bottom: 4,
            right: participant.isMuted ? 28 : 4,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isHost) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 3,
                          vertical: 1,
                        ),
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91E63),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'Host',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    Flexible(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    StreamBuilder<int>(
                      stream: _diamondsStreamCache.putIfAbsent(
                        participant.userId,
                        () => ProfileService.getUserDiamondsStream(participant.userId),
                      ),
                      builder: (context, snapshot) {
                        final diamonds = snapshot.data ?? 0;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.diamond,
                              color: Color(0xFF00E5FF),
                              size: 10,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatNumber(diamonds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (diamonds >= 100000) ...[
                              const SizedBox(width: 2),
                              const Icon(Icons.star, color: Colors.amber, size: 9),
                              Text(
                                '${diamonds ~/ 100000}',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 5. Mic Muted Indicator (Bottom-right, if not fullscreen)
        if (!isFullScreen && participant.isMuted)
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic_off, color: Colors.white, size: 10),
            ),
          ),
      ],
    );

    return GestureDetector(
      onTap: () {
        showProfileInfoBottomSheet(
          context,
          userId: participant.userId,
          hostId: hostId,
          roomId: widget.roomID,
          isSeated: true,
          isCurrentUserAdmin: _participants
              .firstWhere(
                (p) => p.userId == _auth.currentUser!.uid,
                orElse: () => LiveStreamParticipant(
                  userId: '',
                  userName: '',
                  isMuted: false,
                  isCameraOn: false,
                  isOnSeat: false,
                ),
              )
              .isAdmin,
          isCurrentUserModerator: _isCurrentModerator,
        );
      },
      child: Container(
        decoration: isFullScreen
            ? null
            : BoxDecoration(
                color: const Color(0xFF28073D).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isHost
                      ? const Color(0xFFE91E63)
                      : const Color(0xFF9C27B0).withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isHost
                                ? const Color(0xFFE91E63)
                                : const Color(0xFF9C27B0))
                            .withValues(alpha: 0.25),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
        clipBehavior: isFullScreen ? Clip.none : Clip.antiAlias,
        child: ClipRRect(
          borderRadius: isFullScreen
              ? BorderRadius.zero
              : BorderRadius.circular(9),
          child: content,
        ),
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }

  // FIXED: PK Video layout with proper positioning using Row and BoxFit.cover
  Widget _buildPKVideoLayout() {
    return Row(
      children: [
        Expanded(
          child: _buildTeamHost(
            participants: _participants,
            hostId: roomData['hostId'] ?? '',
            hostName: roomData['hostName'] ?? 'Host A',
          ),
        ),
        Expanded(
          child: _buildTeamHost(
            participants: _opponentParticipants,
            hostId: _pkState['opponentHostId'] ?? '',
            hostName: _pkState['opponentHostName'] ?? 'Host B',
          ),
        ),
      ],
    );
  }

  Widget _buildTeamHost({
    required List<LiveStreamParticipant> participants,
    required String hostId,
    required String hostName,
  }) {
    LiveStreamParticipant? host;
    for (final p in participants) {
      if (p.userId == hostId) {
        host = p;
        break;
      }
    }

    if (host == null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text(
            'Waiting for $hostName...',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      );
    }

    return _buildHostVideoForPK(host);
  }

  // FIXED: Host video for PK with BoxFit.cover for no black bars
  Widget _buildHostVideoForPK(LiveStreamParticipant host) {
    final bool isCameraActive =
        (widget.isHost && host.userId == _auth.currentUser?.uid)
        ? (host.isCameraOn && StreamingService.instance.isCameraOn)
        : host.isCameraOn;
    if (isCameraActive) {
      return _SafeParticipantVideoWidget(participant: host);
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

  // Optimized method to get the level badge matching the design in screenshot
  Widget _buildLevelBadge(String userId) {
    if (userId.isNotEmpty && !_userLevelCache.containsKey(userId)) {
      // Fetch level silently and cache it to avoid spamming Firestore reads on scroll
      ProfileService.getUserProfile(userId)
          .then((doc) {
            if (doc.exists && mounted) {
              final data = doc.data() as Map<String, dynamic>;
              final dynamic totalSentRaw = data['totalSent'];
              final int totalSent = totalSentRaw is num
                  ? totalSentRaw.toInt()
                  : (int.tryParse(totalSentRaw?.toString() ?? '0') ?? 0);
              int lvl = 1;
              if (data['userLevel'] is num) {
                lvl = (data['userLevel'] as num).toInt();
              } else if (data['level'] is num) {
                lvl = (data['level'] as num).toInt();
              } else {
                lvl = getSentLevel(totalSent);
              }
              if (lvl <= 0) lvl = 1;

              setState(() {
                _userLevelCache[userId] = lvl;
                if (data['photoUrl'] != null && data['photoUrl'].toString().isNotEmpty) {
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFFA000),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA000), Color(0xFFFF8F00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF8F00).withValues(alpha: 0.35),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        'L.v. $level',
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
          height: 1.1,
        ),
      ),
    );
  }

  Widget _buildChatVipBadge(String userId) {
    final cached = VipService.getVipTypeSync(userId);
    if (cached != null) {
      if (cached == 'vvip') {
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Image.asset(
            'assets/images/VVIP PNG.png',
            height: 20,
            fit: BoxFit.contain,
          ),
        );
      } else if (cached == 'vip') {
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Image.asset(
            'assets/images/VIP PNG.png',
            height: 20,
            fit: BoxFit.contain,
          ),
        );
      }
      return const SizedBox.shrink();
    }

    return FutureBuilder<String?>(
      future: VipService.getVipType(userId),
      builder: (context, snapshot) {
        final vip = snapshot.data;
        if (vip == 'vvip') {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Image.asset(
              'assets/images/VVIP PNG.png',
              height: 20,
              fit: BoxFit.contain,
            ),
          );
        } else if (vip == 'vip') {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Image.asset(
              'assets/images/VIP PNG.png',
              height: 20,
              fit: BoxFit.contain,
            ),
          );
        }
        return const SizedBox.shrink();
      },
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
              Icon(
                CupertinoIcons.chat_bubble_2_fill,
                color: Colors.white,
                size: 14,
              ),
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
            child: Container(
              margin: const EdgeInsets.only(left: 12, right: 64),
              child: ListView.builder(
                reverse: true,
                controller: _chatScrollController,
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.74,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E022A).withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.55),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1.5, right: 6),
                                  child: Icon(
                                    Icons.shield_rounded,
                                    color: Colors.amber,
                                    size: 15,
                                  ),
                                ),
                                Flexible(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        const TextSpan(
                                          text: 'Notice: ',
                                          style: TextStyle(
                                            color: Colors.amber,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              "Any sexual or violation content is strictly prohibited. All violators will be banned.",
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.95),
                                            fontSize: 11,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_roomNotice.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.74,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF28073D).withValues(alpha: 0.88),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.pinkAccent.withValues(alpha: 0.6),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.pink.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(top: 1.5, right: 6),
                                    child: Icon(
                                      Icons.campaign_rounded,
                                      color: Colors.pinkAccent,
                                      size: 16,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _roomNotice,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.25,
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

                  if (m.message == "Just joined the room!") {
                    return GestureDetector(
                      onTap: () {
                        if (m.userId.isNotEmpty) {
                          showProfileInfoBottomSheet(
                            context,
                            userId: m.userId,
                            hostId: roomData['hostId'] ?? '',
                            roomId: widget.roomID,
                          );
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E022A).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.4),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildChatAvatar(m.userId, m.username),
                                _buildLevelBadge(m.userId),
                                _buildChatVipBadge(m.userId),
                                Flexible(
                                  child: Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: '${m.username} ',
                                          style: const TextStyle(
                                            color: Color(0xFFF48FB1),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: 'joined the room',
                                          style: TextStyle(
                                            color: Color(0xFFFFD54F),
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (m.isGiftMessage) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E022A).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.pinkAccent.withValues(alpha: 0.6),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.withValues(alpha: 0.15),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.diamond,
                                color: Colors.cyan,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  m.message,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.pinkAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          if (m.userId.isNotEmpty) {
                            showProfileInfoBottomSheet(
                              context,
                              userId: m.userId,
                              hostId: roomData['hostId'] ?? '',
                              roomId: widget.roomID,
                            );
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1E022A,
                            ).withValues(alpha: 0.90),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(
                                0xFF9C27B0,
                              ).withValues(alpha: 0.75),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF9C27B0,
                                ).withValues(alpha: 0.25),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2, right: 8),
                                child: _buildChatAvatar(m.userId, m.username),
                              ),
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        _buildLevelBadge(m.userId),
                                        _buildChatVipBadge(m.userId),
                                        Flexible(
                                          child: Text(
                                            m.username,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
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
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatAvatar(String userId, String username) {
    final pictureUrl = _userPictureCache[userId];
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
              border: Border.all(
                color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                width: 1.0,
              ),
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
            width: 36,
            height: 36,
            child: IgnorePointer(
              child: ActiveFrameWidget(
                userId: userId,
                size: 36,
              ),
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
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChatInput() {
    const double buttonSize = 40.0;
    const double paddingRight = 8.0;

    final mediaQuery = MediaQuery.of(context);
    final double safeBottom = math.max(
      mediaQuery.padding.bottom,
      mediaQuery.viewPadding.bottom,
    );
    final double bottomPadding = mediaQuery.viewInsets.bottom > 0
        ? 10.0 + mediaQuery.viewInsets.bottom
        : math.max(26.0, 12.0 + safeBottom);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Input pill (Image 1 & 2)
          Expanded(
            child: Container(
              height: 42.0,
              padding: const EdgeInsets.only(left: 14, right: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      focusNode: _chatFocusNode,
                      enabled:
                          _isCommentsEnabled ||
                          widget.isHost ||
                          _isCurrentModerator,
                      textInputAction: TextInputAction.send,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText:
                            (_isCommentsEnabled ||
                                widget.isHost ||
                                _isCurrentModerator)
                            ? 'Say hi'
                            : 'Comments are disabled by host',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 13.5,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
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
                          colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 16,
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
            // 1. Gift Button (Image 1 & 2)
            Padding(
              padding: const EdgeInsets.only(right: paddingRight),
              child: GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  final hostId = roomData['hostId'] ?? '';
                  final seatedParticipants = _participants.where((p) {
                    return p.isOnSeat || p.userId == hostId;
                  }).toList();

                  final convertedParticipants = seatedParticipants.map((p) {
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
                    hostId: hostId,
                  );
                },
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFF880E4F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: const Color(0xFFFF4081),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.gift_fill,
                      color: Color(0xFFFFD54F),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),

            // 2. Call Button (Image 3 Popup: VIEWS, WAITING, ADMINS, LIVE)
            Padding(
              padding: const EdgeInsets.only(right: paddingRight),
              child: GestureDetector(
                onTap: () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  _openCallAndViewsBottomSheet(
                    initialTab: widget.isHost ? 1 : 0,
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C853), Color(0xFF1B5E20)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: const Color(0xFF00E676),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF00E676,
                            ).withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(Icons.call, color: Colors.white, size: 20),
                      ),
                    ),
                    if (widget.isHost && _joinRequests.isNotEmpty)
                      Positioned(
                        top: -3,
                        right: -3,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFE91E63),
                          ),
                          child: Text(
                            _joinRequests.length.toString(),
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

            // 3. Heart / Like Reaction Button (Image 1 & 2)
            GestureDetector(
              onTap: () {
                _sendEmojiMessage('❤️');
              },
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE91E63), Color(0xFF880E4F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: const Color(0xFFFF4081),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.heart_fill,
                    color: Colors.white,
                    size: 20,
                  ),
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
    if (!_isCommentsEnabled && !widget.isHost && !_isCurrentModerator) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comments are disabled by host'),
            backgroundColor: Colors.redAccent,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    final messageText = _chatController.text.trim();
    if (messageText.isEmpty) return;

    final String msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final String currentUserId = _auth.currentUser?.uid ?? '';
    final int myLevel = _userLevelCache[currentUserId] ?? 1;

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
          userLevel: myLevel,
        ),
      );
    });
    _scrollToNewestMessage();

    try {
      await StreamingService.instance.sendChatMessage(
        messageText,
        roomId: widget.roomID,
        isVideo: true,
        customId: msgId,
        userLevel: myLevel,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  bool _isFrontCamera = true;
  bool _isSwitchingCamera = false;

  Future<void> _leaveCallSession() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2d1b2b),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'End Call?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to end your call session and return to audience?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'End Call',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final currentUserId = _auth.currentUser?.uid ?? '';
        await LiveStreamService.leaveCall(widget.roomID, currentUserId);
        await StreamingService.instance.setMicrophoneEnabled(false);
        await StreamingService.instance.setCameraEnabled(false);
        if (mounted) {
          setState(() {
            _isJoined = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Call session ended.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        debugPrint("Error ending call: $e");
      }
    }
  }

  // -------------------------------------------------------------
  // RIGHT-SIDE FLOATING TOOLBAR (Image 1 Collapsed & Image 2 Expanded)
  // -------------------------------------------------------------
  Widget _buildRightToolbar() {
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
    final bool isCurrentlyMuted =
        _localMuteOverride ?? (currentUserParticipant?.isMuted ?? true);
    final bool isCurrentlyCameraOn = currentUserParticipant != null
        ? currentUserParticipant.isCameraOn
        : StreamingService.instance.isCameraOn;
    final int totalRequests = _joinRequests.length;
    final bool isRoomLocked = roomData['isLocked'] == true;

    final mediaQuery = MediaQuery.of(context);
    final double safeBottom = math.max(
      mediaQuery.padding.bottom,
      mediaQuery.viewPadding.bottom,
    );
    final double bottomOffset = math.max(26.0, 12.0 + safeBottom) + 54.0;

    return Positioned(
      right: 12,
      bottom: bottomOffset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // End Call button for guest who is currently on the call
          if (!widget.isHost && _isJoined) ...[
            _buildCircleActionButton(
              size: 44,
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              onTap: _leaveCallSession,
              child: const Icon(Icons.call_end, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 8),
          ],
          if (!_isRightMenuExpanded) ...[
            // ---------------------------------------------------------
            // 1. COLLAPSED TOOLBAR (Image 1)
            // ---------------------------------------------------------
            // PK Badge Button
            if (widget.isHost) _buildPKBadgeButton(size: 38),

            // Share Button (Cyan)
            _buildCircleActionButton(
              size: 38,
              onTap: _shareLiveStream,
              gradient: const LinearGradient(
                colors: [Color(0xFF00E5FF), Color(0xFF0097A7)],
              ),
              border: Border.all(color: const Color(0xFF00E5FF), width: 1.2),
              child: const Icon(Icons.share, color: Colors.white, size: 19),
            ),

            // Lock / Unlock Button (Gold)
            _buildCircleActionButton(
              size: 38,
              onTap: () async {
                if (!widget.isHost) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Only host can lock the room.'),
                      duration: Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
                final newLockState = !isRoomLocked;
                try {
                  await LiveStreamService.toggleRoomLock(
                    widget.roomID,
                    newLockState,
                  );
                  if (mounted) {
                    setState(() {
                      roomData['isLocked'] = newLockState;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          newLockState
                              ? 'Room is locked!'
                              : 'Room is unlocked!',
                        ),
                        backgroundColor: newLockState
                            ? Colors.redAccent
                            : Colors.green,
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint("Error toggling room lock: $e");
                }
              },
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
              ),
              border: Border.all(color: const Color(0xFFFFD700), width: 1.2),
              child: Icon(
                isRoomLocked ? Icons.lock : Icons.lock_open,
                color: Colors.white,
                size: 19,
              ),
            ),

            // Settings (Gear) Button -> Expands to Image 2! (Purple)
            _buildCircleActionButton(
              size: 38,
              onTap: () {
                setState(() {
                  _isRightMenuExpanded = true;
                });
              },
              gradient: const LinearGradient(
                colors: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
              ),
              border: Border.all(color: const Color(0xFFAB47BC), width: 1.2),
              child: const Icon(Icons.settings, color: Colors.white, size: 20),
            ),
          ] else ...[
            // ---------------------------------------------------------
            // 2. EXPANDED TOOLBAR (Image 2)
            // ---------------------------------------------------------
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.70,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 1. PK Button
                    _buildPKBadgeButton(size: 38),

                    // 2. Emoji / Sticker Button
                    _buildCircleActionButton(
                      size: 38,
                      onTap: () {
                        showVideoLiveEmojiBottomSheet(context, widget.roomID);
                      },
                      child: const Icon(
                        Icons.sentiment_satisfied_alt_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),

                    // 3. Notice / Rules / Doc Button
                    _buildCircleActionButton(
                      size: 38,
                      onTap: () {
                        _showNoticeDialog();
                      },
                      child: const Icon(
                        Icons.article_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),

                    // 4. Heart / Ranking Button
                    _buildCircleActionButton(
                      size: 38,
                      onTap: () {
                        final hostId = roomData['hostId'] ?? '';
                        if (hostId.isNotEmpty) {
                          showFansRankingBottomSheet(context, hostId);
                        }
                      },
                      child: const Icon(
                        Icons.favorite,
                        color: Colors.pinkAccent,
                        size: 20,
                      ),
                    ),

                    // 5. Call Button -> Opens Image 3 bottomsheet on WAITING tab!
                    _buildCircleActionButton(
                      size: 38,
                      badge: totalRequests > 0
                          ? Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFFE91E63),
                              ),
                              child: Text(
                                totalRequests.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      onTap: () {
                        _openCallAndViewsBottomSheet(initialTab: 1);
                      },
                      child: const Icon(
                        Icons.call,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),

                    // 6. Rocket / Store Button
                    _buildCircleActionButton(
                      size: 38,
                      onTap: () {
                        showRocketConfigBottomSheet(
                          context,
                          roomId: widget.roomID,
                          hostId: roomData['hostId'] ?? '',
                          isAudioRoom: false,
                        );
                      },
                      child: const Icon(
                        Icons.card_giftcard,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),

                    // 7. Lock Button
                    _buildCircleActionButton(
                      size: 38,
                      onTap: () async {
                        if (!widget.isHost) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Only host can lock the room.'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        final newLockState = !isRoomLocked;
                        try {
                          await LiveStreamService.toggleRoomLock(
                            widget.roomID,
                            newLockState,
                          );
                          if (mounted) {
                            setState(() {
                              roomData['isLocked'] = newLockState;
                            });
                          }
                        } catch (e) {
                          debugPrint("Error locking room: $e");
                        }
                      },
                      child: Icon(
                        isRoomLocked ? Icons.lock : Icons.lock_outline,
                        color: isRoomLocked ? Colors.amber : Colors.white,
                        size: 19,
                      ),
                    ),

                    // 8. Mic Button (toggles mute)
                    _buildCircleActionButton(
                      size: 38,
                      onTap: () async {
                        final newMuteState = !isCurrentlyMuted;
                        setState(() {
                          _localMuteOverride = newMuteState;
                        });
                        try {
                          await StreamingService.instance.setMicrophoneEnabled(
                            !newMuteState,
                          );
                          await LiveStreamService.toggleMuteState(
                            widget.roomID,
                            newMuteState,
                          );
                        } catch (e) {
                          debugPrint('Error toggling mute: $e');
                        }
                      },
                      child: Icon(
                        isCurrentlyMuted
                            ? CupertinoIcons.mic_off
                            : CupertinoIcons.mic_fill,
                        color: isCurrentlyMuted
                            ? Colors.white70
                            : Colors.greenAccent,
                        size: 19,
                      ),
                    ),

                    // 9. Camera Button (toggles video)
                    _buildCircleActionButton(
                      size: 38,
                      onTap: () async {
                        final newCameraState = !isCurrentlyCameraOn;
                        if (newCameraState) {
                          final status = await Permission.camera.request();
                          if (!status.isGranted) return;
                        }
                        await StreamingService.instance.setCameraEnabled(
                          newCameraState,
                        );
                        if (!newCameraState) _isFrontCamera = true;
                        await LiveStreamService.toggleCameraState(
                          widget.roomID,
                          newCameraState,
                        );
                        if (mounted) setState(() {});
                      },
                      child: Icon(
                        isCurrentlyCameraOn
                            ? Icons.videocam
                            : Icons.videocam_off,
                        color: isCurrentlyCameraOn
                            ? Colors.white
                            : Colors.redAccent,
                        size: 19,
                      ),
                    ),

                    // 10. Camera Flip Button
                    _buildCircleActionButton(
                      size: 38,
                      onTap: () async {
                        if (_isSwitchingCamera) return;
                        setState(() => _isSwitchingCamera = true);
                        try {
                          final isFront = await StreamingService.instance
                              .flipCamera();
                          if (mounted) setState(() => _isFrontCamera = isFront);
                        } catch (e) {
                          debugPrint("Error flipping camera: $e");
                        } finally {
                          if (mounted)
                            setState(() => _isSwitchingCamera = false);
                        }
                      },
                      child: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),

                    // 11. Beauty / Magic Wand Button
                    _buildCircleActionButton(
                      size: 38,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Beauty effects active'),
                            duration: Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),

                    // 12. Music Button
                    _buildCircleActionButton(
                      size: 38,
                      onTap: () {
                        showPlayMusicBottomSheet(
                          context,
                          musicManager: _musicPlayerManager,
                          isHost: widget.isHost,
                        );
                      },
                      child: const Icon(
                        Icons.library_music_outlined,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),

                    // 13. Room Skin / Theme Button (Host & Moderator)
                    if (widget.isHost || _isCurrentModerator)
                      _buildCircleActionButton(
                        size: 38,
                        onTap: () {
                          showRoomSkinSideSheet(
                            context,
                            widget.roomID,
                            isLiveStream: true,
                          );
                        },
                        child: const Icon(
                          Icons.palette_outlined,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),

                    // 13. Settings (Gear) Button -> Collapses back to Image 1!
                    _buildCircleActionButton(
                      size: 38,
                      onTap: () {
                        setState(() {
                          _isRightMenuExpanded = false;
                        });
                      },
                      child: const Icon(
                        Icons.settings,
                        color: Colors.amber,
                        size: 21,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircleActionButton({
    required Widget child,
    required VoidCallback onTap,
    double size = 40.0,
    LinearGradient? gradient,
    Border? border,
    Widget? badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    gradient ??
                    const LinearGradient(
                      colors: [Color(0xFF881337), Color(0xFF4C0519)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                border:
                    border ??
                    Border.all(
                      color: const Color(0xFFFF2D55).withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(child: child),
            ),
            if (badge != null) Positioned(top: -3, right: -3, child: badge),
          ],
        ),
      ),
    );
  }

  Widget _buildPKBadgeButton({double size = 42.0}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: GestureDetector(
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          if (_isPKMode) {
            _showEndPKConfirmation();
          } else {
            showInvitePKBottomSheet(
              context,
              pendingInvites: _pendingInvites,
              currentRoomId: widget.roomID,
            );
          }
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFB300), Color(0xFFFF007F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'PK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _shareLiveStream() {
    FocusManager.instance.primaryFocus?.unfocus();
    final String hostName = roomData['hostName'] ?? 'Testing account';
    final String roomId = widget.roomID;
    const String packageName = 'com.pigobdlive.app';

    // Official Google Play Store link for com.pigobdlive.app with room referrer
    final String shareLink =
        'https://play.google.com/store/apps/details?id=$packageName&referrer=roomId%3D$roomId';

    final String shareMessage = '$hostName\n$shareLink';

    // ignore: deprecated_member_use
    Share.share(shareMessage, subject: '$hostName - Pigo Live');
  }

  void _openCallAndViewsBottomSheet({int initialTab = 0}) {
    final hostId = roomData['hostId'] ?? '';
    final isCurrentAdmin =
        widget.isHost ||
        _isCurrentModerator ||
        _participants.any(
          (p) =>
              p.userId == _auth.currentUser?.uid &&
              (p.isAdmin || p.isModerator),
        );

    showLiveRoomCallAndViewsBottomSheet(
      context: context,
      participants: _participants,
      joinRequests: _joinRequests,
      currentUserId: _auth.currentUser?.uid ?? '',
      hostId: hostId,
      roomId: widget.roomID,
      isHost: widget.isHost,
      isCurrentUserModerator: isCurrentAdmin,
      initialTab: initialTab,
    );
  }

  void _showNoticeDialog() {
    final noticeController = TextEditingController(text: _roomNotice);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2d1b2b),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Room Notice',
            style: TextStyle(color: Colors.white),
          ),
          content: widget.isHost
              ? TextField(
                  controller: noticeController,
                  autofocus: true,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter room notice...",
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE91E63)),
                    ),
                  ),
                )
              : Text(
                  _roomNotice.isNotEmpty
                      ? _roomNotice
                      : "No notice has been set for this room.",
                  style: const TextStyle(color: Colors.white70),
                ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white70),
              ),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            if (widget.isHost)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Save Notice',
                  style: TextStyle(color: Colors.white),
                ),
                onPressed: () async {
                  final notice = noticeController.text.trim();
                  Navigator.of(dialogContext).pop();
                  try {
                    await LiveStreamService.setRoomNotice(
                      widget.roomID,
                      notice,
                    );
                    if (mounted) {
                      setState(() {
                        _roomNotice = notice;
                      });
                    }
                  } catch (e) {
                    debugPrint("Error setting notice: $e");
                  }
                },
              ),
          ],
        );
      },
    );
  }

  void _sendEmojiMessage(String emoji) async {
    try {
      _showFloatingEmoji(emoji, senderName: _currentUserName);
      await StreamingService.instance.sendEmoji(
        emoji,
        roomId: widget.roomID,
        isVideo: true,
      );
    } catch (e) {
      debugPrint('Error sending emoji message: $e');
    }
  }

  void _showFloatingEmoji(String emoji, {String? senderName}) {
    if (!mounted) return;
    final key = UniqueKey();
    setState(() {
      _floatingEmojis.add(
        FloatingEmoji(
          emoji: emoji,
          key: key,
          leftOffset: 10.0 + (DateTime.now().millisecondsSinceEpoch % 30),
          senderName: senderName,
        ),
      );
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
    final bool hasJoinCallButton = !widget.isHost && !_isJoined && !_isPKMode;
    final double bottomOffset =
        (hasJoinCallButton ? 104.0 : 62.0) +
        MediaQuery.of(context).padding.bottom;

    return Positioned(
      right: 58,
      bottom: bottomOffset,
      width: 100,
      height: 300,
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: _floatingEmojis
              .map(
                (e) => _FloatingEmojiWidget(
                  key: e.key,
                  emoji: e.emoji,
                  leftOffset: e.leftOffset,
                  senderName: e.senderName,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _sendJoinMessage() async {
    const messageText = "Just joined the room!";
    final String msgId = DateTime.now().millisecondsSinceEpoch.toString();
    final String currentUserId = _auth.currentUser?.uid ?? '';
    final int myLevel = _userLevelCache[currentUserId] ?? 1;

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
            userLevel: myLevel,
          ),
        );
      });
      _scrollToNewestMessage();
    }

    try {
      await StreamingService.instance.sendChatMessage(
        messageText,
        roomId: widget.roomID,
        isVideo: true,
        customId: msgId,
        userLevel: myLevel,
      );
    } catch (e) {
      debugPrint('Error sending join message: $e');
    }
  }

  Widget _buildParticipantAvatars(List<LiveStreamParticipant> participants) {
    if (participants.isEmpty) {
      return const SizedBox.shrink();
    }

    final participantsToShow = participants
        .where((p) => !p.isModerator)
        .toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: participantsToShow.map((participant) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: VipAvatarWidget(
            userId: participant.userId,
            userPicture: participant.userPicture,
            avatarSize: 22.0,
            frameScale: 1.4,
            directVipType: participant.vipType,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildJoinCallOverlay() {
    return const SizedBox.shrink();
  }

  Widget _oldBuildJoinCallOverlay() {
    if (widget.isHost || _isJoined) return const SizedBox.shrink();

    return Positioned(
      bottom: 8,
      right: 16,
      child: GestureDetector(
        onTap: () async {
          final currentUserId = _auth.currentUser?.uid ?? '';
          final myParticipant = _participants.firstWhere(
            (p) => p.userId == currentUserId,
            orElse: () => LiveStreamParticipant(
              userId: '',
              userName: '',
              isOnSeat: false,
              isMuted: true,
              isCameraOn: false,
            ),
          );
          if (myParticipant.isLocked == true) {
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
          try {
            final bool hasVip = await ProfileService.hasKingOrRoyalPackage(
              currentUserId,
            );
            if (hasVip) {
              await LiveStreamService.joinCallImmediately(widget.roomID);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('VIP privilege: Joined call directly!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              return;
            }

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
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
            }
          }
        },
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.5),
            border: Border.all(
              color: const Color(0xFFFFD700), // Gold color
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add_alt_1_outlined,
            color: Color(0xFFFFD700),
            size: 18,
          ),
        ),
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

class FloatingEmoji {
  final String emoji;
  final Key key;
  final double leftOffset;
  final String? senderName;

  FloatingEmoji({
    required this.emoji,
    required this.key,
    required this.leftOffset,
    this.senderName,
  });
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

class _FloatingEmojiWidgetState extends State<_FloatingEmojiWidget>
    with SingleTickerProviderStateMixin {
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

    _positionAnimation = Tween<double>(
      begin: 0,
      end: -250,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

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
                  Text(widget.emoji, style: const TextStyle(fontSize: 28)),
                  if (widget.senderName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        widget.senderName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
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

class _SafeParticipantVideoWidget extends StatefulWidget {
  final LiveStreamParticipant participant;
  const _SafeParticipantVideoWidget({super.key, required this.participant});

  @override
  State<_SafeParticipantVideoWidget> createState() =>
      _SafeParticipantVideoWidgetState();
}

class _SafeParticipantVideoWidgetState
    extends State<_SafeParticipantVideoWidget> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = StreamingService.instance.remoteParticipantsChangedStream
        .listen((_) {
          if (mounted) setState(() {});
        });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.participant.userId.isEmpty) {
      return Container(color: Colors.black);
    }

    return StreamingService.instance.buildVideoView(
      widget.participant.userId,
      fit: BoxFit.cover,
    );
  }
}
