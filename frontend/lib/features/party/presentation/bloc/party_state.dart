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
  final String sessionToken;
  final List<String> debugLogs;
  final String debugResult;
  final bool isSimulatingDelay;

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
    this.sessionToken = '',
    this.debugLogs = const [],
    this.debugResult = 'Standing by for synchronization...',
    this.isSimulatingDelay = false,
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
    String? sessionToken,
    List<String>? debugLogs,
    String? debugResult,
    bool? isSimulatingDelay,
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
      sessionToken: sessionToken ?? this.sessionToken,
      debugLogs: debugLogs ?? this.debugLogs,
      debugResult: debugResult ?? this.debugResult,
      isSimulatingDelay: isSimulatingDelay ?? this.isSimulatingDelay,
    );
  }
}

class PartyFailureState extends PartyState {
  final String errorMessage;
  PartyFailureState(this.errorMessage);
}
