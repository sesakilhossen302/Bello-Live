import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeState extends Equatable {
  final User? user;
  final bool isLoading;

  const HomeState({this.user, this.isLoading = true});

  HomeState copyWith({User? user, bool? isLoading}) {
    return HomeState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [user, isLoading];
}