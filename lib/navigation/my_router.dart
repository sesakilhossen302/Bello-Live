import 'package:app_links/app_links.dart';
import 'package:picture_live/ui/apply/apply_agency.dart';
import 'package:picture_live/ui/apply/apply_hosting.dart';
import 'package:picture_live/ui/auth/registration/register_page.dart';
import 'package:picture_live/ui/earnings/earnings_page.dart';
import 'package:picture_live/ui/inbox/chat_page.dart';
import 'package:picture_live/ui/inbox/inbox_page.dart';
import 'package:picture_live/ui/status/my_feed_page.dart';
import 'package:picture_live/ui/status/newsfeed_page.dart';
import 'package:picture_live/ui/streaming/audio_room_page.dart';
import 'package:picture_live/ui/top_up/top_up_page.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:picture_live/navigation/routes.dart';
import 'package:picture_live/ui/auth/change_password/change_password_page.dart';
import 'package:picture_live/ui/auth/forget_password/forget_password_page.dart';
import 'package:picture_live/ui/auth/login/login_page.dart';
import 'package:picture_live/ui/auth/verify_otp/verify_otp_page.dart';

// Make sure this import path matches where you put the overlay in the new app
import '../core/widgets/big_winner_overlay.dart';
import '../data/local/secure_storage/secure_storage.dart';
import '../ui/streaming/live_now_page.dart';
import '../ui/feedback/feedback_page.dart';
import '../ui/games/greedy_game.dart';
import '../ui/games/spinner_game.dart';
import '../ui/home/home_page.dart';
import '../ui/host_page/host_page.dart';
import '../ui/live_streaming/live_room_page.dart';
import '../ui/main_page.dart';
import '../ui/my_invites/my_invites_page.dart';
import '../ui/my_level/my_level_page.dart';
import '../ui/profile/edit_profile_page.dart';
import '../ui/profile/profile_page.dart';
import '../ui/profile_visitors/profile_visitors_page.dart';
import '../ui/ranks/ranks_page.dart';
import '../ui/search/search_page.dart';
import '../ui/store-bag/mybag_page.dart';
import '../ui/store-bag/store_page.dart';
import '../ui/vip_page/vip_page.dart';
import '../ui/settings/password_settings_page.dart';
import '../ui/settings/settings_page.dart';
import '../ui/settings/language_selection_page.dart';
import '../ui/settings/about_us_page.dart';

class MyRouter {
  static final GlobalKey<NavigatorState> rootNavigatorKey =
      GlobalKey<NavigatorState>();

  static final publicRoutes = {
    Routes.login.path,
    Routes.forgetPassword.path,
    Routes.verifyOTP.path,
    Routes.changePassword.path,
    Routes.register.path,
  };

  // Changed to a factory method to initialize the listener
  static final router = _createRouter();

  static GoRouter _createRouter() {
    final goRouter = GoRouter(
      navigatorKey: rootNavigatorKey,
      debugLogDiagnostics: true,
      initialLocation: Routes.home.path,
      redirect: (context, state) async {
        if (publicRoutes.any((route) => state.fullPath!.endsWith(route))) {
          return null;
        }
        final isLoggedIn = await GetIt.I<SecureStorage>().isLoggedIn;
        if (!isLoggedIn) return Routes.login.path;
        return null;
      },
      routes: [
        // --- [NEW] MASTER SHELL ROUTE ---
        // This wraps ALL your existing routes to provide the persistent overlay
        ShellRoute(
          builder: (context, state, child) {
            // Check if we are on a public page (Login, Register, OTP, etc.)
            final bool isPublicPage = publicRoutes.any(
              (route) => state.matchedLocation.endsWith(route),
            );

            // If it's a public page, just return the page (no overlay)
            if (isPublicPage) {
              return child;
            }

            // If it's a private page, wrap it in a Stack with the Overlay
            return Stack(
              children: [
                child, // The actual page content
                const BigWinnerOverlay(), // The floating winner notification
              ],
            );
          },
          routes: [
            ShellRoute(
              builder: (context, state, child) {
                int page = 0;
                if (state.fullPath!.contains(Routes.status.path)) {
                  page = 1;
                } else if (state.fullPath!.contains(Routes.hostPage.path)) {
                  page = 2;
                } else if (state.fullPath!.contains(Routes.inbox.path)) {
                  page = 3;
                } else if (state.fullPath!.contains(Routes.profile.path)) {
                  page = 4;
                }
                return MainPage(selectedPageNo: page, child: child);
              },
              routes: [
                GoRoute(
                  path: Routes.home.path,
                  pageBuilder: (context, state) => NoTransitionPage<void>(
                    key: state.pageKey,
                    child: HomePage(),
                  ),
                ),
                GoRoute(
                  path: Routes.search.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: SearchPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 300),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.status.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: NewsfeedPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 300),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.myFeed.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: MyFeedPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 300),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.hostPage.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: HostPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 300),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.inbox.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: InboxPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 300),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.history.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const Scaffold(body: Center(child: Text("history"))),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.profile.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: ProfilePage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.editProfile.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: EditProfilePage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.settingsPage.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: SettingsPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.passwordSettings.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: PasswordSettingsPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.applyHosting.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: ApplyHostingPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.languageSelection.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const LanguageSelectionPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.applyAgency.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: ApplyAgencyPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.liveNow.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const LiveNowPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
                GoRoute(
                  path: Routes.aboutUs.path,
                  pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const AboutUsPage(),
                    transitionsBuilder: customPopTransition,
                    transitionDuration: const Duration(milliseconds: 200),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 100,
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/room/:roomId',
              redirect: (context, state) {
                final roomId = state.pathParameters['roomId'];
                final type = state
                    .uri
                    .queryParameters['type']; // 'audio', 'video', 'live'

                if (roomId == null) return Routes.home.path;

                if (type == 'audio') {
                  return "${Routes.audioRoom.path}?roomId=$roomId";
                } else if (type == 'video') {
                  return "${Routes.videoRoom.path}?roomId=$roomId";
                } else if (type == 'live') {
                  return "${Routes.liveStream.path}?roomId=$roomId";
                }

                return Routes.home.path;
              },
            ),
            GoRoute(
              path: Routes.audioRoom.path,
              pageBuilder: (context, state) {
                String roomId = '';
                bool isHost = false;

                if (state.extra != null &&
                    state.extra is Map<String, dynamic>) {
                  final data = state.extra as Map<String, dynamic>;
                  roomId = data['roomId'] as String;
                  isHost = data['isHost'] as bool;
                } else {
                  roomId = state.uri.queryParameters['roomId'] ?? '';
                }

                return CustomTransitionPage<void>(
                  key: state.pageKey,
                  child: AudioRoomPage(roomID: roomId, isHost: isHost),
                  transitionsBuilder: customSlideTransition,
                  transitionDuration: const Duration(milliseconds: 250),
                  reverseTransitionDuration: const Duration(milliseconds: 200),
                );
              },
            ),
            GoRoute(
              path: Routes.liveStream.path,
              pageBuilder: (context, state) {
                String roomId = '';
                bool isHost = false;

                if (state.extra != null &&
                    state.extra is Map<String, dynamic>) {
                  final data = state.extra as Map<String, dynamic>;
                  roomId = data['roomId'] as String;
                  isHost = data['isHost'] as bool;
                } else {
                  roomId = state.uri.queryParameters['roomId'] ?? '';
                }

                return CustomTransitionPage<void>(
                  key: state.pageKey,
                  child: LiveStreamPage(roomID: roomId, isHost: isHost),
                  transitionsBuilder: customSlideTransition,
                  transitionDuration: const Duration(milliseconds: 250),
                  reverseTransitionDuration: const Duration(milliseconds: 200),
                );
              },
            ),
            GoRoute(
              path: Routes.chat.path,
              pageBuilder: (context, state) {
                final args = state.extra as Map<String, dynamic>;

                return CustomTransitionPage<void>(
                  key: state.pageKey,
                  child: ChatPage(
                    peerId: args['peerId'] ?? '',
                    peerName: args['peerName'] ?? 'Unknown',
                    peerAvatar: args['peerAvatar'] ?? '',
                  ),
                  transitionsBuilder: customSlideTransition,
                  transitionDuration: const Duration(milliseconds: 250),
                  reverseTransitionDuration: const Duration(milliseconds: 200),
                );
              },
            ),
            GoRoute(
              path: Routes.greedy.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: GreedyGamePage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.spinner.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: FruitsKingPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.topUp.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: TopUpPage(beansCount: 12745),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.earnings.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: EarningsPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.vip.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: VIPPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.myInvites.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: MyInvitesPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.visitors.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: ProfileVisitorsPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.store.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: StorePage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.myBag.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: MyBagPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.myLevel.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: MyLevelPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.ranks.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: RanksPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.feedback.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: FeedbackPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.login.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: LoginPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.register.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: RegisterPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.forgetPassword.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: ForgetPasswordPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.verifyOTP.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: VerifyOTPPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
            GoRoute(
              path: Routes.changePassword.path,
              pageBuilder: (context, state) => CustomTransitionPage<void>(
                key: state.pageKey,
                child: ChangePasswordPage(),
                transitionsBuilder: customSlideTransition,
                transitionDuration: const Duration(milliseconds: 250),
                reverseTransitionDuration: const Duration(milliseconds: 200),
              ),
            ),
          ],
        ),
      ],
      errorPageBuilder: (context, state) => MaterialPage<void>(
        key: state.pageKey,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.red,
            title: const Text("Error 404"),
          ),
          body: const Center(child: Text("Page not found.")),
        ),
      ),
    );

    // --- Setup Listener for Warm/Background Starts ---
    final appLinks = AppLinks();
    appLinks.uriLinkStream.listen((uri) {
      final location = uri.path + (uri.hasQuery ? '?${uri.query}' : '');
      debugPrint('AppLinks stream received: $location');
      goRouter.go(location);
    });

    return goRouter;
  }
}

Widget customPopTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return ScaleTransition(
    scale: Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.ease)),
    child: child,
  );
}

Widget customSlideTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.decelerate)),
    child: child,
  );
}

Widget noTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return child;
}
