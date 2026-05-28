// lib/features/home/bloc/home_state.dart
import 'package:audio_sync/features/home/dashboard_payload.dart';

abstract class HomeState {}

class HomeLoadingState extends HomeState {}

class HomeSuccessState extends HomeState {
  final MediaAlbum? featured;
  final List<MediaTrack> recentlyPlayed;
  final List<MediaAlbum> madeForYou;
  final List<MediaTrack> newReleases;

  HomeSuccessState({
    required this.featured,
    required this.recentlyPlayed,
    required this.madeForYou,
    required this.newReleases,
  });
}

class HomeFailureState extends HomeState {
  final String errorMessage;
  HomeFailureState(this.errorMessage);
}
