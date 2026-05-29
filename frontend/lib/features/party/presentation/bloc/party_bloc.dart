import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/network/api_client.dart';
import '../../data/services/party_sync_service.dart';
import 'party_event.dart';
import 'party_state.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/core/widgets/download_manager.dart';

class PartyBloc extends Bloc<PartyEvent, PartyState> {
  final ApiClient _apiClient = ApiClient();
  final PartySyncService _syncService = PartySyncService();
  
  StreamSubscription? _logSubscription;
  StreamSubscription? _songSubscription;
  StreamSubscription? _trackSubscription;
  Timer? _refreshTimer;
  final List<String> _debugLogs = [];
  String _debugResult = 'Standing by for synchronization...';



  PartyBloc() : super(PartyInitialState()) {
    
    // Wire the underlying high-fidelity synchronization engine listeners
    _syncService.onLogUpdate = (log) {
      // ignore: avoid_print
      print("[SYNC-CORE] $log");
      add(UpdatePartyDebugInfoEvent(log: log));
    };

    _syncService.onCalculationComplete = (offsetMs, distanceMeters, statusText) {
      add(UpdatePartyDebugInfoEvent(debugResult: statusText));
    };

    _syncService.onSongStateChanged = (isPlaying) {
      final currentState = state;
      if (currentState is PartyJoinedState) {
        add(UpdatePartyDetailsEvent(
          partyId: currentState.partyId,
          token: "",
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

    _syncService.onPlaylistUpdated = () {
      final currentState = state;
      if (currentState is PartyJoinedState) {
        add(LoadPartyDetailsEvent(
          partyId: currentState.partyId,
          token: currentState.sessionToken,
        ));
      }
    };


    on<CreatePartyEvent>((event, emit) async {
      _debugLogs.clear();
      _debugResult = 'Standing by for synchronization...';
      emit(PartyLoadingState());
      try {
        final result = await _apiClient.createParty(event.token);
        final partyJson = result['party'];
        final partyId = partyJson['id'] as String;
        final inviteCode = partyJson['inviteCode'] as String;
        final hostId = partyJson['hostId'] as String;
        await _syncService.initialize();
        _syncService.localUsername = event.username;
        _syncService.isHost = true;
        await _syncService.connectWebSocket(partyId, event.token);

        final details = await _apiClient.fetchPartyDetails(partyId, event.token);
        final members = details['members'] as List<dynamic>;
        final playlistJson = details['playlist'] as List<dynamic>;
        final playlist = playlistJson.map((t) => MediaTrack.fromJson(t)).toList();

        _syncService.hostId = hostId;
        _syncService.members = members;
        await _syncService.preloadChirpPlayer();

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
          sessionToken: event.token,
          debugLogs: List<String>.from(_debugLogs),
          debugResult: _debugResult,
        ));

        // 30s periodic fallback refresh in case WS events are missed
        _startPeriodicRefresh(partyId, event.token);
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
      _debugLogs.clear();
      _debugResult = 'Standing by for synchronization...';
      emit(PartyLoadingState());
      try {
        final cleanCode = event.partyId.trim().toUpperCase();
        // 1. Resolve 6-digit short invite code to get actual party details
        final resolveResult = await _apiClient.resolveInviteCode(cleanCode, event.token);
        final partyJson = resolveResult['party'];
        final actualPartyId = partyJson['id'] as String;

        // 2. Join using UUID
        await _apiClient.joinParty(actualPartyId, event.token);

        // 3. Connect WebSocket using UUID
        await _syncService.initialize();
        _syncService.localUsername = event.username;
        _syncService.isHost = false;
        await _syncService.connectWebSocket(actualPartyId, event.token);

        // 4. Fetch details using UUID
        final details = await _apiClient.fetchPartyDetails(actualPartyId, event.token);
        final members = details['members'] as List<dynamic>;
        final playlistJson = details['playlist'] as List<dynamic>;
        final playlist = playlistJson.map((t) => MediaTrack.fromJson(t)).toList();

        _syncService.hostId = partyJson['hostId'] as String;
        _syncService.members = members;
        await _syncService.preloadChirpPlayer();

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
          sessionToken: event.token,
          debugLogs: List<String>.from(_debugLogs),
          debugResult: _debugResult,
        ));

        // 30s periodic fallback refresh
        _startPeriodicRefresh(actualPartyId, event.token);
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
        final tokenToUse = event.token.isNotEmpty ? event.token : currentState.sessionToken;
        final details = await _apiClient.fetchPartyDetails(currentState.partyId, tokenToUse);
        final members = details['members'] as List<dynamic>;
        final playlistJson = details['playlist'] as List<dynamic>;
        final playlist = playlistJson.map((t) => MediaTrack.fromJson(t)).toList();

        _syncService.isHost = currentState.isHost;
        _syncService.members = members;
        await _syncService.preloadChirpPlayer();

        emit(currentState.copyWith(
          members: members,
          playlist: playlist,
        ));

        // Background-download all tracks in the playlist to pre-cache them
        for (final track in playlist) {
          if (track.audioStreamUrl.isNotEmpty) {
            DownloadManager().downloadTrack(track).then((_) {
              // ignore: avoid_print
              print("[SYNC-PRECACHE] Pre-cached track ${track.title} successfully!");
            }).catchError((err) {
              // ignore: avoid_print
              print("[SYNC-PRECACHE] Pre-cache failed for ${track.title}: $err");
            });
          }
        }
      } catch (_) {
        // Fallback: preserve active list on network hiccup
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
        String streamUrl = event.track.audioStreamUrl;
        if (streamUrl.isEmpty) {
          final metadata = await _apiClient.fetchTrackMetadata(event.track.id);
          streamUrl = metadata['audioStreamUrl'] as String? ?? "";
        }

        final token = currentState.sessionToken;

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

        // Notify peers via playlist:update WS (no pause side-effect)
        _syncService.broadcastPlaylistUpdate();
        add(LoadPartyDetailsEvent(partyId: currentState.partyId, token: token));
      } catch (e) {
        // ignore: avoid_print
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
        final token = currentState.sessionToken;
        await _apiClient.removeTrackFromPartyPlaylist(currentState.partyId, event.queueId, token);
        add(LoadPartyDetailsEvent(partyId: currentState.partyId, token: token));
      } catch (e) {
        // ignore: avoid_print
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
        MediaTrack track = event.track;
        if (track.audioStreamUrl.isEmpty) {
          final playlistTrack = currentState.playlist.firstWhere(
            (t) => t.id == track.id,
            orElse: () => track,
          );
          track = playlistTrack;
        }
        if (track.audioStreamUrl.isEmpty) {
          final metadata = await _apiClient.fetchTrackMetadata(track.id);
          final streamUrl = metadata['audioStreamUrl'] as String? ?? "";
          track = MediaTrack(
            id: track.id,
            title: track.title,
            artistName: track.artistName,
            albumTitle: track.albumTitle,
            coverArtUrl: track.coverArtUrl,
            audioStreamUrl: streamUrl,
            formatBadge: track.formatBadge,
            durationInSeconds: track.durationInSeconds,
          );
        }
        await _syncService.broadcastPlay(track);
        
        final freshState = state;
        if (freshState is PartyJoinedState) {
          emit(freshState.copyWith(isPlaying: true, activeTrack: track));
        }
      } catch (e) {
        // ignore: avoid_print
        print("[BLOC] Synced track broadcast playback failed: $e");
      }
    });

    on<PlayTrackUnsyncedEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PartyJoinedState) return;

      try {
        MediaTrack track = event.track;
        if (track.audioStreamUrl.isEmpty) {
          final playlistTrack = currentState.playlist.firstWhere(
            (t) => t.id == track.id,
            orElse: () => track,
          );
          track = playlistTrack;
        }
        if (track.audioStreamUrl.isEmpty) {
          final metadata = await _apiClient.fetchTrackMetadata(track.id);
          final streamUrl = metadata['audioStreamUrl'] as String? ?? "";
          track = MediaTrack(
            id: track.id,
            title: track.title,
            artistName: track.artistName,
            albumTitle: track.albumTitle,
            coverArtUrl: track.coverArtUrl,
            audioStreamUrl: streamUrl,
            formatBadge: track.formatBadge,
            durationInSeconds: track.durationInSeconds,
          );
        }
        await _syncService.broadcastPlayUnsynced(track);
        
        final freshState = state;
        if (freshState is PartyJoinedState) {
          emit(freshState.copyWith(isPlaying: true, activeTrack: track));
        }
      } catch (e) {
        // ignore: avoid_print
        print("[BLOC] Unsynced track broadcast playback failed: $e");
      }
    });

    on<PlayTestSoundSyncedEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PartyJoinedState) return;

      try {
        final mockTrack = MediaTrack(
          id: 'test_sound_track',
          title: '⚡ Test Sync Sound',
          artistName: 'System Diagnostic',
          albumTitle: 'System Diagnostic',
          coverArtUrl: '',
          audioStreamUrl: '',
          formatBadge: 'Hi-Res',
          durationInSeconds: 1,
        );
        
        await _syncService.broadcastPlay(mockTrack);
        
        final freshState = state;
        if (freshState is PartyJoinedState) {
          emit(freshState.copyWith(isPlaying: true, activeTrack: mockTrack));
        }
      } catch (e) {
        // ignore: avoid_print
        print("[BLOC] Synced test sound broadcast failed: $e");
      }
    });

    on<PlayTestSoundUnsyncedEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PartyJoinedState) return;

      try {
        final mockTrack = MediaTrack(
          id: 'test_sound_track',
          title: '⚡ Test Sync Sound',
          artistName: 'System Diagnostic',
          albumTitle: 'System Diagnostic',
          coverArtUrl: '',
          audioStreamUrl: '',
          formatBadge: 'Hi-Res',
          durationInSeconds: 1,
        );
        
        await _syncService.broadcastPlayUnsynced(mockTrack);
        
        final freshState = state;
        if (freshState is PartyJoinedState) {
          emit(freshState.copyWith(isPlaying: true, activeTrack: mockTrack));
        }
      } catch (e) {
        // ignore: avoid_print
        print("[BLOC] Unsynced test sound broadcast failed: $e");
      }
    });

    on<PlayTestSoundNoNtpEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PartyJoinedState) return;

      try {
        final mockTrack = MediaTrack(
          id: 'test_sound_track',
          title: '⚡ Test Sync Sound',
          artistName: 'System Diagnostic',
          albumTitle: 'System Diagnostic',
          coverArtUrl: '',
          audioStreamUrl: '',
          formatBadge: 'Hi-Res',
          durationInSeconds: 1,
        );
        
        await _syncService.broadcastPlayNoNtp(mockTrack);
        
        final freshState = state;
        if (freshState is PartyJoinedState) {
          emit(freshState.copyWith(isPlaying: true, activeTrack: mockTrack));
        }
      } catch (e) {
        // ignore: avoid_print
        print("[BLOC] No-NTP test sound broadcast failed: $e");
      }
    });




    on<TogglePartyPlayStateEvent>((event, emit) async {
      final currentState = state;
      if (currentState is! PartyJoinedState) return;

      try {
        if (currentState.isHost) {
          if (currentState.isPlaying) {
            await _syncService.broadcastPause();
            final freshState = state;
            if (freshState is PartyJoinedState) {
              emit(freshState.copyWith(isPlaying: false));
            }
          } else if (currentState.activeTrack != null) {
            await _syncService.broadcastPlay(currentState.activeTrack!);
            final freshState = state;
            if (freshState is PartyJoinedState) {
              emit(freshState.copyWith(isPlaying: true));
            }
          }
        } else {
          if (currentState.isPlaying) {
            _syncService.pauseLocalPlayer();
            final freshState = state;
            if (freshState is PartyJoinedState) {
              emit(freshState.copyWith(isPlaying: false));
            }
          } else if (currentState.activeTrack != null) {
            _syncService.resumeLocalPlayer();
            final freshState = state;
            if (freshState is PartyJoinedState) {
              emit(freshState.copyWith(isPlaying: true));
            }
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print("[BLOC] Playback state toggle failed: $e");
      }
    });

    on<SeekPartyPlaybackEvent>((event, emit) async {
      try {
        await _syncService.broadcastSeek(event.positionInSeconds);
      } catch (e) {
        // ignore: avoid_print
        print("[BLOC] Playback seek failed: $e");
      }
    });

    on<EnterOfflineSyncModeEvent>((event, emit) async {
      _debugLogs.clear();
      _debugResult = 'Standing by for synchronization...';
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
          debugLogs: List<String>.from(_debugLogs),
          debugResult: _debugResult,
        ));
      } catch (e) {
        emit(PartyFailureState("BLE Sync launch failure: $e"));
      }
    });

    on<UpdatePartyDebugInfoEvent>((event, emit) {
      if (event.log != null) {
        _debugLogs.insert(0, "[${DateTime.now().toString().substring(11, 19)}] ${event.log}");
        if (_debugLogs.length > 100) {
          _debugLogs.removeRange(100, _debugLogs.length);
        }
      }
      if (event.debugResult != null) {
        _debugResult = event.debugResult!;
      }

      final currentState = state;
      if (currentState is PartyJoinedState) {
        emit(currentState.copyWith(
          debugLogs: List<String>.from(_debugLogs),
          debugResult: _debugResult,
        ));
      }
    });

    on<DisconnectPartyEvent>((event, emit) async {
      _refreshTimer?.cancel();
      _syncService.stopAudio();
      await _syncService.disconnect();
      _debugLogs.clear();
      _debugResult = 'Standing by for synchronization...';
      emit(PartyInitialState());
    });
  }

  void _startPeriodicRefresh(String partyId, String token) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final currentState = state;
      if (currentState is PartyJoinedState) {
        add(LoadPartyDetailsEvent(partyId: partyId, token: token));
      } else {
        _refreshTimer?.cancel();
      }
    });
  }

  @override
  Future<void> close() {
    _logSubscription?.cancel();
    _songSubscription?.cancel();
    _trackSubscription?.cancel();
    _refreshTimer?.cancel();
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
