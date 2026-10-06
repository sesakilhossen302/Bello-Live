import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/active_frame_widget.dart';
import '../../../core/widgets/auto_scroll_text.dart';
import '../../../data/remote/firebase/live_streaming_services.dart';
import '../live_room_page.dart';
import 'profile_info_bottomsheet.dart';

class LiveRoomCallAndViewsBottomSheet extends StatefulWidget {
  final List<LiveStreamParticipant> participants;
  final List<JoinRequest> initialJoinRequests;
  final String currentUserId;
  final String hostId;
  final String roomId;
  final bool isHost;
  final bool isCurrentUserModerator;
  final int initialTab; // 0: VIEWS, 1: WAITING, 2: ADMINS, 3: LIVE

  const LiveRoomCallAndViewsBottomSheet({
    super.key,
    required this.participants,
    required this.initialJoinRequests,
    required this.currentUserId,
    required this.hostId,
    required this.roomId,
    required this.isHost,
    this.isCurrentUserModerator = false,
    this.initialTab = 0,
  });

  @override
  State<LiveRoomCallAndViewsBottomSheet> createState() =>
      _LiveRoomCallAndViewsBottomSheetState();
}

class _LiveRoomCallAndViewsBottomSheetState
    extends State<LiveRoomCallAndViewsBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<LiveStreamParticipant> _liveParticipants;
  late List<JoinRequest> _joinRequests;
  StreamSubscription? _participantsSubscription;
  StreamSubscription? _requestsSubscription;

  int _approvedCount = 0;
  bool _isRequestingToJoin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _liveParticipants = List.from(widget.participants);
    _joinRequests = List.from(widget.initialJoinRequests);

    // Real-time synchronization for participants and join requests
    _participantsSubscription =
        LiveStreamService.getRoomParticipants(widget.roomId).listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        if (mounted) setState(() => _liveParticipants = []);
        return;
      }
      try {
        final participantsMap = Map<dynamic, dynamic>.from(
          event.snapshot.value as Map,
        );
        final newParticipants = participantsMap.entries
            .map((entry) => LiveStreamParticipant.fromRTDB(entry.key, entry.value))
            .toList();
        if (mounted) {
          setState(() {
            _liveParticipants = newParticipants;
          });
        }
      } catch (e) {
        debugPrint('Error parsing room participants: $e');
      }
    });

    _requestsSubscription =
        LiveStreamService.getJoinRequestsStream(widget.roomId).listen((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) {
        if (mounted) setState(() => _joinRequests = []);
        return;
      }
      try {
        final requestsMap = Map<dynamic, dynamic>.from(
          event.snapshot.value as Map,
        );
        final requests = requestsMap.entries
            .map((entry) => JoinRequest.fromRTDB(entry.key, entry.value))
            .toList();
        if (mounted) {
          setState(() {
            _joinRequests = requests;
          });
        }
      } catch (e) {
        debugPrint('Error parsing join requests: $e');
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _participantsSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.dispose();
  }

  bool get _canManage =>
      widget.isHost ||
      widget.isCurrentUserModerator ||
      _liveParticipants.any(
        (p) =>
            p.userId == widget.currentUserId && (p.isAdmin || p.isModerator),
      );

  bool get _isUserOnSeat => _liveParticipants.any(
        (p) =>
            p.userId == widget.currentUserId &&
            (p.isOnSeat || p.userId == widget.hostId),
      );

  bool get _isUserAlreadyRequested =>
      _joinRequests.any((r) => r.userId == widget.currentUserId);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Tabs: VIEWS | WAITING | ADMINS | LIVE
          TabBar(
            controller: _tabController,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            indicatorColor: const Color(0xFFE91E63),
            indicatorWeight: 3.0,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: const Color(0xFFE91E63),
            unselectedLabelColor: const Color(0xFF757575),
            labelStyle: const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
            tabs: [
              const Tab(text: 'VIEWS'),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('WAITING'),
                    if (_joinRequests.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE91E63),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_joinRequests.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'ADMINS'),
              const Tab(text: 'LIVE'),
            ],
          ),
          Divider(color: Colors.grey.shade200, height: 1, thickness: 1),

          // Tab Bar View content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildViewsTab(),
                _buildWaitingTab(),
                _buildAdminsTab(),
                _buildLiveTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 1: VIEWS (All viewers watching the room)
  // -------------------------------------------------------------
  Widget _buildViewsTab() {
    final viewers = _liveParticipants
        .where((p) => p.userId != widget.hostId && !p.isOnSeat)
        .toList();

    viewers.sort((a, b) => a.userName.toLowerCase().compareTo(b.userName.toLowerCase()));

    return Column(
      children: [
        Expanded(
          child: viewers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.remove_red_eye_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No viewers currently in the room',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: viewers.length,
                  separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
                  itemBuilder: (context, index) {
                    final viewer = viewers[index];
                    final isMe = viewer.userId == widget.currentUserId;

                    return ListTile(
                      onTap: () {
                        Navigator.of(context).pop();
                        showProfileInfoBottomSheet(
                          context,
                          userId: viewer.userId,
                          hostId: widget.hostId,
                          roomId: widget.roomId,
                          isCurrentUserAdmin: _canManage,
                        );
                      },
                      leading: SizedBox(
                        width: 44,
                        height: 44,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: Colors.grey.shade300,
                              backgroundImage: viewer.userPicture != null && viewer.userPicture!.isNotEmpty
                                  ? NetworkImage(viewer.userPicture!)
                                  : null,
                              child: viewer.userPicture == null || viewer.userPicture!.isEmpty
                                  ? const Icon(Icons.person, color: Colors.white, size: 22)
                                  : null,
                            ),
                            Positioned(
                              width: 52,
                              height: 52,
                              child: IgnorePointer(
                                child: ActiveFrameWidget(userId: viewer.userId, size: 52),
                              ),
                            ),
                          ],
                        ),
                      ),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              viewer.userName,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE91E63).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  color: Color(0xFFE91E63),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        viewer.gender != null && viewer.gender!.isNotEmpty
                            ? viewer.gender!
                            : 'Viewer',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                    );
                  },
                ),
        ),

        // Bottom Join Call bar for viewers who are not host and not on seat
        if (!widget.isHost && !_isUserOnSeat)
          _buildViewerJoinBottomBar(),
      ],
    );
  }

  Widget _buildViewerJoinBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _isUserAlreadyRequested
            ? Row(
                children: [
                  const Icon(Icons.hourglass_top, color: Color(0xFFE91E63), size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Request sent! Waiting for host to accept...',
                      style: TextStyle(
                        color: Color(0xFFE91E63),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    ),
                    onPressed: () {
                      final myReq = _joinRequests.firstWhere(
                        (r) => r.userId == widget.currentUserId,
                        orElse: () => JoinRequest(requestId: '', userId: '', userName: ''),
                      );
                      if (myReq.requestId.isNotEmpty) {
                        _cancelMyRequest(myReq);
                      }
                    },
                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isRequestingToJoin ? null : _handleSendJoinRequest,
                  icon: const Icon(Icons.call, color: Colors.white, size: 20),
                  label: Text(
                    _isRequestingToJoin ? 'Requesting...' : 'Join Call',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: WAITING (Join Call requests queue)
  // -------------------------------------------------------------
  Widget _buildWaitingTab() {
    if (_joinRequests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.call_outlined, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'No pending join requests',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              Text(
                widget.isHost
                    ? 'Users requesting to join the call will appear here for your approval.'
                    : 'You can request to join the call and talk with the host.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              if (!widget.isHost && !_isUserOnSeat) ...[
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: _isRequestingToJoin ? null : _handleSendJoinRequest,
                  icon: const Icon(Icons.call, color: Colors.white, size: 18),
                  label: Text(
                    _isRequestingToJoin ? 'Requesting...' : 'Join Call',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // If guest hasn't requested yet, provide Join Call action at the top
        if (!widget.isHost && !_isUserOnSeat && !_isUserAlreadyRequested)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _isRequestingToJoin ? null : _handleSendJoinRequest,
                icon: const Icon(Icons.call, color: Colors.white, size: 18),
                label: const Text(
                  'Join Call',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _joinRequests.length,
            separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
            itemBuilder: (context, index) {
              final request = _joinRequests[index];
              final isMe = request.userId == widget.currentUserId;

              return ListTile(
                leading: SizedBox(
                  width: 44,
                  height: 44,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: request.userPicture != null && request.userPicture!.isNotEmpty
                            ? NetworkImage(request.userPicture!)
                            : null,
                        child: request.userPicture == null || request.userPicture!.isEmpty
                            ? const Icon(Icons.person, color: Colors.white, size: 22)
                            : null,
                      ),
                      Positioned(
                        width: 52,
                        height: 52,
                        child: IgnorePointer(
                          child: ActiveFrameWidget(userId: request.userId, size: 52),
                        ),
                      ),
                    ],
                  ),
                ),
                title: AutoScrollText(
                  alignment: Alignment.centerLeft,
                  text: request.userName,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: request.callType == 'video'
                            ? Colors.pink.shade50
                            : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: request.callType == 'video'
                              ? Colors.pink.shade200
                              : Colors.green.shade200,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            request.callType == 'video' ? Icons.videocam : Icons.mic,
                            size: 12,
                            color: request.callType == 'video'
                                ? Colors.pink.shade700
                                : Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            request.callType == 'video' ? 'Video' : 'Audio',
                            style: TextStyle(
                              color: request.callType == 'video'
                                  ? Colors.pink.shade700
                                  : Colors.green.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isMe ? 'Waiting approval' : 'Wants to join',
                        style: TextStyle(
                          color: isMe ? const Color(0xFFE91E63) : Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                trailing: _canManage
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () => _rejectRequest(request),
                            child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE91E63),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: () => _approveRequest(request),
                            child: const Text(
                              'Accept',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      )
                    : isMe
                        ? OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            onPressed: () => _cancelMyRequest(request),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        : null,
              );
            },
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 3: ADMINS (Room Host & Moderators)
  // -------------------------------------------------------------
  Widget _buildAdminsTab() {
    final admins = _liveParticipants
        .where((p) => p.userId == widget.hostId || p.isAdmin || p.isModerator)
        .toList();

    // Put host first
    admins.sort((a, b) {
      if (a.userId == widget.hostId) return -1;
      if (b.userId == widget.hostId) return 1;
      return a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
    });

    if (admins.isEmpty) {
      return Center(
        child: Text(
          'No admins currently',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: admins.length,
      separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
      itemBuilder: (context, index) {
        final admin = admins[index];
        final isHost = admin.userId == widget.hostId;

        return ListTile(
          onTap: () {
            Navigator.of(context).pop();
            showProfileInfoBottomSheet(
              context,
              userId: admin.userId,
              hostId: widget.hostId,
              roomId: widget.roomId,
              isCurrentUserAdmin: _canManage,
            );
          },
          leading: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: admin.userPicture != null && admin.userPicture!.isNotEmpty
                      ? NetworkImage(admin.userPicture!)
                      : null,
                  child: admin.userPicture == null || admin.userPicture!.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 22)
                      : null,
                ),
                Positioned(
                  width: 52,
                  height: 52,
                  child: IgnorePointer(
                    child: ActiveFrameWidget(userId: admin.userId, size: 52),
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            admin.userName,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            isHost ? 'Room Owner / Host' : 'Moderator / Admin',
            style: TextStyle(
              color: isHost ? Colors.amber.shade800 : Colors.indigo.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isHost ? Colors.amber.shade100 : Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHost ? Colors.amber.shade400 : Colors.indigo.shade300,
                width: 1,
              ),
            ),
            child: Text(
              isHost ? 'Host' : 'Admin',
              style: TextStyle(
                color: isHost ? Colors.amber.shade900 : Colors.indigo.shade700,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 4: LIVE (Participants currently in the call)
  // -------------------------------------------------------------
  Widget _buildLiveTab() {
    final liveParticipants = _liveParticipants
        .where((p) => p.isOnSeat || p.userId == widget.hostId)
        .toList();

    // Put host first
    liveParticipants.sort((a, b) {
      if (a.userId == widget.hostId) return -1;
      if (b.userId == widget.hostId) return 1;
      return a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
    });

    if (liveParticipants.isEmpty) {
      return Center(
        child: Text(
          'No one on call right now',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: liveParticipants.length,
      separatorBuilder: (_, __) => Divider(color: Colors.grey.shade100, height: 1),
      itemBuilder: (context, index) {
        final participant = liveParticipants[index];
        final isHost = participant.userId == widget.hostId;

        return ListTile(
          onTap: () {
            Navigator.of(context).pop();
            showProfileInfoBottomSheet(
              context,
              userId: participant.userId,
              hostId: widget.hostId,
              roomId: widget.roomId,
              isCurrentUserAdmin: _canManage,
            );
          },
          leading: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: participant.userPicture != null && participant.userPicture!.isNotEmpty
                      ? NetworkImage(participant.userPicture!)
                      : null,
                  child: participant.userPicture == null || participant.userPicture!.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 22)
                      : null,
                ),
                Positioned(
                  width: 52,
                  height: 52,
                  child: IgnorePointer(
                    child: ActiveFrameWidget(userId: participant.userId, size: 52),
                  ),
                ),
              ],
            ),
          ),
          title: Text(
            participant.userName,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Icon(
                participant.isMuted ? Icons.mic_off : Icons.mic,
                size: 14,
                color: participant.isMuted ? Colors.redAccent : Colors.green,
              ),
              const SizedBox(width: 4),
              Icon(
                participant.isCameraOn ? Icons.videocam : Icons.videocam_off,
                size: 14,
                color: participant.isCameraOn ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                isHost ? 'Host' : 'Call Member',
                style: TextStyle(
                  color: isHost ? Colors.amber.shade800 : Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          trailing: isHost
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Host',
                    style: TextStyle(
                      color: Colors.amber.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                )
              : (participant.userId == widget.currentUserId)
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.call_end, size: 16),
                      label: const Text('End Call', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        await LiveStreamService.leaveCall(widget.roomId, widget.currentUserId);
                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('You left the call session.')),
                          );
                        }
                      },
                    )
                  : _canManage
                      ? PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          onSelected: (value) async {
                            if (value == 'kick') {
                              await LiveStreamService.kickParticipant(widget.roomId, participant.userId);
                            } else if (value == 'mute') {
                              await LiveStreamService.muteParticipant(
                                widget.roomId,
                                participant.userId,
                                !participant.isMuted,
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'mute',
                              child: Text(participant.isMuted ? 'Unmute Mic' : 'Mute Mic'),
                            ),
                            const PopupMenuItem(
                              value: 'kick',
                              child: Text('Remove from Call', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        )
                      : null,
        );
      },
    );
  }

  // -------------------------------------------------------------
  // ACTION HANDLERS
  // -------------------------------------------------------------
  Future<void> _handleSendJoinRequest() async {
    final callType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E2C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Select Call Type',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose how you want to join the call',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx, 'audio'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic, color: Colors.white, size: 36),
                          SizedBox(height: 10),
                          Text('Audio Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('Voice Only', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx, 'video'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE91E63), Color(0xFFFF4081)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                        ],
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam, color: Colors.white, size: 36),
                          SizedBox(height: 10),
                          Text('Video Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(height: 4),
                          Text('Camera & Mic', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (callType == null) return;

    setState(() => _isRequestingToJoin = true);
    try {
      await LiveStreamService.requestToJoin(widget.roomId, callType: callType);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${callType == 'video' ? 'Video' : 'Audio'} join request sent to the host!'),
            backgroundColor: const Color(0xFFE91E63),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRequestingToJoin = false);
      }
    }
  }

  void _rejectRequest(JoinRequest request) {
    LiveStreamService.rejectJoinRequest(widget.roomId, request.requestId);
  }

  void _cancelMyRequest(JoinRequest request) {
    LiveStreamService.rejectJoinRequest(widget.roomId, request.requestId);
  }

  void _approveRequest(JoinRequest request) {
    final seatedCount = _liveParticipants
        .where((p) => p.userId != widget.hostId && p.isOnSeat)
        .length;

    if (seatedCount + _approvedCount >= 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 13 people (including host) can join the call.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    LiveStreamService.approveJoinRequest(
      widget.roomId,
      request.requestId,
      request.userId,
      callType: request.callType,
    );
    setState(() {
      _approvedCount++;
    });
  }
}

/// Global helper to show the call and views modal bottom sheet
void showLiveRoomCallAndViewsBottomSheet({
  required BuildContext context,
  required List<LiveStreamParticipant> participants,
  required List<JoinRequest> joinRequests,
  required String currentUserId,
  required String hostId,
  required String roomId,
  required bool isHost,
  bool isCurrentUserModerator = false,
  int initialTab = 0, // 0: VIEWS, 1: WAITING, 2: ADMINS, 3: LIVE
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return FractionallySizedBox(
        heightFactor: 0.65,
        child: LiveRoomCallAndViewsBottomSheet(
          participants: participants,
          initialJoinRequests: joinRequests,
          currentUserId: currentUserId,
          hostId: hostId,
          roomId: roomId,
          isHost: isHost,
          isCurrentUserModerator: isCurrentUserModerator,
          initialTab: initialTab,
        ),
      );
    },
  );
}
