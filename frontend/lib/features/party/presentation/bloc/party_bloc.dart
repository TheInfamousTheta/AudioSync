import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/network/api_client.dart';
import '../../data/services/party_sync_service.dart';
import 'party_event.dart';
import 'party_state.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';

class PartyBloc extends Bloc<PartyEvent, PartyState> {
  final ApiClient _apiClient = ApiClient();
  final PartySyncService _syncService = PartySyncService();
  
  StreamSubscription? _logSubscription;
  StreamSubscription? _songSubscription;
  StreamSubscription? _trackSubscription;
  String? _sessionToken;

  Future<String> _retrieveToken() async {
    if (_sessionToken != null && _sessionToken!.isNotEmpty) {
      return _sessionToken!;
    }
    try {
      final f = File('.midnight_token');
      if (await f.exists()) {
        final token = await f.readAsString();
        if (token.trim().isNotEmpty) {
          _sessionToken = token.trim();
          return _sessionToken!;
        }
      }
    } catch (_) {}
    try {
      final f = File('${Directory.systemTemp.path}/.midnight_token');
      if (await f.exists()) {
        final token = await f.readAsString();
        if (token.trim().isNotEmpty) {
          _sessionToken = token.trim();
          return _sessionToken!;
        }
      }
    } catch (_) {}
    return "";
  }

  PartyBloc() : super(PartyInitialState()) {
    
    // Wire the underlying high-fidelity synchronization engine listeners
    _syncService.onLogUpdate = (log) {
      // Direct stream to console or local system log
      print("[SYNC-CORE] $log");
    };

    _syncService.onSongStateChanged = (isPlaying) {
      final currentState = state;
      if (currentState is PartyJoinedState) {
        add(UpdatePartyDetailsEvent(
          partyId: currentState.partyId,
          token: "", // Handled inside state retention
          isPlayStateChangeOnly: true,
          isPlaying: isPlaying,
        ));
      }
    };

    _syncService.onTrackSynced = (track, isPlaying) {
      final currentState = state;
      if (currentState is PartyJoinedState) {
        add(UpdatePartyDetailsEvent(
          partyId: currentState.partyId,
          token: "",
          isPlayStateChangeOnly: true,
          isPlaying: isPlaying,
          activeTrack: track,
        ));
      }
    };

    on<CreatePartyEvent>((event, emit) async {
      emit(PartyLoadingState());
      try {
        final result = await _apiClient.createParty(event.token);
        final partyJson = result['party'];
        final partyId = partyJson['id'] as String;
        final inviteCode = partyJson['inviteCode'] as String;
        final hostId = partyJson['hostId'] as String;

        _sessionToken = event.token;

        await _syncService.initialize();
        await _syncService.connectWebSocket(partyId, event.token);

        final details = await _apiClient.fetchPartyDetails(partyId, event.token);
        final members = details['members'] as List<dynamic>;
        final playlistJson = details['playlist'] as List<dynamic>;
        final playlist = playlistJson.map((t) => MediaTrack.fromJson(t)).toList();

        emit(PartyJoinedState(
          partyId: partyId,
          hostId: hostId,
          inviteCode: inviteCode,
          members: members,
          playlist: playlist,
          isHost: true,
          isOffline: false,
          isPlaying: _syncService.isSongPlaying,
          activeTrack: _syncService.activeTrack,
        ));
      } catch (e) {
        emit(PartyFailureState(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<ResolveInviteCodeEvent>((event, emit) async {
      emit(PartyLoadingState());
      try {
        final result = await _apiClient.resolveInviteCode(event.inviteCode, event.token);
        emit(PartyInviteResolvedState(
          party: result['party'],
          isAlreadyMember: result['isMember'] == true,
        ));
      } catch (e) {
        emit(PartyFailureState(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<JoinPartyRoomEvent>((event, emit) async {
      emit(PartyLoadingState());
      try {
        final cleanCode = event.partyId.trim().toUpperCase();
        // 1. Resolve 6-digit short invite code to get actual party details
        final resolveResult = await _apiClient.resolveInviteCode(cleanCode, event.token);
        final partyJson = resolveResult['party'];
        final actualPartyId = partyJson['id'] as String;

        // 2. Join using UUID
        await _apiClient.joinParty(actualPartyId, event.token);

        _sessionToken = event.token;

        // 3. Connect WebSocket using UUID
        await _syncService.initialize();
        await _syncService.connectWebSocket(actualPartyId, event.token);

        // 4. Fetch details using UUID
        final details = await _apiClient.fetchPartyDetails(actualPartyId, event.token);
        final members = details['members'] as List<dynamic>;
        final playlistJson = details['playlist'] as List<dynamic>;
        final playlist = playlistJson.map((t) => MediaTrack.fromJson(t)).toList();

        emit(PartyJoinedState(
          partyId: actualPartyId,
          hostId: partyJson['hostId'] as String,
          inviteCode: partyJson['inviteCode'] as String,
          members: members,
          playlist: playlist,
          isHost: false,
          isOffline: false,
          isPlaying: _syncService.isSongPlaying,
          activeTrack: _syncService.activeTrack,
        ));
      } catch (e) {
        emit(PartyFailureState(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<UpdatePartyDetailsEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PartyJoinedState) return;

      if (event.isPlayStateChangeOnly) {
        emit(currentState.copyWith(
          isPlaying: event.isPlaying,
          activeTrack: event.activeTrack ?? currentState.activeTrack,
        ));
        return;
      }

      try {
        final tokenToUse = event.token.isNotEmpty ? event.token : await _retrieveToken();
        final details = await _apiClient.fetchPartyDetails(currentState.partyId, tokenToUse);
        final members = details['members'] as List<dynamic>;
        final playlistJson = details['playlist'] as List<dynamic>;
        final playlist = playlistJson.map((t) => MediaTrack.fromJson(t)).toList();

        emit(currentState.copyWith(
          members: members,
          playlist: playlist,
        ));
      } catch (_) {
        // Fallback to preserve active list if details call experiences network hiccups
      }
    });

    on<AddTrackToPartyQueueEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PartyJoinedState) return;

      if (currentState.isOffline) {
        final updatedPlaylist = List<MediaTrack>.from(currentState.playlist)..add(event.track);
        emit(currentState.copyWith(playlist: updatedPlaylist));
        if (currentState.isHost && currentState.activeTrack == null) {
          add(PlayTrackSyncedEvent(event.track));
        }
        return;
      }

      try {
        // Resolve streaming URL on-the-fly if not present (true for search results)
        String streamUrl = event.track.audioStreamUrl;
        if (streamUrl.isEmpty) {
          final metadata = await _apiClient.fetchTrackMetadata(event.track.id);
          streamUrl = metadata['audioStreamUrl'] as String? ?? "";
        }

        final token = await _retrieveToken();

        // Appends to database collaborative playlist
        await _apiClient.addTrackToPartyPlaylist(
          currentState.partyId,
          {
            'trackId': event.track.id,
            'title': event.track.title,
            'durationInSeconds': event.track.durationInSeconds,
            'audioStreamUrl': streamUrl,
            'coverArtUrl': event.track.coverArtUrl,
            'artistName': event.track.artistName,
            'albumTitle': event.track.albumTitle,
          },
          token,
        );
        
        // Push reload notice over WebSocket
        _syncService.broadcastPause(); // Broadcast update triggers immediate room reload
        add(LoadPartyDetailsEvent(partyId: currentState.partyId, token: token));
      } catch (e) {
        print("[BLOC] Failed to append track to collaborative queue: $e");
        emit(PartyFailureState("Failed to add track: ${e.toString().replaceAll('Exception: ', '')}"));
        emit(currentState); // Restore state so user isn't kicked out
      }
    });

    on<RemoveTrackFromPartyQueueEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PartyJoinedState) return;

      if (currentState.isOffline) {
        final updatedPlaylist = List<MediaTrack>.from(currentState.playlist)
          ..removeWhere((t) => t.id == event.queueId);
        emit(currentState.copyWith(playlist: updatedPlaylist));
        return;
      }

      try {
        final token = await _retrieveToken();
        await _apiClient.removeTrackFromPartyPlaylist(currentState.partyId, event.queueId, token);
        add(LoadPartyDetailsEvent(partyId: currentState.partyId, token: token));
      } catch (e) {
        print("[BLOC] Failed to remove track from collaborative queue: $e");
        emit(PartyFailureState("Failed to remove track: ${e.toString().replaceAll('Exception: ', '')}"));
        emit(currentState);
      }
    });

    on<LoadPartyDetailsEvent>((event, emit) async {
      add(UpdatePartyDetailsEvent(partyId: event.partyId, token: event.token));
    });

    on<PlayTrackSyncedEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PartyJoinedState) return;

      try {
        await _syncService.broadcastPlay(event.track);
        emit(currentState.copyWith(isPlaying: true, activeTrack: event.track));
      } catch (e) {
        print("[BLOC] Synced track broadcast playback failed: $e");
      }
    });

    on<TogglePartyPlayStateEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PartyJoinedState) return;

      try {
        if (_syncService.isSongPlaying) {
          await _syncService.broadcastPause();
          emit(currentState.copyWith(isPlaying: false));
        } else if (currentState.activeTrack != null) {
          await _syncService.broadcastPlay(currentState.activeTrack!);
          emit(currentState.copyWith(isPlaying: true));
        }
      } catch (e) {
        print("[BLOC] Playback state toggle failed: $e");
      }
    });

    on<SeekPartyPlaybackEvent>((event, emit) async {
      try {
        await _syncService.broadcastSeek(event.positionInSeconds);
      } catch (e) {
        print("[BLOC] Playback seek failed: $e");
      }
    });

    on<EnterOfflineSyncModeEvent>((event, emit) async {
      emit(PartyLoadingState());
      try {
        await _syncService.initialize();
        await _syncService.setupBleOfflineSync(event.deviceId, isHost: event.isHost);

        emit(PartyJoinedState(
          partyId: 'offline-ble-sync-room',
          hostId: event.isHost ? 'host' : 'client',
          inviteCode: 'OFFLINE',
          members: const [],
          playlist: const [],
          isHost: event.isHost,
          isOffline: true,
          isPlaying: _syncService.isSongPlaying,
          activeTrack: _syncService.activeTrack,
        ));
      } catch (e) {
        emit(PartyFailureState("BLE Sync launch failure: $e"));
      }
    });

    on<DisconnectPartyEvent>((event, emit) async {
      await _syncService.disconnect();
      emit(PartyInitialState());
    });
  }

  @override
  Future<void> close() {
    _logSubscription?.cancel();
    _songSubscription?.cancel();
    _trackSubscription?.cancel();
    _syncService.dispose();
    return super.close();
  }
}

class UpdatePartyDetailsEvent extends PartyEvent {
  final String partyId;
  final String token;
  final bool isPlayStateChangeOnly;
  final bool isPlaying;
  final MediaTrack? activeTrack;

  UpdatePartyDetailsEvent({
    required this.partyId,
    required this.token,
    this.isPlayStateChangeOnly = false,
    this.isPlaying = false,
    this.activeTrack,
  });
}
