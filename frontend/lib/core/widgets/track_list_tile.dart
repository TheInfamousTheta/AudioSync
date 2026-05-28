import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_bloc.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_event.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_state.dart';
import 'package:audio_sync/features/library/bloc/library_bloc.dart';
import 'package:audio_sync/features/library/bloc/library_event.dart';
import 'package:audio_sync/features/library/bloc/library_state.dart';
import 'package:audio_sync/features/library/screens/playlist_selection_modal.dart';
import 'package:audio_sync/features/library/bloc/download_bloc.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';

class TrackListTile extends StatelessWidget {
  final MediaTrack track;
  final List<MediaTrack> queueContext;
  final int indexInQueue;

  const TrackListTile({
    super.key,
    required this.track,
    required this.queueContext,
    required this.indexInQueue,
  });

  void _showMoreOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: Container(
            color: AppColors.surfaceContainerLow,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: track.coverArtUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          Text(
                            track.artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.subText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.queue_music_rounded, color: AppColors.primaryNeon),
                  title: const Text('Add to active queue', style: TextStyle(color: AppColors.onSurface)),
                  onTap: () {
                    Navigator.pop(context);
                    context.read<NowPlayingBloc>().add(AddToQueueEvent(track));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "${track.title}" to active play queue'),
                        duration: const Duration(seconds: 2),
                        backgroundColor: AppColors.surfaceContainerHigh,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add_rounded, color: AppColors.primaryNeon),
                  title: const Text('Add to playlist', style: TextStyle(color: AppColors.onSurface)),
                  onTap: () {
                    Navigator.pop(context);
                    PlaylistSelectionModal.show(context, track);
                  },
                ),
                BlocBuilder<DownloadBloc, DownloadState>(
                  builder: (context, downloadState) {
                    final isDownloaded = downloadState is DownloadSuccessState &&
                        downloadState.localTracks.any((t) => t.id == track.id);
                    if (isDownloaded) {
                      return ListTile(
                        leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        title: const Text('Delete download', style: TextStyle(color: Colors.redAccent)),
                        onTap: () {
                          Navigator.pop(context);
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
                    } else {
                      return ListTile(
                        leading: const Icon(Icons.download_rounded, color: AppColors.primaryNeon),
                        title: const Text('Download track', style: TextStyle(color: AppColors.onSurface)),
                        onTap: () {
                          Navigator.pop(context);
                          context.read<DownloadBloc>().add(StartDownloadTrackEvent(track));
                        },
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NowPlayingBloc, NowPlayingState>(
      builder: (context, nowPlayingState) {
        final activeTrackId = nowPlayingState is PlayerActiveState ? nowPlayingState.track.id : null;
        final isActive = track.id == activeTrackId;
        final isPlaying = nowPlayingState is PlayerActiveState ? nowPlayingState.isPlaying : false;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: InkWell(
            onTap: () {
              context.read<NowPlayingBloc>().add(
                    UpdateQueueEvent(tracks: queueContext, initialIndex: indexInQueue),
                  );
            },
            borderRadius: BorderRadius.circular(12),
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              borderRadius: 12,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: track.coverArtUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(color: AppColors.containerHighest),
                      errorWidget: (context, url, error) => Container(color: AppColors.containerHighest),
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
                            fontSize: 14,
                            color: isActive ? AppColors.primaryNeon : AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          track.artistName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            color: AppColors.subText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isActive) ...[
                    Icon(
                      isPlaying ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
                      color: AppColors.primaryNeon,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                  ],
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
                              width: 18,
                              height: 18,
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
                              size: 20,
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
                              size: 20,
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
                          color: AppColors.subText,
                          size: 20,
                        ),
                        onPressed: () {
                          context.read<DownloadBloc>().add(StartDownloadTrackEvent(track));
                        },
                      );
                    },
                  ),
                  BlocBuilder<LibraryBloc, LibraryState>(
                    builder: (context, libState) {
                      final isFavorited = libState is LibrarySuccessState &&
                          libState.favoriteTracks.any((t) => t.id == track.id);
                      return IconButton(
                        icon: Icon(
                          isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFavorited ? AppColors.primaryNeon : AppColors.subText,
                          size: 20,
                        ),
                        onPressed: () {
                          context.read<LibraryBloc>().add(ToggleFavoriteTrackEvent(track));
                        },
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.subText,
                      size: 20,
                    ),
                    onPressed: () => _showMoreOptions(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
