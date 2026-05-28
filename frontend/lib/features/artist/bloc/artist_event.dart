// lib/features/artist/bloc/artist_event.dart
abstract class ArtistEvent {}

class FetchArtistDataEvent extends ArtistEvent {
  final String artistId;
  FetchArtistDataEvent(this.artistId);
}
