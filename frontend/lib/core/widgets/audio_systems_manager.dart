import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:rxdart/rxdart.dart';
import 'package:flutter/services.dart';
import 'package:audio_sync/core/widgets/audio_cache_manager.dart';
import 'package:audio_sync/core/widgets/download_manager.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';

class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;

  PositionData(this.position, this.bufferedPosition, this.duration);
}

class AudioSystemManager {
  static final AudioSystemManager _instance = AudioSystemManager._internal();
  factory AudioSystemManager() => _instance;

  static const _effectsChannel = MethodChannel('com.midnight.audio_sync/audio_effects');
  static const _routingChannel = MethodChannel('com.midnight.audio_sync/audio_routing');

  static AudioHandler? audioHandler;

  late final AudioPlayer _player;
  MediaTrack? _currentTrack;
  String _reverbPreset = 'Studio';

  static final Map<String, List<double>> eqPresets = {
    'Flat': [0.0, 0.0, 0.0, 0.0, 0.0],
    'Rock': [4.0, 2.0, -1.0, 2.0, 4.0],
    'Pop': [-1.0, 2.0, 4.0, 2.0, -1.0],
    'Classical': [4.0, 3.0, 0.0, 2.0, 3.0],
    'Jazz': [3.0, 2.0, 1.0, 2.0, 3.0],
    'Electronic': [4.0, 1.0, 0.0, 2.0, 4.0],
    'Vocal': [-2.0, -1.0, 3.0, 4.0, 1.0],
    'Bass Boost': [6.0, 4.0, 0.0, 0.0, 0.0],
  };

  String _activeEqPreset = 'Flat';
  String get activeEqPreset => _activeEqPreset;
  final Map<String, double> _equalizerBands = {
    'Bass': 0.0,
    'Low-Mid': 0.0,
    'Mid': 0.0,
    'High-Mid': 0.0,
    'Treble': 0.0,
  };

  AudioSystemManager._internal() {
    _player = AudioPlayer();
    _player.androidAudioSessionIdStream.listen((sessionId) {
      if (sessionId != null && sessionId > 0) {
        _initNativeEffects(sessionId);
      }
    });
  }

  Future<void> _initNativeEffects(int sessionId) async {
    try {
      await _effectsChannel.invokeMethod('initEffects', {'sessionId': sessionId});
      _equalizerBands.forEach((band, value) {
        setEqualizerBand(band, value);
      });
      setReverbPreset(_reverbPreset);
    } catch (_) {}
  }

  static Future<void> init() async {
    audioHandler = await AudioService.init(
      builder: () => MidnightAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.midnight.audio_sync.channel.audio',
        androidNotificationChannelName: 'Midnight Playback',
        androidNotificationOngoing: true,
        androidShowNotificationBadge: true,
      ),
    );

    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  }

  AudioPlayer get player => _player;
  MediaTrack? get currentTrack => _currentTrack;

  String get reverbPreset => _reverbPreset;
  Map<String, double> get equalizerBands => _equalizerBands;

  void setEqualizerBand(String band, double value) {
    _equalizerBands[band] = value;

    bool matched = false;
    eqPresets.forEach((presetName, levels) {
      final bands = ['Bass', 'Low-Mid', 'Mid', 'High-Mid', 'Treble'];
      bool allMatch = true;
      for (int i = 0; i < bands.length; i++) {
        if (_equalizerBands[bands[i]] != levels[i]) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) {
        _activeEqPreset = presetName;
        matched = true;
      }
    });
    if (!matched) {
      _activeEqPreset = 'Custom';
    }

    final bandsList = ['Bass', 'Low-Mid', 'Mid', 'High-Mid', 'Treble'];
    final bandIndex = bandsList.indexOf(band);
    if (bandIndex != -1) {
      _effectsChannel.invokeMethod('setBandLevel', {
        'band': bandIndex,
        'level': value.toInt(),
      });
    }
  }

  void applyEqPreset(String name) {
    if (eqPresets.containsKey(name)) {
      _activeEqPreset = name;
      final levels = eqPresets[name]!;
      final bands = ['Bass', 'Low-Mid', 'Mid', 'High-Mid', 'Treble'];
      for (int i = 0; i < bands.length; i++) {
        setEqualizerBand(bands[i], levels[i]);
      }
    }
  }

  void setReverbPreset(String preset) {
    _reverbPreset = preset;
    _effectsChannel.invokeMethod('setReverbPreset', {'preset': preset});
    if (preset == 'Cathedral') {
      _player.setPitch(0.92);
    } else if (preset == 'Ambient') {
      _player.setPitch(1.08);
    } else {
      _player.setPitch(1.0);
    }
  }

  Future<void> switchAudioRoute(String routeName) async {
    try {
      String routeCode = 'default';
      final lower = routeName.toLowerCase();
      if (lower.contains('speaker')) {
        routeCode = 'speaker';
      } else if (lower.contains('receiver') || lower.contains('earpiece')) {
        routeCode = 'earpiece';
      }
      await _routingChannel.invokeMethod('setAudioRoute', {'route': routeCode});
    } catch (_) {}
  }

  Future<void> playTrack(MediaTrack track) async {
    _currentTrack = track;
    if (audioHandler != null) {
      await (audioHandler as MidnightAudioHandler).playTrack(track);
    } else {
      final localPath = await DownloadManager().getLocalTrackPath(track.id);
      if (localPath != null) {
        await _player.setAudioSource(
          AudioSource.file(
            localPath,
            tag: track.title,
          ),
        );
      } else {
        final cacheFile = MidnightAudioCache().getCachedFile(track.id);
        final hasCache = await cacheFile.exists();

        if (hasCache) {
          await _player.setAudioSource(
            AudioSource.file(
              cacheFile.path,
              tag: track.title,
            ),
          );
        } else {
          await _player.setAudioSource(
            // ignore: experimental_member_use
            LockCachingAudioSource(
              Uri.parse(track.audioStreamUrl),
              tag: track.title,
            ),
          );
          MidnightAudioCache().preCacheTrack(track.id, track.audioStreamUrl);
        }
      }
      _player.play();
    }
  }

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
      );

  void togglePlayPause() {
    if (_player.playing) {
      if (audioHandler != null) {
        audioHandler!.pause();
      } else {
        _player.pause();
      }
    } else {
      if (audioHandler != null) {
        audioHandler!.play();
      } else {
        _player.play();
      }
    }
  }

  void dispose() {
    _player.dispose();
  }
}

class MidnightAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  AudioPlayer get player => AudioSystemManager().player;

  MidnightAudioHandler() {
    player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    player.sequenceStateStream.listen((sequenceState) {
      final currentSource = sequenceState.currentSource;
      if (currentSource == null) return;
      final trackTag = currentSource.tag;
      if (trackTag is MediaItem) {
        mediaItem.add(trackTag);
      }
    });
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[player.processingState]!,
      playing: player.playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: event.currentIndex,
    );
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> stop() async {
    await player.stop();
    await playbackState.firstWhere((state) => state.processingState == AudioProcessingState.idle);
  }

  Future<void> playTrack(MediaTrack track) async {
    final item = MediaItem(
      id: track.id,
      album: track.albumTitle,
      title: track.title,
      artist: track.artistName,
      duration: Duration(seconds: track.durationInSeconds),
      artUri: Uri.parse(track.coverArtUrl),
      extras: {'url': track.audioStreamUrl},
    );
    mediaItem.add(item);

    final localPath = await DownloadManager().getLocalTrackPath(track.id);
    if (localPath != null) {
      await player.setAudioSource(
        AudioSource.file(
          localPath,
          tag: item,
        ),
      );
    } else {
      final cacheFile = MidnightAudioCache().getCachedFile(track.id);
      final hasCache = await cacheFile.exists();

      if (hasCache) {
        await player.setAudioSource(
          AudioSource.file(
            cacheFile.path,
            tag: item,
          ),
        );
      } else {
        await player.setAudioSource(
          // ignore: experimental_member_use
          LockCachingAudioSource(
            Uri.parse(track.audioStreamUrl),
            tag: item,
          ),
        );
        MidnightAudioCache().preCacheTrack(track.id, track.audioStreamUrl);
      }
    }
    player.play();
  }
}
