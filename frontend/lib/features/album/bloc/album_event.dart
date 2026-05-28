abstract class AlbumEvent {}

class FetchAlbumDetailEvent extends AlbumEvent {
  final String albumId;
  FetchAlbumDetailEvent(this.albumId);
}
