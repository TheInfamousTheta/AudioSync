import 'package:audio_sync/features/album/models/album_payload.dart';

abstract class AlbumState {}

class AlbumLoadingState extends AlbumState {}

class AlbumFailureState extends AlbumState {
  final String errorMessage;
  AlbumFailureState(this.errorMessage);
}

class AlbumSuccessState extends AlbumState {
  final AlbumDetailPayload album;
  AlbumSuccessState(this.album);
}
