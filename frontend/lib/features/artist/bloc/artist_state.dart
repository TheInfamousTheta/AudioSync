// lib/features/artist/bloc/artist_state.dart
import 'package:audio_sync/features/artist/models/artist_payload.dart';

abstract class ArtistState {}

class ArtistLoadingState extends ArtistState {}

class ArtistFailureState extends ArtistState {
  final String errorMessage;
  ArtistFailureState(this.errorMessage);
}

class ArtistSuccessState extends ArtistState {
  final ArtistProfile profile;
  ArtistSuccessState(this.profile);
}
