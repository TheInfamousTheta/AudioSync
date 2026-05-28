import 'package:audio_sync/features/home/dashboard_payload.dart';

abstract class LibraryEvent {}

class LoadLibraryEvent extends LibraryEvent {}

class CreatePlaylistEvent extends LibraryEvent {
  final String name;
  final String description;
  final List<String> tags;

  CreatePlaylistEvent({
    required this.name,
    this.description = '',
    this.tags = const [],
  });
}

class DeletePlaylistEvent extends LibraryEvent {
  final String playlistId;
  DeletePlaylistEvent(this.playlistId);
}

class AddTrackToPlaylistEvent extends LibraryEvent {
  final String playlistId;
  final MediaTrack track;
  AddTrackToPlaylistEvent({required this.playlistId, required this.track});
}

class RemoveTrackFromPlaylistEvent extends LibraryEvent {
  final String playlistId;
  final String trackId;
  RemoveTrackFromPlaylistEvent({required this.playlistId, required this.trackId});
}

class ToggleFavoriteTrackEvent extends LibraryEvent {
  final MediaTrack track;
  ToggleFavoriteTrackEvent(this.track);
}

class ToggleFavoriteAlbumEvent extends LibraryEvent {
  final MediaAlbum album;
  ToggleFavoriteAlbumEvent(this.album);
}
