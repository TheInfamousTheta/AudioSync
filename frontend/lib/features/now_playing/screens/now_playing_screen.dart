import 'dart:ui';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/core/widgets/audio_systems_manager.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_bloc.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_event.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_state.dart';
import 'package:audio_sync/features/library/bloc/library_bloc.dart';
import 'package:audio_sync/features/library/bloc/library_event.dart';
import 'package:audio_sync/features/library/bloc/library_state.dart';
import 'package:audio_sync/features/library/bloc/download_bloc.dart';
import 'package:audio_sync/features/library/screens/playlist_selection_modal.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  void _showAethericTuner(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const _AtmosphericTunerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.surfaceSmoky),
        child: BlocBuilder<NowPlayingBloc, NowPlayingState>(
          builder: (context, state) {
            if (state is! PlayerActiveState) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primaryNeon),
                ),
              );
            }

            final track = state.track;
            final audioManager = AudioSystemManager();

            return Stack(
              children: [
                Positioned(
                  top: -100,
                  right: -100,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryNeon.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      _NowPlayingHeader(track: track),
                      const Spacer(),
                      _NowPlayingCoverArt(track: track),
                      const Spacer(),
                      _NowPlayingTrackInfo(track: track),
                      const SizedBox(height: 28),
                      _NowPlayingTimeline(audioManager: audioManager),
                      const SizedBox(height: 16),
                      _NowPlayingControls(isPlaying: state.isPlaying),
                      const Spacer(),
                      _NowPlayingFooter(onTunerTap: () => _showAethericTuner(context)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NowPlayingHeader extends StatelessWidget {
  final MediaTrack track;
  const _NowPlayingHeader({required this.track});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.onSurface, size: 32),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'PLAYING FROM ALBUM',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10,
                    letterSpacing: 2,
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  track.albumTitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_add_rounded, color: AppColors.onSurface, size: 28),
            onPressed: () => PlaylistSelectionModal.show(context, track),
          ),
        ],
      ),
    );
  }
}

class _NowPlayingCoverArt extends StatelessWidget {
  final MediaTrack track;
  const _NowPlayingCoverArt({required this.track});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width - 80;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: track.coverArtUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: AppColors.surfaceContainerHighest),
                errorWidget: (context, url, error) => Container(
                  decoration: const BoxDecoration(gradient: AppGradients.laserEtched),
                  child: const Icon(Icons.music_note_rounded, size: 54, color: AppColors.onSurface),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -16,
            right: -16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.outlineVariant.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryNeon),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        track.formatBadge,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          color: AppColors.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowPlayingTrackInfo extends StatelessWidget {
  final MediaTrack track;
  const _NowPlayingTrackInfo({required this.track});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    BlocBuilder<DownloadBloc, DownloadState>(
                      builder: (context, downloadState) {
                        final isDownloaded = downloadState is DownloadSuccessState &&
                            downloadState.localTracks.any((t) => t.id == track.id);
                        if (isDownloaded) {
                          return const Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(
                              Icons.offline_pin_rounded,
                              color: Colors.grey,
                              size: 20,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  track.artistName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 16,
                    color: AppColors.primaryNeon,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          BlocBuilder<DownloadBloc, DownloadState>(
            builder: (context, downloadState) {
              if (downloadState is DownloadSuccessState) {
                final isLocal = downloadState.localTracks.any((t) => t.id == track.id);
                final isRemote = downloadState.remoteTracks.any((t) => t.id == track.id);
                final progress = downloadState.progress[track.id];
                final isDownloading = progress != null && progress < 1.0;

                if (isDownloading) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 2,
                        color: AppColors.primaryNeon,
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  );
                }

                if (isLocal) {
                  return IconButton(
                    icon: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primaryNeon,
                      size: 28,
                    ),
                    onPressed: () {
                      context.read<DownloadBloc>().add(DeleteDownloadedTrackEvent(track.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed "${track.title}" from offline stage'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppColors.surfaceContainerHigh,
                        ),
                      );
                    },
                  );
                }

                if (isRemote) {
                  return IconButton(
                    icon: const Icon(
                      Icons.cloud_download_rounded,
                      color: AppColors.primaryNeon,
                      size: 28,
                    ),
                    onPressed: () {
                      context.read<DownloadBloc>().add(StartDownloadTrackEvent(track));
                    },
                  );
                }
              }

              return IconButton(
                icon: const Icon(
                  Icons.arrow_downward_rounded,
                  color: AppColors.onSurfaceVariant,
                  size: 28,
                ),
                onPressed: () {
                  context.read<DownloadBloc>().add(StartDownloadTrackEvent(track));
                },
              );
            },
          ),
          const SizedBox(width: 8),
          BlocBuilder<LibraryBloc, LibraryState>(
            builder: (context, libState) {
              final isFavorited = libState is LibrarySuccessState &&
                  libState.favoriteTracks.any((t) => t.id == track.id);
              return IconButton(
                icon: Icon(
                  isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFavorited ? AppColors.primaryNeon : AppColors.onSurfaceVariant,
                  size: 28,
                ),
                onPressed: () {
                  context.read<LibraryBloc>().add(ToggleFavoriteTrackEvent(track));
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _NowPlayingTimeline extends StatelessWidget {
  final AudioSystemManager audioManager;
  const _NowPlayingTimeline({required this.audioManager});

  String _formatDuration(Duration duration) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PositionData>(
      stream: audioManager.positionDataStream,
      builder: (context, snapshot) {
        final positionData = snapshot.data ?? PositionData(Duration.zero, Duration.zero, Duration.zero);
        final durationMillis = positionData.duration.inMilliseconds.toDouble();
        final maxValue = durationMillis <= 0 ? 1.0 : durationMillis;
        final currentValue = positionData.position.inMilliseconds.toDouble().clamp(0.0, maxValue);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  activeTrackColor: AppColors.primaryNeon,
                  inactiveTrackColor: AppColors.outlineVariant.withValues(alpha: 0.2),
                  thumbColor: AppColors.onSurface,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  min: 0,
                  max: maxValue,
                  value: currentValue,
                  onChanged: (value) {
                    context.read<NowPlayingBloc>().add(SeekPositionEvent(Duration(milliseconds: value.toInt())));
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(positionData.position),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      _formatDuration(positionData.duration),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NowPlayingControls extends StatelessWidget {
  final bool isPlaying;
  const _NowPlayingControls({required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NowPlayingBloc, NowPlayingState>(
      builder: (context, state) {
        final isShuffle = state is PlayerActiveState && state.isShuffleEnabled;
        final isRepeat = state is PlayerActiveState && state.isRepeatEnabled;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: Icon(
                  Icons.shuffle_rounded,
                  color: isShuffle ? AppColors.primaryNeon : AppColors.onSurfaceVariant,
                ),
                onPressed: () {
                  context.read<NowPlayingBloc>().add(ToggleShuffleEvent());
                },
              ),
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, color: AppColors.onSurface, size: 36),
                onPressed: () {
                  context.read<NowPlayingBloc>().add(PlayPreviousEvent());
                },
              ),
              GestureDetector(
                onTap: () => context.read<NowPlayingBloc>().add(TogglePlaybackEvent()),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppGradients.laserEtched),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: AppColors.onPrimary,
                    size: 40,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, color: AppColors.onSurface, size: 36),
                onPressed: () {
                  context.read<NowPlayingBloc>().add(PlayNextEvent());
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.repeat_rounded,
                  color: isRepeat ? AppColors.primaryNeon : AppColors.onSurfaceVariant,
                ),
                onPressed: () {
                  context.read<NowPlayingBloc>().add(ToggleRepeatEvent());
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NowPlayingFooter extends StatelessWidget {
  final VoidCallback onTunerTap;
  const _NowPlayingFooter({required this.onTunerTap});

  void _showDevicesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const _DevicesSheet(),
    );
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const _QueueSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.devices_rounded, color: AppColors.onSurfaceVariant),
            onPressed: () => _showDevicesSheet(context),
          ),
          GestureDetector(
            onTap: onTunerTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: AppColors.primaryNeon.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.2), width: 1),
              ),
              child: const Row(
                children: [
                  Icon(Icons.tune_rounded, color: AppColors.primaryNeon, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'AETHERIC SOUND',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNeon,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.playlist_play_rounded, color: AppColors.onSurfaceVariant),
            onPressed: () => _showQueueSheet(context),
          ),
        ],
      ),
    );
  }
}

class _DevicesSheet extends StatefulWidget {
  const _DevicesSheet();

  @override
  State<_DevicesSheet> createState() => _DevicesSheetState();
}

class _DevicesSheetState extends State<_DevicesSheet> {
  List<Map<String, dynamic>> _uiDevices = [];
  String _selectedDeviceName = "Local Speaker (Atmospheric Focus)";
  StreamSubscription<Set<AudioDevice>>? _devicesSubscription;

  @override
  void initState() {
    super.initState();
    _fetchSystemDevices();
    _subscribeToDeviceChanges();
  }

  Future<void> _fetchSystemDevices() async {
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices();
      _updateDevices(devices.where((d) => d.isOutput).toList());
    } catch (_) {
      _useFallbackDevices();
    }
  }

  Future<void> _subscribeToDeviceChanges() async {
    try {
      final session = await AudioSession.instance;
      _devicesSubscription = session.devicesStream.listen((devices) {
        _updateDevices(devices.where((d) => d.isOutput).toList());
      });
    } catch (_) {}
  }

  void _updateDevices(List<AudioDevice> outputs) {
    if (outputs.isEmpty) {
      _useFallbackDevices();
      return;
    }

    final uniqueDevices = <String, Map<String, dynamic>>{};

    for (final d in outputs) {
      final typeName = _formatDeviceType(d.type);
      final displayName = d.name.isNotEmpty
          ? (d.name.toLowerCase().contains(typeName.toLowerCase()) ? d.name : "${d.name} ($typeName)")
          : typeName;

      IconData icon = Icons.volume_up_rounded;
      final typeStr = d.type.toString().toLowerCase();

      if (typeStr.contains('speaker')) {
        icon = Icons.volume_up_rounded;
      } else if (typeStr.contains('headphones') || typeStr.contains('headset') || typeStr.contains('wired')) {
        icon = Icons.headphones_rounded;
      } else if (typeStr.contains('bluetooth')) {
        icon = Icons.bluetooth_audio_rounded;
      } else if (typeStr.contains('receiver') || typeStr.contains('earpiece')) {
        icon = Icons.phone_android_rounded;
      } else if (typeStr.contains('hdmi')) {
        icon = Icons.settings_input_hdmi_rounded;
      }

      if (!uniqueDevices.containsKey(displayName)) {
        uniqueDevices[displayName] = {
          "name": displayName,
          "icon": icon,
          "id": d.id,
        };
      }
    }

    setState(() {
      _uiDevices = uniqueDevices.values.toList();

      if (_uiDevices.isNotEmpty && !_uiDevices.any((d) => d["name"] == _selectedDeviceName)) {
        _selectedDeviceName = _uiDevices.first["name"] as String;
      }
    });
  }

  // ignore: experimental_member_use
  String _formatDeviceType(AudioDeviceType type) {
    final s = type.toString().split('.').last;
    final words = s.replaceAllMapped(RegExp(r'(?<!^)(?=[A-Z])'), (match) => ' ${match.group(0)}');
    return words[0].toUpperCase() + words.substring(1);
  }

  void _useFallbackDevices() {
    setState(() {
      _uiDevices = [
        {"name": "Local Speaker (Atmospheric Focus)", "icon": Icons.phone_android_rounded},
        {"name": "Midnight Soundbar (Studio Level)", "icon": Icons.speaker_rounded},
        {"name": "Master Bluetooth Headphones", "icon": Icons.headphones_rounded},
      ];
    });
  }

  @override
  void dispose() {
    _devicesSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          color: AppColors.surfaceContainerLow.withValues(alpha: 0.85),
          padding: const EdgeInsets.only(left: 28, right: 28, top: 24, bottom: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Connect to Device',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              if (_uiDevices.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: CircularProgressIndicator(color: AppColors.primaryNeon),
                  ),
                )
              else
                Column(
                  children: _uiDevices.map((device) {
                    final isSelected = _selectedDeviceName == device["name"];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDeviceName = device["name"] as String;
                        });
                        AudioSystemManager().switchAudioRoute(device["name"] as String);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isSelected 
                              ? AppColors.primaryNeon.withValues(alpha: 0.15) 
                              : Colors.transparent,
                          border: isSelected 
                              ? Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.3), width: 1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              device["icon"] as IconData,
                              color: isSelected ? AppColors.primaryNeon : AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                device["name"] as String,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? AppColors.primaryNeon : AppColors.onSurface,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle_rounded, color: AppColors.primaryNeon, size: 20),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueSheet extends StatelessWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          color: AppColors.surfaceContainerLow.withValues(alpha: 0.85),
          padding: const EdgeInsets.only(left: 28, right: 28, top: 24, bottom: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Playback Queue',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              BlocBuilder<NowPlayingBloc, NowPlayingState>(
                builder: (context, state) {
                  if (state is! PlayerActiveState || state.queue.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: Text(
                          'No tracks queued.',
                          style: TextStyle(color: AppColors.subText),
                        ),
                      ),
                    );
                  }

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: state.queue.length,
                      itemBuilder: (context, index) {
                        final track = state.queue[index];
                        final isCurrent = index == state.currentIndex;

                        return InkWell(
                          onTap: () {
                            context.read<NowPlayingBloc>().add(
                              UpdateQueueEvent(tracks: state.queue, initialIndex: index),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            margin: const EdgeInsets.only(bottom: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: isCurrent 
                                  ? AppColors.primaryNeon.withValues(alpha: 0.1) 
                                  : Colors.transparent,
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: track.coverArtUrl,
                                    width: 38,
                                    height: 38,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        track.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontWeight: FontWeight.bold,
                                          color: isCurrent ? AppColors.primaryNeon : AppColors.onSurface,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        track.artistName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          color: AppColors.onSurfaceVariant,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isCurrent)
                                  const Icon(Icons.volume_up_rounded, color: AppColors.primaryNeon, size: 16),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AtmosphericTunerSheet extends StatefulWidget {
  const _AtmosphericTunerSheet();

  @override
  State<_AtmosphericTunerSheet> createState() => _AtmosphericTunerSheetState();
}

class _AtmosphericTunerSheetState extends State<_AtmosphericTunerSheet> {
  final AudioSystemManager audioManager = AudioSystemManager();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          color: AppColors.surfaceContainerLow.withValues(alpha: 0.85),
          padding: const EdgeInsets.only(left: 28, right: 28, top: 24, bottom: 40),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Aetheric Sound Studio',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Conform the atmospheric acoustics to your signature style.',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Graphic Equalizer (5-Band)',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  height: 170,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: audioManager.equalizerBands.keys.map((band) {
                      final value = audioManager.equalizerBands[band]!;
                      return Column(
                        children: [
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  activeTrackColor: AppColors.primaryNeon,
                                  inactiveTrackColor: AppColors.outlineVariant.withValues(alpha: 0.2),
                                  thumbColor: AppColors.onSurface,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                ),
                                child: Slider(
                                  min: -12.0,
                                  max: 12.0,
                                  value: value,
                                  onChanged: (val) {
                                    setState(() {
                                      audioManager.setEqualizerBand(band, val);
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            band,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${value > 0 ? '+' : ''}${value.toInt()}dB',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: value != 0 ? AppColors.primaryNeon : AppColors.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Equalizer Presets',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: AudioSystemManager.eqPresets.keys.map((preset) {
                      final isActive = audioManager.activeEqPreset == preset;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              audioManager.applyEqPreset(preset);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.primaryNeon : AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive ? AppColors.primaryNeon : AppColors.outlineVariant.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              preset,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive ? AppColors.baseSurface : AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Reverb Presets',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: ['Studio', 'Cathedral', 'Ambient'].map((preset) {
                      final isActive = audioManager.reverbPreset == preset;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              audioManager.setReverbPreset(preset);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.primaryNeon : AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive ? AppColors.primaryNeon : AppColors.outlineVariant.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              preset,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isActive ? AppColors.baseSurface : AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
