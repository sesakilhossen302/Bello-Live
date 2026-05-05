import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/localization/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../home/home_cubit.dart';
import '../home/home_page.dart';
import '../home/home_state.dart';
import '../home/widgets/card_widget.dart';

class LiveNowPage extends StatelessWidget {
  const LiveNowPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return BlocProvider(
      create: (context) => HomeCubit()..init(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.barColor,
          elevation: 0,
          title: Text(
            AppLocalizations.of(context).liveNow,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Header: Video Live
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.videocam_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context).liveNow,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Grid of Followed Live Streams
              Expanded(
                child: currentUserId == null
                    ? const Center(child: Text("Please login to see followed lives", style: TextStyle(color: Colors.white70)))
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUserId)
                            .collection('following')
                            .snapshots(),
                        builder: (context, followingSnapshot) {
                          if (followingSnapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator(color: Colors.white));
                          }

                          final followingIds = followingSnapshot.data?.docs.map((doc) => doc.id).toSet() ?? {};

                          return BlocBuilder<HomeCubit, HomeState>(
                            builder: (context, state) {
                              return StreamBuilder<List<StreamerModel>>(
                                stream: context.read<HomeCubit>().allRoomsStream,
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(color: Colors.white),
                                    );
                                  }

                                  final allRooms = snapshot.data ?? [];
                                  // Show ALL rooms (Audio/Video) that the user follows
                                  final followedRooms = allRooms.where((r) =>
                                    r.hostId != null && followingIds.contains(r.hostId)
                                  ).toList();

                                  if (followedRooms.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.videocam_off_rounded,
                                            size: 64,
                                            color: Colors.white.withValues(alpha: 0.3),
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            AppLocalizations.of(context).noFollowedLive,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.5),
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return GridView.builder(
                                    padding: const EdgeInsets.all(16),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.9,
                                    ),
                                    itemCount: followedRooms.length,
                                    itemBuilder: (context, index) {
                                      return AnimatedStreamerCard(streamer: followedRooms[index]);
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
