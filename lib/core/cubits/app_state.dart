part of 'app_cubit.dart';

class AppState extends Equatable {
  final User? user;
  final Locale locale;

  const AppState({this.user, this.locale = const Locale('en')});

  @override
  List<Object?> get props => [user, locale];

  AppState copyWith({User? user, Locale? locale}) {
    return AppState(
      user: user ?? this.user,
      locale: locale ?? this.locale,
    );
  }

  removeUser() {
    return AppState(user: null, locale: locale);
  }
}
