// lib/features/artist/bloc/artist_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/network/api_client.dart';
import 'package:audio_sync/features/artist/bloc/artist_event.dart';
import 'package:audio_sync/features/artist/bloc/artist_state.dart';
import 'package:audio_sync/features/artist/models/artist_payload.dart';

class ArtistBloc extends Bloc<ArtistEvent, ArtistState> {
  final ApiClient _apiClient = ApiClient();

  ArtistBloc() : super(ArtistLoadingState()) {
    on<FetchArtistDataEvent>((event, emit) async {
      emit(ArtistLoadingState());
      try {
        final data = await _apiClient.fetchArtistProfile(event.artistId);
        final profile = ArtistProfile.fromJson(data);
        emit(ArtistSuccessState(profile));
      } catch (e) {
        emit(ArtistFailureState(e.toString()));
      }
    });
  }
}
