import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'home_cubit.dart';
import 'home_page.dart'; 
import 'widgets/carousal_banner.dart';
import 'widgets/card_widget.dart';
import '../../core/localization/app_localizations.dart';

Widget _buildFresherGrid(HomeCubit cubit) {
    return StreamBuilder<List<StreamerModel>>(
      stream: cubit.freshersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final freshers = snapshot.data ?? [];

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: CarouselBanner(
                imageUrls: BannerUrls.liveStreamingBanners,
                autoPlayDuration: const Duration(seconds: 4),
                onBannerTap: (index) => debugPrint('Banner $index tapped'),
              ),
            ),
            if (freshers.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.videocam_off, size: 60, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).noActiveRooms,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: .9,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => AnimatedStreamerCard(streamer: freshers[index]),
                    childCount: freshers.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  Widget _buildPartyTab(HomeCubit cubit) {
    return StreamBuilder<List<StreamerModel>>(
      stream: cubit.audioRoomsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final audioRooms = snapshot.data ?? [];

        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: CarouselBanner(
                imageUrls: BannerUrls.liveStreamingBanners,
                autoPlayDuration: const Duration(seconds: 4),
                onBannerTap: (index) => debugPrint('Banner $index tapped'),
              ),
            ),
            if (audioRooms.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.mic_off, size: 60, color: Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).noActiveRooms,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: .9,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => AnimatedStreamerCard(streamer: audioRooms[index]),
                    childCount: audioRooms.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }
