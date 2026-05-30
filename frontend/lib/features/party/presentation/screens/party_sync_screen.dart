import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/features/auth/bloc/auth_bloc.dart';
import 'package:audio_sync/features/auth/bloc/auth_state.dart';
import 'package:audio_sync/features/library/bloc/download_bloc.dart';
import 'package:audio_sync/features/search/bloc/search_bloc.dart';
import 'package:audio_sync/features/search/bloc/search_event.dart';
import 'package:audio_sync/features/search/bloc/search_state.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/core/app_config.dart';
import '../bloc/party_bloc.dart';
import '../bloc/party_event.dart';
import '../bloc/party_state.dart';

class PartySyncScreen extends StatefulWidget {
  const PartySyncScreen({super.key});

  @override
  State<PartySyncScreen> createState() => _PartySyncScreenState();
}

class _PartySyncScreenState extends State<PartySyncScreen> {
  final TextEditingController _inviteCodeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchSection = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.surfaceSmoky),
        child: SafeArea(
          child: BlocConsumer<PartyBloc, PartyState>(
            buildWhen: (previous, current) => current is! PartyFailureState,
            listener: (context, state) {
              if (state is PartyFailureState) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
                    content: Text(state.errorMessage, style: const TextStyle(color: Colors.white)),
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state is PartyLoadingState) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryNeon),
                );
              }

              if (state is PartyJoinedState) {
                return _buildJoinedPartyView(state);
              }

              return _buildSetupView();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'Midnight Stage',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Synchronize music across speakers, rooms, and devices in real time.',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: AppColors.subText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            
            // Central Control Panel
            GlassContainer(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'HOST A SESSION',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNeon,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryNeon,
                      foregroundColor: AppColors.baseSurface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final authState = context.read<AuthBloc>().state;
                      if (authState is AuthAuthenticatedState) {
                        context.read<PartyBloc>().add(CreatePartyEvent(authState.token, username: authState.username));
                      }
                    },
                    child: const Text(
                      'START CLOUD PARTY',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 24),
                  const Text(
                    'JOIN ACTIVE SESSION',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.subText,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _inviteCodeController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                      letterSpacing: 4.0,
                    ),
                    decoration: InputDecoration(
                      hintText: 'CODE',
                      hintStyle: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        color: AppColors.subText.withValues(alpha: 0.4),
                        letterSpacing: 1.0,
                      ),
                      filled: true,
                      fillColor: AppColors.containerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceBright,
                      foregroundColor: AppColors.onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 0,
                    ),
                    onPressed: () {
                      final input = _inviteCodeController.text.trim();
                      if (input.isNotEmpty) {
                        String code = input;
                        final RegExp codeRegex = RegExp(r'[A-Za-z0-9]{6}');
                        final Iterable<RegExpMatch> matches = codeRegex.allMatches(input);
                        if (matches.isNotEmpty) {
                          code = matches.last.group(0)!.toUpperCase();
                        }

                        final authState = context.read<AuthBloc>().state;
                        if (authState is AuthAuthenticatedState) {
                          context.read<PartyBloc>().add(JoinPartyRoomEvent(partyId: code, token: authState.token, username: authState.username));
                        }
                      }
                    },
                    child: const Text(
                      'JOIN ROOM',
                      style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Offline Sync BLE options
            GlassContainer(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.bluetooth_connected_rounded, color: Colors.blueAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'OFFLINE BLUETOOTH SYNC',
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No network? Synchronize pre-downloaded music directly via Bluetooth BLE.',
                    style: TextStyle(fontFamily: 'Manrope', fontSize: 11, color: AppColors.subText, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () {
                            context.read<PartyBloc>().add(EnterOfflineSyncModeEvent(deviceId: "host", isHost: true));
                          },
                          child: const Text('HOST BLE', style: TextStyle(color: AppColors.onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                          onPressed: () {
                            context.read<PartyBloc>().add(EnterOfflineSyncModeEvent(deviceId: "host", isHost: false));
                          },
                          child: const Text('JOIN BLE', style: TextStyle(color: AppColors.onSurface, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinedPartyView(PartyJoinedState state) {
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primaryNeon,
            backgroundColor: AppColors.containerLow,
            onRefresh: () async {
              context.read<PartyBloc>().add(LoadPartyDetailsEvent(partyId: state.partyId, token: ""));
              await Future.delayed(const Duration(milliseconds: 600));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Premium Header
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              state.isOffline ? 'OFFLINE SYNC' : 'PARTY ACTIVE',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: state.isOffline ? Colors.orangeAccent : AppColors.primaryNeon,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Code: ${state.inviteCode}',
                              style: const TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share_rounded, color: AppColors.onSurface),
                              onPressed: () {
                                final String cleanBase = AppConfig.apiBaseUrl.replaceAll('/api/v1', '');
                                final inviteUrl = '$cleanBase/party/join/${state.inviteCode}';
                                Clipboard.setData(ClipboardData(text: inviteUrl)).then((_) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.surfaceBright.withValues(alpha: 0.9),
                                      content: const Row(
                                        children: [
                                          Icon(Icons.check_circle_outline_rounded, color: AppColors.primaryNeon, size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Invite link copied to clipboard!',
                                            style: TextStyle(color: AppColors.onSurface, fontFamily: 'Manrope', fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                });
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.exit_to_app_rounded, color: Colors.redAccent),
                              onPressed: () {
                                context.read<PartyBloc>().add(DisconnectPartyEvent());
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Active Party Members Section
                  _buildMembersSection(state),

                  if (kDebugMode)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.bug_report_rounded, color: AppColors.primaryNeon, size: 18),
                                const SizedBox(width: 8),
                                const Text(
                                  'DEBUG MATRIX & OUTPUT CONSOLE',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryNeon,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Calibration Status Card
                            Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: AppColors.containerLow,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Text(
                                state.debugResult,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: state.debugResult.contains('❌') 
                                      ? Colors.redAccent 
                                      : state.debugResult.contains('Lock') 
                                          ? AppColors.primaryNeon 
                                          : Colors.amberAccent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "System Output Console Logs:", 
                                  style: TextStyle(fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.subText)
                                ),
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(50, 30),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    foregroundColor: AppColors.primaryNeon,
                                  ),
                                  onPressed: () {
                                    final String allLogs = state.debugLogs.join('\n');
                                    Clipboard.setData(ClipboardData(text: allLogs)).then((_) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppColors.surfaceBright.withValues(alpha: 0.9),
                                          content: const Text(
                                            'Logs copied to clipboard!',
                                            style: TextStyle(color: AppColors.onSurface, fontFamily: 'Manrope', fontWeight: FontWeight.bold),
                                          ),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    });
                                  },
                                  icon: const Icon(Icons.copy_rounded, size: 12),
                                  label: const Text("Copy Logs", style: TextStyle(fontFamily: 'Manrope', fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  itemCount: state.debugLogs.length,
                                  itemBuilder: (context, index) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Text(
                                      state.debugLogs[index],
                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white70),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (state.playlist.isNotEmpty && state.isHost) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                  foregroundColor: Colors.orangeAccent,
                                  side: const BorderSide(color: Colors.orangeAccent, width: 1.0),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  final trackToPlay = state.activeTrack ?? state.playlist.first;
                                  context.read<PartyBloc>().add(PlayTrackUnsyncedEvent(trackToPlay));
                                },
                                icon: const Icon(Icons.flash_off_rounded, size: 16),
                                label: Text(
                                  state.activeTrack != null 
                                      ? 'FORCE PLAY UNSYNCED ("${state.activeTrack!.title}")' 
                                      : 'PLAY FIRST TRACK UNSYNCED',
                                  style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ),
                            ],
                            if (state.isHost) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primaryNeon.withValues(alpha: 0.1),
                                        foregroundColor: AppColors.primaryNeon,
                                        side: const BorderSide(color: AppColors.primaryNeon, width: 1.0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () {
                                        context.read<PartyBloc>().add(PlayTestSoundSyncedEvent());
                                      },
                                      icon: const Icon(Icons.volume_up_rounded, size: 12),
                                      label: const Text(
                                        'SYNCED POP',
                                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange.withValues(alpha: 0.1),
                                        foregroundColor: Colors.orangeAccent,
                                        side: const BorderSide(color: Colors.orangeAccent, width: 1.0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () {
                                        context.read<PartyBloc>().add(PlayTestSoundUnsyncedEvent());
                                      },
                                      icon: const Icon(Icons.flash_off_rounded, size: 12),
                                      label: const Text(
                                        'NTP ONLY',
                                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.withValues(alpha: 0.1),
                                        foregroundColor: Colors.redAccent,
                                        side: const BorderSide(color: Colors.redAccent, width: 1.0),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      onPressed: () {
                                        context.read<PartyBloc>().add(PlayTestSoundNoNtpEvent());
                                      },
                                      icon: const Icon(Icons.wifi_off_rounded, size: 12),
                                      label: const Text(
                                        'NO NTP',
                                        style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: state.isSimulatingDelay 
                                      ? Colors.redAccent.withValues(alpha: 0.15)
                                      : Colors.white10,
                                  foregroundColor: state.isSimulatingDelay ? Colors.redAccent : AppColors.onSurface,
                                  side: BorderSide(
                                    color: state.isSimulatingDelay ? Colors.redAccent : Colors.white24,
                                    width: 1.0,
                                  ),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () {
                                  context.read<PartyBloc>().add(ToggleSimulateGuestDelayEvent());
                                },
                                icon: Icon(
                                  state.isSimulatingDelay ? Icons.timer_rounded : Icons.timer_outlined,
                                  size: 14,
                                ),
                                label: SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    state.isSimulatingDelay
                                        ? 'SIMULATING +300MS GUEST DELAY (ACTIVE)'
                                        : 'SIMULATE +300MS GUEST DELAY (INACTIVE)',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Collaborative Playlist Queue Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Collaborative Queue',
                          style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        ),
                        IconButton(
                          icon: Icon(_showSearchSection ? Icons.close_rounded : Icons.add_circle_outline_rounded, color: AppColors.primaryNeon),
                          onPressed: () {
                            setState(() => _showSearchSection = !_showSearchSection);
                          },
                        ),
                      ],
                    ),
                  ),

                  // Search Interface (For adding tracks)
                  if (_showSearchSection)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      child: _buildSearchSection(state),
                    ),

                  // Playlist Queue
                  state.playlist.isEmpty
                      ? SizedBox(
                          height: 300,
                          child: _buildEmptyQueueView(state),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          itemCount: state.playlist.length,
                          itemBuilder: (context, index) {
                            final track = state.playlist[index];
                            final isCurrentTrack = state.activeTrack?.id == track.id;
                            
                            // Host can remove any; Member can only remove their own added tracks
                            final canDelete = state.isHost || !state.isOffline; // Strict rules applied inside bloc

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(
                                  color: isCurrentTrack 
                                      ? AppColors.surfaceBright.withValues(alpha: 0.5) 
                                      : AppColors.surfaceContainerLow.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(16.0),
                                  border: Border.all(
                                    color: isCurrentTrack ? AppColors.primaryNeon.withValues(alpha: 0.3) : AppColors.ghostBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _buildTrackImage(track.coverArtUrl, size: 48),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            track.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface, fontSize: 14),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            track.artistName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: AppColors.subText, fontSize: 11),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isCurrentTrack && state.isPlaying)
                                      IconButton(
                                        icon: const Icon(Icons.pause_rounded, color: AppColors.primaryNeon),
                                        onPressed: () {
                                          context.read<PartyBloc>().add(TogglePartyPlayStateEvent());
                                        },
                                      )
                                    else if (state.isHost)
                                      IconButton(
                                        icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryNeon),
                                        onPressed: () {
                                          context.read<PartyBloc>().add(PlayTrackSyncedEvent(track));
                                        },
                                      ),
                                    if (canDelete)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38),
                                        onPressed: () {
                                          context.read<PartyBloc>().add(RemoveTrackFromPartyQueueEvent(track.id));
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),

        // Synced Bottom Player Bar Controller
        if (state.activeTrack != null)
          _buildSyncedMiniPlayer(state),
      ],
    );
  }

  Widget _buildMembersSection(PartyJoinedState state) {
    if (state.members.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVE PARTY MEMBERS',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryNeon,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: state.members.length,
              itemBuilder: (context, index) {
                final member = state.members[index];
                // Check if this member is the host
                final memberUserId = member['userId'] as String? ?? '';
                final isMemberHost = memberUserId == state.hostId;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isMemberHost 
                          ? AppColors.primaryNeon.withValues(alpha: 0.15) 
                          : AppColors.containerLow,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isMemberHost 
                            ? AppColors.primaryNeon.withValues(alpha: 0.4) 
                            : Colors.white10,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isMemberHost ? Icons.star_rounded : Icons.person_outline_rounded,
                          size: 14,
                          color: isMemberHost ? AppColors.primaryNeon : AppColors.onSurface,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          member['username'] ?? 'User',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: isMemberHost ? FontWeight.bold : FontWeight.normal,
                            color: isMemberHost ? AppColors.primaryNeon : AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSearchSection(PartyJoinedState state) {
    if (state.isOffline) {
      // OFFLINE MODE: Load pre-downloaded offline track list from BLoC instead of internet search
      return BlocBuilder<DownloadBloc, DownloadState>(
        builder: (context, dlState) {
          if (dlState is! DownloadSuccessState) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
          }

          final localTracks = dlState.localTracks;
          if (localTracks.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("No downloaded files available.", style: TextStyle(color: AppColors.subText))),
            );
          }

          return Material(
            color: AppColors.containerLow,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              height: 200,
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: localTracks.length,
                itemBuilder: (context, idx) {
                  final track = localTracks[idx];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: _buildTrackImage(track.coverArtUrl, size: 36),
                    ),
                    title: Text(track.title, style: const TextStyle(color: AppColors.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(track.artistName, style: const TextStyle(color: AppColors.subText, fontSize: 10)),
                    trailing: const Icon(Icons.add_rounded, color: AppColors.primaryNeon),
                    onTap: () {
                      context.read<PartyBloc>().add(AddTrackToPartyQueueEvent(track));
                      setState(() => _showSearchSection = false);
                    },
                  );
                },
              ),
            ),
          );
        },
      );
    }

    // ONLINE MODE: standard search inputs with live query and self-healing offline fallback
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _searchController,
          style: const TextStyle(color: AppColors.onSurface),
          onChanged: (val) {
            context.read<SearchBloc>().add(TriggerQueryEvent(val));
          },
          decoration: InputDecoration(
            hintText: 'Search songs to add...',
            hintStyle: const TextStyle(color: AppColors.subText),
            filled: true,
            fillColor: AppColors.containerLow,
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.subText),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, color: AppColors.subText),
                    onPressed: () {
                      _searchController.clear();
                      context.read<SearchBloc>().add(ClearSearchEvent());
                      setState(() {});
                    },
                  )
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        BlocBuilder<SearchBloc, SearchState>(
          builder: (context, searchState) {
            if (searchState is SearchLoadingState) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(color: AppColors.primaryNeon),
                ),
              );
            }

            List<MediaTrack> tracksToShow = [];

            if (searchState is SearchSuccessState) {
              tracksToShow = searchState.songs;
            } else if (searchState is SearchFailureState || searchState is SearchInitialState) {
              // OFFLINE FALLBACK SEARCH: Search locally downloaded tracks matching the query text!
              final query = _searchController.text.trim().toLowerCase();
              if (query.isNotEmpty) {
                final dlState = context.read<DownloadBloc>().state;
                if (dlState is DownloadSuccessState) {
                  tracksToShow = dlState.localTracks.where((track) {
                    return track.title.toLowerCase().contains(query) ||
                           track.artistName.toLowerCase().contains(query);
                  }).toList();
                }
              }
            }

            if (tracksToShow.isEmpty) {
              if (_searchController.text.trim().isEmpty) {
                return const SizedBox.shrink();
              }
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text('No matching songs found.', style: TextStyle(color: AppColors.subText, fontSize: 13)),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Material(
                color: AppColors.containerLow,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  height: 220,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: tracksToShow.length,
                    itemBuilder: (context, idx) {
                      final track = tracksToShow[idx];
                      return ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _buildTrackImage(track.coverArtUrl, size: 36),
                        ),
                        title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: Text(track.artistName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.subText, fontSize: 10)),
                        trailing: const Icon(Icons.add_rounded, color: AppColors.primaryNeon),
                        onTap: () {
                          context.read<PartyBloc>().add(AddTrackToPartyQueueEvent(track));
                          _searchController.clear();
                          context.read<SearchBloc>().add(ClearSearchEvent());
                          setState(() => _showSearchSection = false);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildEmptyQueueView(PartyJoinedState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.queue_music_rounded, size: 48, color: AppColors.subText.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'Playlist queue is empty',
            style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.subText),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the "+" icon at the top right to queue up songs.',
            style: TextStyle(fontFamily: 'Manrope', fontSize: 12, color: AppColors.subText),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncedMiniPlayer(PartyJoinedState state) {
    final track = state.activeTrack!;
    return GlassContainer(
      borderRadius: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildTrackImage(track.coverArtUrl, size: 44),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface, fontSize: 13),
                ),
                Text(
                  track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.subText, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              state.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
              color: AppColors.primaryNeon,
              size: 36,
            ),
            onPressed: () {
              context.read<PartyBloc>().add(TogglePartyPlayStateEvent());
            },
          ),
          if (!state.isHost) ...[
            const SizedBox(width: 8),
            Icon(
              state.isPlaying ? Icons.sync_rounded : Icons.sync_disabled_rounded,
              color: state.isPlaying ? AppColors.primaryNeon : AppColors.subText,
              size: 20,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackImage(String url, {double size = 48}) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildFallbackImage(size),
      );
    }
    return _buildFallbackImage(size);
  }

  Widget _buildFallbackImage(double size) {
    return Container(
      color: Colors.white10,
      width: size,
      height: size,
      child: Icon(Icons.music_note_rounded, color: Colors.white30, size: size * 0.5),
    );
  }
}
