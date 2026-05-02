enum Routes {
  login,
  register,
  forgetPassword,
  verifyOTP,
  changePassword,
  home,
  audioRoom,
  status,
  offer,
  qrCode,
  history,
  more,
  profile,
  topUp,
  earnings,
  store,
  myBag,
  myLevel,
  feedback,
  vip,
  myInvites,
  visitors,
  hostPage,
  videoRoom,
  liveStream,
  greedy,
  spinner,
  editProfile,
  applyHosting,
  applyAgency,
  inbox,
  chat,
  settingsPage,
  passwordSettings,
  ranks,
  search,
  myFeed,
}

extension RoutesExtension on Routes {
  String get path {
    switch (this) {
      case Routes.login:
        return '/login';
      case Routes.register:
        return '/register';
      case Routes.forgetPassword:
        return '/forgetPassword';
      case Routes.verifyOTP:
        return '/verifyOTP';
      case Routes.changePassword:
        return '/changePassword';
      case Routes.home:
        return '/home';
      case Routes.status:
        return '/status';
      case Routes.audioRoom:
        return '/audioRoom';
      case Routes.offer:
        return '/offer';
      case Routes.qrCode:
        return '/qrCode';
      case Routes.history:
        return '/history';
      case Routes.more:
        return '/more';
      case Routes.profile:
        return '/profile';
      case Routes.topUp:
        return '/topUp';
      case Routes.earnings:
        return '/earnings';
      case Routes.store:
        return '/store';
      case Routes.myBag:
        return '/my-bag';
      case Routes.myLevel:
        return '/my-level';
      case Routes.feedback:
        return '/feedback';
      case Routes.vip:
        return '/vip';
      case Routes.myInvites:
        return '/myInvites';
      case Routes.visitors:
        return '/visitors';
      case Routes.visitors:
        return '/visitors';
      case Routes.hostPage:
        return '/hostPage';
      case Routes.videoRoom:
        return '/videoRoom';
      case Routes.liveStream:
        return '/liveStream';
      case Routes.greedy:
        return '/greedy';
      case Routes.spinner:
        return '/spinner';
      case Routes.editProfile:
        return '/editProfile';
      case Routes.applyHosting:
        return '/applyHosting';
      case Routes.applyAgency:
        return '/applyAgency';
      case Routes.inbox:
        return '/inbox';
      case Routes.chat:
        return '/chat';
      case Routes.settingsPage:
        return '/settingsPage';
      case Routes.passwordSettings:
        return '/passwordSettings';
      case Routes.ranks:
        return '/ranks';
      case Routes.search:
        return '/search';
      case Routes.myFeed:
        return '/myFeed';
    }
  }
}
