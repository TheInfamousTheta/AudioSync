import 'package:audio_sync/core/network/api_client.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/features/search/bloc/search_event.dart';
import 'package:audio_sync/features/search/bloc/search_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final ApiClient _apiClient = ApiClient();

  String currentQuery = '';

  SearchBloc() : super(SearchInitialState()) {
    on<TriggerQueryEvent>((event, emit) async {
      currentQuery = event.query;
      if (event.query.trim().isEmpty) {
        emit(SearchInitialState());
        return;
      }

      emit(SearchLoadingState());

      try {
        final result = await _apiClient.searchTracks(event.query);

        final List<dynamic> rawSongs = result['songs'] ?? [];
        final List<dynamic> rawAlbums = result['albums'] ?? [];

        final songs = rawSongs
            .whereType<Map<String, dynamic>>()
            .map(MediaTrack.fromJson)
            .toList();
        final albums = rawAlbums
            .whereType<Map<String, dynamic>>()
            .map(MediaAlbum.fromJson)
            .toList();

        emit(SearchSuccessState(songs: songs, albums: albums));
      } catch (e) {
        emit(SearchFailureState(e.toString()));
      }
    });

    on<ClearSearchEvent>((event, emit) {
      currentQuery = '';
      emit(SearchInitialState());
    });
  }
}
