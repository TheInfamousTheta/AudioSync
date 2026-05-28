import 'package:audio_sync/features/home/dashboard_payload.dart';

abstract class PartyState {}

class PartyInitialState extends PartyState {}

class PartyLoadingState extends PartyState {}

class PartyInviteResolvedState extends PartyState {
  final Map<String, dynamic> party;
  final bool isAlreadyMember;
  PartyInviteResolvedState({required this.party, required this.isAlreadyMember});
}

class PartyJoinedState extends PartyState {
  final String partyId;
  final String hostId;
  final String inviteCode;
  final List<dynamic> members;
  final List<MediaTrack> playlist;
  final MediaTrack? activeTrack;
  final bool isPlaying;
  final bool isHost;
  final bool isOffline;

  PartyJoinedState({
    required this.partyId,
    required this.hostId,
    required this.inviteCode,
    required this.members,
    required this.playlist,
    this.activeTrack,
    this.isPlaying = false,
    required this.isHost,
    this.isOffline = false,
  });

  PartyJoinedState copyWith({
    String? partyId,
    String? hostId,
    String? inviteCode,
    List<dynamic>? members,
    List<MediaTrack>? playlist,
    MediaTrack? activeTrack,
    bool? isPlaying,
    bool? isHost,
    bool? isOffline,
  }) {
    return PartyJoinedState(
      partyId: partyId ?? this.partyId,
      hostId: hostId ?? this.hostId,
      inviteCode: inviteCode ?? this.inviteCode,
      members: members ?? this.members,
      playlist: playlist ?? this.playlist,
      activeTrack: activeTrack ?? this.activeTrack,
      isPlaying: isPlaying ?? this.isPlaying,
      isHost: isHost ?? this.isHost,
      isOffline: isOffline ?? this.isOffline,
    );
  }
}

class PartyFailureState extends PartyState {
  final String errorMessage;
  PartyFailureState(this.errorMessage);
}
