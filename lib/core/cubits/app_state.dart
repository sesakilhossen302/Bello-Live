part of 'app_cubit.dart';

class AppState extends Equatable {
  final User? user;

  const AppState({this.user});

  @override
  List<Object> get props => [?user];

  AppState copyWith({User? user}) {
    return AppState(user: user ?? this.user);
  }

  removeUser() {
    return AppState(user: null);
  }
}
