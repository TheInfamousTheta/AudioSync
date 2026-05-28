import 'dart:ui';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/features/library/bloc/library_bloc.dart';
import 'package:audio_sync/features/library/bloc/library_event.dart';
import 'package:audio_sync/features/library/bloc/library_state.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_bloc.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlaylistDetailScreen extends StatelessWidget {
  final Map<String, dynamic> playlist;

  const PlaylistDetailScreen({super.key, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final playlistId = playlist['id'].toString();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.surfaceSmoky),
        child: SafeArea(
          child: BlocBuilder<LibraryBloc, LibraryState>(
            builder: (context, state) {
              if (state is! LibrarySuccessState) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryNeon));
              }

              // Retrieve the latest version of this playlist from state
              final currentPlaylist = state.customPlaylists.firstWhere(
                (p) => p['id'].toString() == playlistId,
                orElse: () => playlist,
              );

              final name = currentPlaylist['name'] as String? ?? 'Untitled';
              final desc = currentPlaylist['description'] as String? ?? 'Curated Stage Collection';
              final tags = currentPlaylist['tags'] as List<dynamic>? ?? [];
              final rawTracks = currentPlaylist['tracks'] as List<dynamic>? ?? [];
              
              final tracks = rawTracks
                  .whereType<Map<String, dynamic>>()
                  .map(MediaTrack.fromJson)
                  .toList();

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Glassmorphic App Bar
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    pinned: true,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.onSurface),
                      onPressed: () => Navigator.pop(context),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context),
                      ),
                    ],
                  ),

                  // Playlist Header Info
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  gradient: AppGradients.laserEtched,
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                ),
                                child: const Icon(
                                  Icons.queue_music_rounded,
                                  color: AppColors.primaryNeon,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurface,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      desc,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.subText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (tags.isNotEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: tags.map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryNeon.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: const TextStyle(
                                    color: AppColors.primaryNeon,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )).toList(),
                            ),
                          const SizedBox(height: 24),
                          const Text(
                            'Tracks',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (tracks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 48.0),
                              child: Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.music_off_outlined, size: 48, color: AppColors.subText.withValues(alpha: 0.5)),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No tracks on this stage yet.',
                                      style: TextStyle(color: AppColors.subText),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Tracks List
                  if (tracks.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final track = tracks[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Dismissible(
                                key: Key(track.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                                ),
                                onDismissed: (direction) {
                                  context.read<LibraryBloc>().add(
                                    RemoveTrackFromPlaylistEvent(
                                      playlistId: playlistId,
                                      trackId: track.id,
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.containerHighest,
                                      content: Text('Removed "${track.title}" from playlist'),
                                    ),
                                  );
                                },
                                child: GlassContainer(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          track.coverArtUrl,
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: AppColors.containerHighest,
                                            width: 48,
                                            height: 48,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            context.read<NowPlayingBloc>().add(LoadTrackEvent(track));
                                          },
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                track.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
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
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                                        onPressed: () {
                                          context.read<LibraryBloc>().add(
                                            RemoveTrackFromPlaylistEvent(
                                              playlistId: playlistId,
                                              trackId: track.id,
                                            ),
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.play_arrow_rounded, color: AppColors.primaryNeon),
                                        onPressed: () {
                                          context.read<NowPlayingBloc>().add(LoadTrackEvent(track));
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: tracks.length,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 120)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (diagContext) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: AppColors.baseSurface.withValues(alpha: 0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: const Text('Delete Playlist', style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to permanently delete this playlist?', style: TextStyle(color: AppColors.subText)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(diagContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.subText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                context.read<LibraryBloc>().add(DeletePlaylistEvent(playlist['id'].toString()));
                Navigator.pop(diagContext);
                Navigator.pop(context);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
