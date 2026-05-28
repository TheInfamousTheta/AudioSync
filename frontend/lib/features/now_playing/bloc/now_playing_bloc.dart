import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_sync/core/widgets/audio_systems_manager.dart';
import 'package:audio_sync/core/widgets/audio_cache_manager.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_event.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_state.dart';

class PlayerPlayingStateChangedEvent extends NowPlayingEvent {
  final bool isPlaying;
  PlayerPlayingStateChangedEvent(this.isPlaying);
}

class NowPlayingBloc extends Bloc<NowPlayingEvent, NowPlayingState> {
  final AudioSystemManager _audioManager = AudioSystemManager();
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<ProcessingState>? _processingStateSubscription;

  NowPlayingBloc() : super(PlayerEmptyState()) {
    _playingSubscription = _audioManager.player.playingStream.listen((playing) {
      add(PlayerPlayingStateChangedEvent(playing));
    });

    _processingStateSubscription = _audioManager.player.processingStateStream.listen((processingState) {
      if (processingState == ProcessingState.completed) {
        add(PlayNextEvent());
      }
    });

    on<LoadTrackEvent>((event, emit) async {
      final currentState = state;
      bool shuffle = false;
      bool repeat = false;
      List<MediaTrack> currentQueue = [event.track];
      int idx = 0;

      if (currentState is PlayerActiveState) {
        shuffle = currentState.isShuffleEnabled;
        repeat = currentState.isRepeatEnabled;
        final existingIdx = currentState.queue.indexWhere((t) => t.id == event.track.id);
        if (existingIdx != -1) {
          currentQueue = currentState.queue;
          idx = existingIdx;
        }
      }

      if (currentState is PlayerActiveState && currentState.track.id == event.track.id) {
        _audioManager.togglePlayPause();
      } else {
        emit(PlayerActiveState(
          track: event.track,
          isPlaying: true,
          queue: currentQueue,
          currentIndex: idx,
          isShuffleEnabled: shuffle,
          isRepeatEnabled: repeat,
        ));
        await _audioManager.playTrack(event.track);
        _preCacheQueue(currentQueue, idx);
      }
    });

    on<UpdateQueueEvent>((event, emit) async {
      if (event.tracks.isEmpty) return;
      final initialIndex = event.initialIndex.clamp(0, event.tracks.length - 1);
      final track = event.tracks[initialIndex];

      bool shuffle = false;
      bool repeat = false;
      if (state is PlayerActiveState) {
        final s = state as PlayerActiveState;
        shuffle = s.isShuffleEnabled;
        repeat = s.isRepeatEnabled;
      }

      emit(PlayerActiveState(
        track: track,
        isPlaying: true,
        queue: event.tracks,
        currentIndex: initialIndex,
        isShuffleEnabled: shuffle,
        isRepeatEnabled: repeat,
      ));
      await _audioManager.playTrack(track);
      _preCacheQueue(event.tracks, initialIndex);
    });

    on<PlayerPlayingStateChangedEvent>((event, emit) {
      final currentState = state;
      if (currentState is PlayerActiveState) {
        emit(PlayerActiveState(
          track: currentState.track,
          isPlaying: event.isPlaying,
          queue: currentState.queue,
          currentIndex: currentState.currentIndex,
          isShuffleEnabled: currentState.isShuffleEnabled,
          isRepeatEnabled: currentState.isRepeatEnabled,
        ));
      }
    });

    on<TogglePlaybackEvent>((event, emit) {
      if (state is PlayerActiveState) {
        _audioManager.togglePlayPause();
      }
    });

    on<SeekPositionEvent>((event, emit) {
      _audioManager.player.seek(event.position);
    });

    on<PlayNextEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PlayerActiveState) return;

      final queue = currentState.queue;
      if (queue.isEmpty) return;

      int nextIndex = currentState.currentIndex + 1;
      if (currentState.isShuffleEnabled) {
        nextIndex = DateTime.now().millisecond % queue.length;
      } else if (nextIndex >= queue.length) {
        if (currentState.isRepeatEnabled) {
          nextIndex = 0;
        } else {
          nextIndex = currentState.currentIndex;
          return;
        }
      }

      final nextTrack = queue[nextIndex];
      emit(PlayerActiveState(
        track: nextTrack,
        isPlaying: true,
        queue: queue,
        currentIndex: nextIndex,
        isShuffleEnabled: currentState.isShuffleEnabled,
        isRepeatEnabled: currentState.isRepeatEnabled,
      ));
      await _audioManager.playTrack(nextTrack);
      _preCacheQueue(queue, nextIndex);
    });

    on<PlayPreviousEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PlayerActiveState) return;

      final queue = currentState.queue;
      if (queue.isEmpty) return;

      int prevIndex = currentState.currentIndex - 1;
      if (currentState.isShuffleEnabled) {
        prevIndex = DateTime.now().millisecond % queue.length;
      } else if (prevIndex < 0) {
        if (currentState.isRepeatEnabled) {
          prevIndex = queue.length - 1;
        } else {
          prevIndex = 0;
        }
      }

      final prevTrack = queue[prevIndex];
      emit(PlayerActiveState(
        track: prevTrack,
        isPlaying: true,
        queue: queue,
        currentIndex: prevIndex,
        isShuffleEnabled: currentState.isShuffleEnabled,
        isRepeatEnabled: currentState.isRepeatEnabled,
      ));
      await _audioManager.playTrack(prevTrack);
      _preCacheQueue(queue, prevIndex);
    });

    on<ToggleShuffleEvent>((event, emit) {
      final currentState = state;
      if (currentState is PlayerActiveState) {
        emit(PlayerActiveState(
          track: currentState.track,
          isPlaying: currentState.isPlaying,
          queue: currentState.queue,
          currentIndex: currentState.currentIndex,
          isShuffleEnabled: !currentState.isShuffleEnabled,
          isRepeatEnabled: currentState.isRepeatEnabled,
        ));
      }
    });

    on<ToggleRepeatEvent>((event, emit) {
      final currentState = state;
      if (currentState is PlayerActiveState) {
        emit(PlayerActiveState(
          track: currentState.track,
          isPlaying: currentState.isPlaying,
          queue: currentState.queue,
          currentIndex: currentState.currentIndex,
          isShuffleEnabled: currentState.isShuffleEnabled,
          isRepeatEnabled: !currentState.isRepeatEnabled,
        ));
      }
    });

    on<AddToQueueEvent>((event, emit) {
      final currentState = state;
      if (currentState is PlayerActiveState) {
        if (!currentState.queue.any((t) => t.id == event.track.id)) {
          final updatedQueue = List<MediaTrack>.from(currentState.queue)..add(event.track);
          emit(PlayerActiveState(
            track: currentState.track,
            isPlaying: currentState.isPlaying,
            queue: updatedQueue,
            currentIndex: currentState.currentIndex,
            isShuffleEnabled: currentState.isShuffleEnabled,
            isRepeatEnabled: currentState.isRepeatEnabled,
          ));
          _preCacheQueue(updatedQueue, currentState.currentIndex);
        }
      } else {
        final newQueue = [event.track];
        emit(PlayerActiveState(
          track: event.track,
          isPlaying: false,
          queue: newQueue,
          currentIndex: 0,
          isShuffleEnabled: false,
          isRepeatEnabled: false,
        ));
        _preCacheQueue(newQueue, 0);
      }
    });

    _preCacheQueue(state is PlayerActiveState ? (state as PlayerActiveState).queue : [], state is PlayerActiveState ? (state as PlayerActiveState).currentIndex : 0);
  }

  void _preCacheQueue(List<MediaTrack> queue, int currentIndex) {
    if (queue.isEmpty) return;
    final cacheManager = MidnightAudioCache();
    for (int i = 1; i <= 5; i++) {
      final targetIndex = currentIndex + i;
      if (targetIndex < queue.length) {
        final track = queue[targetIndex];
        cacheManager.preCacheTrack(track.id, track.audioStreamUrl);
      }
    }
  }

  @override
  Future<void> close() {
    _playingSubscription?.cancel();
    _processingStateSubscription?.cancel();
    return super.close();
  }
}
