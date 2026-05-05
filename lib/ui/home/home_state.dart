import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeState extends Equatable {
  final User? user;
  final bool isLoading;
  final String selectedCountry;
  final Map<String, int> countryCounts;

  const HomeState({
    this.user,
    this.isLoading = true,
    this.selectedCountry = 'Global',
    this.countryCounts = const {},
  });

  HomeState copyWith({
    User? user,
    bool? isLoading,
    String? selectedCountry,
    Map<String, int>? countryCounts,
  }) {
    return HomeState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      selectedCountry: selectedCountry ?? this.selectedCountry,
      countryCounts: countryCounts ?? this.countryCounts,
    );
  }

  @override
  List<Object?> get props => [user, isLoading, selectedCountry, countryCounts];
}