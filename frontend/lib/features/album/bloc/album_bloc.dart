import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/network/api_client.dart';
import 'package:audio_sync/features/album/bloc/album_event.dart';
import 'package:audio_sync/features/album/bloc/album_state.dart';
import 'package:audio_sync/features/album/models/album_payload.dart';

class AlbumBloc extends Bloc<AlbumEvent, AlbumState> {
  final ApiClient _apiClient = ApiClient();

  AlbumBloc() : super(AlbumLoadingState()) {
    on<FetchAlbumDetailEvent>((event, emit) async {
      emit(AlbumLoadingState());
      try {
        final data = await _apiClient.fetchAlbumDetails(event.albumId);
        final album = AlbumDetailPayload.fromJson(data);
        emit(AlbumSuccessState(album));
      } catch (e) {
        emit(AlbumFailureState(e.toString()));
      }
    });
  }
}
