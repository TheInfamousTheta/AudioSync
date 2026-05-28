import 'package:audio_sync/features/home/dashboard_payload.dart';

abstract class PartyEvent {}

class CreatePartyEvent extends PartyEvent {
  final String token;
  CreatePartyEvent(this.token);
}

class ResolveInviteCodeEvent extends PartyEvent {
  final String inviteCode;
  final String token;
  ResolveInviteCodeEvent({required this.inviteCode, required this.token});
}

class JoinPartyRoomEvent extends PartyEvent {
  final String partyId;
  final String token;
  JoinPartyRoomEvent({required this.partyId, required this.token});
}

class LoadPartyDetailsEvent extends PartyEvent {
  final String partyId;
  final String token;
  LoadPartyDetailsEvent({required this.partyId, required this.token});
}

class AddTrackToPartyQueueEvent extends PartyEvent {
  final MediaTrack track;
  AddTrackToPartyQueueEvent(this.track);
}

class RemoveTrackFromPartyQueueEvent extends PartyEvent {
  final String queueId;
  RemoveTrackFromPartyQueueEvent(this.queueId);
}

class PlayTrackSyncedEvent extends PartyEvent {
  final MediaTrack track;
  PlayTrackSyncedEvent(this.track);
}

class TogglePartyPlayStateEvent extends PartyEvent {}

class SeekPartyPlaybackEvent extends PartyEvent {
  final double positionInSeconds;
  SeekPartyPlaybackEvent(this.positionInSeconds);
}

class EnterOfflineSyncModeEvent extends PartyEvent {
  final String deviceId;
  final bool isHost;
  EnterOfflineSyncModeEvent({required this.deviceId, required this.isHost});
}

class DisconnectPartyEvent extends PartyEvent {}
