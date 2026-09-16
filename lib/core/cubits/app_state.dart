part of 'app_cubit.dart';

class MinimizedRoomData extends Equatable {
  final String roomId;
  final String hostPicture;
  final String hostName;
  final bool isAudioRoom;
  final bool isHost;

  const MinimizedRoomData({
    required this.roomId,
    required this.hostPicture,
    required this.hostName,
    required this.isAudioRoom,
    required this.isHost,
  });

  @override
  List<Object?> get props => [roomId, hostPicture, hostName, isAudioRoom, isHost];
}

class AppState extends Equatable {
  final User? user;
  final Locale locale;
  final MinimizedRoomData? minimizedRoom;
  final bool isUpdateRequired;
  final String updateUrl;

  const AppState({
    this.user,
    this.locale = const Locale('en'),
    this.minimizedRoom,
    this.isUpdateRequired = false,
    this.updateUrl = '',
  });

  @override
  List<Object?> get props => [user, locale, minimizedRoom, isUpdateRequired, updateUrl];

  AppState copyWith({
    User? user,
    Locale? locale,
    MinimizedRoomData? minimizedRoom,
    bool clearMinimizedRoom = false,
    bool? isUpdateRequired,
    String? updateUrl,
  }) {
    return AppState(
      user: user ?? this.user,
      locale: locale ?? this.locale,
      minimizedRoom: clearMinimizedRoom ? null : (minimizedRoom ?? this.minimizedRoom),
      isUpdateRequired: isUpdateRequired ?? this.isUpdateRequired,
      updateUrl: updateUrl ?? this.updateUrl,
    );
  }

  removeUser() {
    return AppState(
      user: null, 
      locale: locale, 
      isUpdateRequired: isUpdateRequired, 
      updateUrl: updateUrl,
    );
  }
}
