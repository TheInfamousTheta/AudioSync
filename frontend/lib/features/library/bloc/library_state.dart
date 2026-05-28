import 'package:audio_sync/features/home/dashboard_payload.dart';

abstract class LibraryState {}

class LibraryLoadingState extends LibraryState {}

class LibrarySuccessState extends LibraryState {
  final List<MediaAlbum> favoriteAlbums;
  final List<MediaTrack> favoriteTracks;
  final List<dynamic> customPlaylists;

  LibrarySuccessState({
    required this.favoriteAlbums,
    required this.favoriteTracks,
    required this.customPlaylists,
  });
}

class LibraryFailureState extends LibraryState {
  final String message;
  LibraryFailureState(this.message);
}
