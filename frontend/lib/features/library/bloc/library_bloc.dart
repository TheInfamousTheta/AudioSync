import 'package:flutter/foundation.dart';
import 'package:audio_sync/core/network/api_client.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/features/library/bloc/library_event.dart';
import 'package:audio_sync/features/library/bloc/library_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  final ApiClient _apiClient = ApiClient();

  LibraryBloc() : super(LibraryLoadingState()) {
    on<LoadLibraryEvent>((event, emit) async {
      emit(LibraryLoadingState());
      try {
        await _fetchAndEmitLibrary(emit);
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isNetworkError = errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed to connect') ||
            errStr.contains('connection refused') ||
            errStr.contains('timeout') ||
            errStr.contains('conduit' ) ||
            errStr.contains('failed to communicate');

        if (isNetworkError) {
          debugPrint('LibraryBloc: Network connection error. Emitting successful state for offline use.');
          emit(
            LibrarySuccessState(
              favoriteAlbums: const [],
              favoriteTracks: const [],
              customPlaylists: const [],
            ),
          );
        } else {
          emit(LibraryFailureState(e.toString()));
        }
      }
    });

    on<CreatePlaylistEvent>((event, emit) async {
      try {
        await _apiClient.createPlaylist(
          event.name,
          description: event.description,
          tags: event.tags,
        );
        await _fetchAndEmitLibrary(emit);
      } catch (e) {
        emit(LibraryFailureState(e.toString()));
      }
    });

    on<DeletePlaylistEvent>((event, emit) async {
      try {
        await _apiClient.deletePlaylist(event.playlistId);
        await _fetchAndEmitLibrary(emit);
      } catch (e) {
        emit(LibraryFailureState(e.toString()));
      }
    });

    on<AddTrackToPlaylistEvent>((event, emit) async {
      try {
        final trackJson = {
          'id': event.track.id,
          'title': event.track.title,
          'artistName': event.track.artistName,
          'albumTitle': event.track.albumTitle,
          'coverArtUrl': event.track.coverArtUrl,
          'audioStreamUrl': event.track.audioStreamUrl,
          'formatBadge': event.track.formatBadge,
          'durationInSeconds': event.track.durationInSeconds,
        };
        await _apiClient.addTrackToPlaylist(event.playlistId, trackJson);
        await _fetchAndEmitLibrary(emit);
      } catch (e) {
        emit(LibraryFailureState(e.toString()));
      }
    });

    on<RemoveTrackFromPlaylistEvent>((event, emit) async {
      try {
        await _apiClient.removeTrackFromPlaylist(event.playlistId, event.trackId);
        await _fetchAndEmitLibrary(emit);
      } catch (e) {
        emit(LibraryFailureState(e.toString()));
      }
    });

    on<ToggleFavoriteTrackEvent>((event, emit) async {
      try {
        final trackJson = {
          'id': event.track.id,
          'title': event.track.title,
          'artistName': event.track.artistName,
          'albumTitle': event.track.albumTitle,
          'coverArtUrl': event.track.coverArtUrl,
          'audioStreamUrl': event.track.audioStreamUrl,
          'formatBadge': event.track.formatBadge,
          'durationInSeconds': event.track.durationInSeconds,
        };
        await _apiClient.toggleFavorite('track', trackJson);
        await _fetchAndEmitLibrary(emit);
      } catch (e) {
        emit(LibraryFailureState(e.toString()));
      }
    });

    on<ToggleFavoriteAlbumEvent>((event, emit) async {
      try {
        final albumJson = {
          'id': event.album.id,
          'title': event.album.title,
          'coverArtUrl': event.album.coverArtUrl,
          'artistName': event.album.artistName,
        };
        await _apiClient.toggleFavorite('album', albumJson);
        await _fetchAndEmitLibrary(emit);
      } catch (e) {
        emit(LibraryFailureState(e.toString()));
      }
    });
  }

  Future<void> _fetchAndEmitLibrary(Emitter<LibraryState> emit) async {
    final playlistsJson = await _apiClient.fetchPlaylists();
    final favoritesJson = await _apiClient.fetchFavorites();

    final List<dynamic> rawTracks = favoritesJson['tracks'] ?? [];
    final List<dynamic> rawAlbums = favoritesJson['albums'] ?? [];

    final favoriteTracks = rawTracks
        .whereType<Map<String, dynamic>>()
        .map(MediaTrack.fromJson)
        .toList();

    final favoriteAlbums = rawAlbums
        .whereType<Map<String, dynamic>>()
        .map(MediaAlbum.fromJson)
        .toList();

    emit(
      LibrarySuccessState(
        favoriteAlbums: favoriteAlbums,
        favoriteTracks: favoriteTracks,
        customPlaylists: playlistsJson,
      ),
    );
  }
}
