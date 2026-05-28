import 'package:audio_sync/features/home/dashboard_payload.dart';

abstract class NowPlayingEvent {}

class LoadTrackEvent extends NowPlayingEvent {
  final MediaTrack track;
  LoadTrackEvent(this.track);
}

class TogglePlaybackEvent extends NowPlayingEvent {}

class SeekPositionEvent extends NowPlayingEvent {
  final Duration position;
  SeekPositionEvent(this.position);
}

class PlayNextEvent extends NowPlayingEvent {}

class PlayPreviousEvent extends NowPlayingEvent {}

class ToggleShuffleEvent extends NowPlayingEvent {}

class ToggleRepeatEvent extends NowPlayingEvent {}

class UpdateQueueEvent extends NowPlayingEvent {
  final List<MediaTrack> tracks;
  final int initialIndex;
  UpdateQueueEvent({required this.tracks, required this.initialIndex});
}

class AddToQueueEvent extends NowPlayingEvent {
  final MediaTrack track;
  AddToQueueEvent(this.track);
}
