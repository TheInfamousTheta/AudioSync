import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/network/api_client.dart';
import 'package:audio_sync/core/widgets/download_manager.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';

// EVENTS
abstract class DownloadEvent {}

class LoadDownloadsEvent extends DownloadEvent {}

class StartDownloadTrackEvent extends DownloadEvent {
  final MediaTrack track;
  StartDownloadTrackEvent(this.track);
}

class DeleteDownloadedTrackEvent extends DownloadEvent {
  final String trackId;
  DeleteDownloadedTrackEvent(this.trackId);
}

class DownloadProgressUpdatedEvent extends DownloadEvent {
  final Map<String, double> progress;
  DownloadProgressUpdatedEvent(this.progress);
}

// STATES
abstract class DownloadState {}

class DownloadInitialState extends DownloadState {}

class DownloadLoadingState extends DownloadState {}

class DownloadSuccessState extends DownloadState {
  final List<MediaTrack> localTracks;
  final List<MediaTrack> remoteTracks; // Recorded on backend but not offline on this device
  final Map<String, double> progress;

  DownloadSuccessState({
    required this.localTracks,
    required this.remoteTracks,
    required this.progress,
  });

  List<MediaTrack> get allTracks {
    final ids = localTracks.map((t) => t.id).toSet();
    final combined = List<MediaTrack>.from(localTracks);
    for (final r in remoteTracks) {
      if (!ids.contains(r.id)) {
        combined.add(r);
      }
    }
    return combined;
  }
}

class DownloadFailureState extends DownloadState {
  final String message;
  DownloadFailureState(this.message);
}

// BLOC
class DownloadBloc extends Bloc<DownloadEvent, DownloadState> {
  final ApiClient _apiClient = ApiClient();
  final DownloadManager _downloadManager = DownloadManager();
  StreamSubscription? _progressSubscription;

  DownloadBloc() : super(DownloadInitialState()) {
    _progressSubscription = _downloadManager.progressStream.listen((progress) {
      add(DownloadProgressUpdatedEvent(progress));
    });

    on<LoadDownloadsEvent>((event, emit) async {
      emit(DownloadLoadingState());
      await _loadAndEmit(emit);
    });

    on<DownloadProgressUpdatedEvent>((event, emit) {
      final currentState = state;
      if (currentState is DownloadSuccessState) {
        emit(
          DownloadSuccessState(
            localTracks: currentState.localTracks,
            remoteTracks: currentState.remoteTracks,
            progress: event.progress,
          ),
        );
      }
    });

    on<StartDownloadTrackEvent>((event, emit) async {
      // Async trigger download in manager
      unawaited(_downloadManager.downloadTrack(event.track).then((_) async {
        // Once completed offline, try sync to backend
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
          await _apiClient.syncDownloadedTrack(trackJson);
        } catch (_) {}
        add(LoadDownloadsEvent());
      }));
    });

    on<DeleteDownloadedTrackEvent>((event, emit) async {
      try {
        await _downloadManager.deleteTrack(event.trackId);
        try {
          await _apiClient.deleteSyncedTrack(event.trackId);
        } catch (_) {}
        await _loadAndEmit(emit);
      } catch (e) {
        emit(DownloadFailureState(e.toString()));
      }
    });
  }

  Future<void> _loadAndEmit(Emitter<DownloadState> emit) async {
    try {
      final local = await _downloadManager.getDownloadedTracks();
      List<MediaTrack> remote = [];

      try {
        final syncedJson = await _apiClient.fetchDownloadedTracks();
        final syncedTracks = syncedJson
            .whereType<Map<String, dynamic>>()
            .map(MediaTrack.fromJson)
            .toList();

        final localIds = local.map((t) => t.id).toSet();
        remote = syncedTracks.where((t) => !localIds.contains(t.id)).toList();
      } catch (e) {
        debugPrint('DownloadBloc: Sync listing failed (probably offline): $e');
      }

      emit(
        DownloadSuccessState(
          localTracks: local,
          remoteTracks: remote,
          progress: _downloadManager.currentProgress,
        ),
      );
    } catch (e) {
      emit(DownloadFailureState(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _progressSubscription?.cancel();
    return super.close();
  }
}
