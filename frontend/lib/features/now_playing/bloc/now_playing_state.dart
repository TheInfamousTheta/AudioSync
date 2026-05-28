import 'package:audio_sync/features/home/dashboard_payload.dart';

abstract class NowPlayingState {}

class PlayerEmptyState extends NowPlayingState {}

class PlayerActiveState extends NowPlayingState {
  final MediaTrack track;
  final bool isPlaying;
  final List<MediaTrack> queue;
  final int currentIndex;
  final bool isShuffleEnabled;
  final bool isRepeatEnabled;

  PlayerActiveState({
    required this.track,
    required this.isPlaying,
    required this.queue,
    required this.currentIndex,
    this.isShuffleEnabled = false,
    this.isRepeatEnabled = false,
  });
}
