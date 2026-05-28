import 'package:audio_sync/features/home/dashboard_payload.dart';

abstract class SearchState {}

class SearchInitialState extends SearchState {}

class SearchLoadingState extends SearchState {}

class SearchSuccessState extends SearchState {
  final List<MediaTrack> songs;
  final List<MediaAlbum> albums;

  SearchSuccessState({required this.songs, required this.albums});
}

class SearchFailureState extends SearchState {
  final String errorMessage;

  SearchFailureState(this.errorMessage);
}
