import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class LiveHistoryPage extends StatefulWidget {
  const LiveHistoryPage({super.key});

  @override
  State<LiveHistoryPage> createState() => _LiveHistoryPageState();
}

class _LiveHistoryPageState extends State<LiveHistoryPage> {
  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
  }

  String _formatDuration(int totalMinutes) {
    if (totalMinutes < 60) {
      return '$totalMinutes mins';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) {
      return '$hours hrs';
    }
    return '$hours hrs $mins mins';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF091433),
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Container(
              color: const Color(0xFFE62563),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.back, size: 26, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Live Streaming History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _userId == null
                  ? const Center(child: Text('Please log in to view history'))
                  : StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(_userId)
                          .collection('liveHistory')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: Color(0xFFE62563)),
                          );
                        }

                        final docs = snapshot.data?.docs ?? [];

                        // Compute totals
                        int grandTotalMinutes = 0;
                        int totalAudioMinutes = 0;
                        int totalVideoMinutes = 0;

                        List<Map<String, dynamic>> allSessions = [];

                        for (final doc in docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          final sessions = data['sessions'] as List<dynamic>? ?? [];

                          for (final session in sessions) {
                            final sessionMap = Map<String, dynamic>.from(session as Map);
                            final duration = sessionMap['durationMinutes'] as int? ?? 0;
                            final roomType = sessionMap['roomType'] as String? ?? 'video';

                            grandTotalMinutes += duration;
                            if (roomType == 'audio') {
                              totalAudioMinutes += duration;
                            } else {
                              totalVideoMinutes += duration;
                            }

                            allSessions.add(sessionMap);
                          }
                        }

                        // Sort sessions by startTime descending
                        allSessions.sort((a, b) {
                          final Timestamp? tA = a['startTime'] as Timestamp?;
                          final Timestamp? tB = b['startTime'] as Timestamp?;
                          if (tA == null || tB == null) return 0;
                          return tB.compareTo(tA);
                        });

                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. Total Summary Card
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFE62563), Color(0xFF2C132B)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE62563).withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Live Streaming Time',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _formatDuration(grandTotalMinutes),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Audio / Video breakdown pills
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(CupertinoIcons.mic_fill, color: Colors.white, size: 18),
                                                const SizedBox(width: 8),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Audio Live',
                                                      style: TextStyle(color: Colors.white70, fontSize: 11),
                                                    ),
                                                    Text(
                                                      _formatDuration(totalAudioMinutes),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(CupertinoIcons.videocam_fill, color: Colors.white, size: 18),
                                                const SizedBox(width: 8),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'Video Live',
                                                      style: TextStyle(color: Colors.white70, fontSize: 11),
                                                    ),
                                                    Text(
                                                      _formatDuration(totalVideoMinutes),
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
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
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              const Text(
                                'Stream Sessions History',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (allSessions.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F1E42),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  child: const Column(
                                    children: [
                                      Icon(CupertinoIcons.time, size: 48, color: Colors.white38),
                                      SizedBox(height: 12),
                                      Text(
                                        'No live streaming history yet',
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: allSessions.length,
                                  itemBuilder: (context, index) {
                                    final session = allSessions[index];
                                    final roomType = session['roomType'] as String? ?? 'video';
                                    final duration = session['durationMinutes'] as int? ?? 0;
                                    final startTime = session['startTime'] as Timestamp?;
                                    final isVideo = roomType == 'video';

                                    String formattedDate = 'N/A';
                                    String formattedTime = '';
                                    if (startTime != null) {
                                      final dt = startTime.toDate();
                                      formattedDate = DateFormat('MMM d, yyyy').format(dt);
                                      formattedTime = DateFormat('h:mm a').format(dt);
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F1E42),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              color: (isVideo ? const Color(0xFFE62563) : const Color(0xFF0088FF))
                                                  .withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isVideo ? CupertinoIcons.videocam_fill : CupertinoIcons.mic_fill,
                                              color: isVideo ? const Color(0xFFE62563) : const Color(0xFF0088FF),
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${isVideo ? "Video Live" : "Audio Live"} (${_formatDuration(duration)})',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '$formattedDate • $formattedTime',
                                                  style: const TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE62563).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '$duration mins',
                                              style: const TextStyle(
                                                color: Color(0xFFE62563),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
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
}
