import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/features/library/bloc/library_bloc.dart';
import 'package:audio_sync/features/library/bloc/library_event.dart';
import 'package:audio_sync/features/library/bloc/library_state.dart';
import 'package:audio_sync/features/library/screens/downloads_screen.dart';
import 'package:audio_sync/features/library/screens/playlist_detail_screen.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_bloc.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_event.dart';
import 'package:audio_sync/features/album/screens/album_detail_screen.dart';
import 'package:audio_sync/features/auth/bloc/auth_bloc.dart';
import 'package:audio_sync/features/auth/bloc/auth_event.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final tagController = TextEditingController();

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
          title: const Text(
            'New Playlist',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Playlist Name',
                  hintStyle: const TextStyle(color: AppColors.subText),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryNeon),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                style: const TextStyle(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Description',
                  hintStyle: const TextStyle(color: AppColors.subText),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryNeon),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: tagController,
                style: const TextStyle(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: 'Tags (comma separated e.g. Lofi, Sleep)',
                  hintStyle: const TextStyle(color: AppColors.subText),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.primaryNeon),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(diagContext),
              child: const Text('Cancel', style: TextStyle(color: AppColors.subText)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryNeon,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isNotEmpty) {
                  final tagsText = tagController.text.trim();
                  final tags = tagsText.isNotEmpty
                      ? tagsText.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
                      : <String>[];
                  context.read<LibraryBloc>().add(
                    CreatePlaylistEvent(
                      name: name,
                      description: descController.text.trim(),
                      tags: tags,
                    ),
                  );
                  Navigator.pop(diagContext);
                }
              },
              child: const Text(
                'Create',
                style: TextStyle(color: AppColors.baseSurface, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.surfaceSmoky),
        child: SafeArea(
          child: BlocBuilder<LibraryBloc, LibraryState>(
            builder: (context, state) {
              if (state is LibraryLoadingState) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryNeon),
                );
              }

              if (state is LibraryFailureState) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Conduit Exception: ${state.message}',
                        style: const TextStyle(color: Colors.redAccent),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNeon),
                        onPressed: () {
                          context.read<LibraryBloc>().add(LoadLibraryEvent());
                        },
                        child: const Text('Retry Connection', style: TextStyle(color: AppColors.baseSurface)),
                      ),
                    ],
                  ),
                );
              }

              if (state is! LibrarySuccessState) {
                return const SizedBox.shrink();
              }

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  const SliverToBoxAdapter(child: _LibraryHeader()),
                  _PlaylistsSection(
                    playlists: state.customPlaylists,
                    onCreateTap: () => _showCreatePlaylistDialog(context),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24.0)),
                  _FavoriteTracksSection(tracks: state.favoriteTracks),
                  const SliverToBoxAdapter(child: SizedBox(height: 24.0)),
                  _FavoriteAlbumsSection(albums: state.favoriteAlbums),
                  const SliverToBoxAdapter(child: SizedBox(height: 140.0)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24.0, top: 24.0, right: 24.0, bottom: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Your Stage',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
              letterSpacing: -1.0,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.sync_rounded, color: AppColors.primaryNeon),
                onPressed: () {
                  context.read<LibraryBloc>().add(LoadLibraryEvent());
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                onPressed: () {
                  context.read<AuthBloc>().add(TriggerLogoutEvent());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlaylistsSection extends StatelessWidget {
  final List<dynamic> playlists;
  final VoidCallback onCreateTap;

  const _PlaylistsSection({required this.playlists, required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Playlists',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                GestureDetector(
                  onTap: onCreateTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.4)),
                      color: AppColors.primaryNeon.withValues(alpha: 0.08),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, color: AppColors.primaryNeon, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'Create',
                          style: TextStyle(
                            color: AppColors.primaryNeon,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (playlists.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Text(
                'No playlists created yet. Set up your first stage playlist above!',
                style: TextStyle(color: AppColors.subText, fontSize: 13),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final playlist = playlists[index];
                  final playlistName = playlist['name'] as String? ?? 'Untitled';
                  final description = playlist['description'] as String? ?? 'Custom Stage';
                  final tracksList = playlist['tracks'] as List<dynamic>? ?? [];
                  final count = tracksList.length;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaylistDetailScreen(playlist: playlist),
                          ),
                        );
                      },
                      child: GlassContainer(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: AppGradients.laserEtched,
                              ),
                              child: const Icon(
                                Icons.queue_music_rounded,
                                color: AppColors.primaryNeon,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    playlistName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurface,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.subText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$count tracks',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primaryNeon,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.subText,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: playlists.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _FavoriteTracksSection extends StatelessWidget {
  final List<MediaTrack> tracks;
  const _FavoriteTracksSection({required this.tracks});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Text(
              'Favorite Tracks',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ),
        if (tracks.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
              child: Text(
                'No favorited tracks yet. Double-tap or heart songs during search and playback!',
                style: TextStyle(color: AppColors.subText, fontSize: 13),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final track = tracks[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              track.coverArtUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppColors.containerHighest,
                                width: 44,
                                height: 44,
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
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    track.artistName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.subText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite_rounded, color: AppColors.primaryNeon, size: 20),
                            onPressed: () {
                              context.read<LibraryBloc>().add(ToggleFavoriteTrackEvent(track));
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
                  );
                },
                childCount: tracks.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _FavoriteAlbumsSection extends StatelessWidget {
  final List<MediaAlbum> albums;
  const _FavoriteAlbumsSection({required this.albums});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Text(
              'Favorite Collections',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16.0,
              crossAxisSpacing: 16.0,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == 0) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const DownloadsScreen(),
                        ),
                      );
                    },
                    child: GlassContainer(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                gradient: AppGradients.laserEtched,
                              ),
                              child: const Icon(
                                Icons.download_done_rounded,
                                color: AppColors.primaryNeon,
                                size: 48,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Downloaded Songs',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const Text(
                            'Offline stage collection',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.subText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final album = albums[index - 1];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AlbumDetailScreen(
                          albumId: album.id,
                        ),
                      ),
                    );
                  },
                  child: GlassContainer(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: album.coverArtUrl.isNotEmpty
                                ? Image.network(
                                    album.coverArtUrl,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: AppColors.containerHighest,
                                      child: const Icon(Icons.album_rounded, color: Colors.white, size: 40),
                                    ),
                                  )
                                : Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: AppGradients.laserEtched,
                                    ),
                                    child: const Icon(
                                      Icons.album_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          album.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                album.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.subText,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                context.read<LibraryBloc>().add(ToggleFavoriteAlbumEvent(album));
                              },
                              child: const Icon(Icons.favorite_rounded, color: AppColors.primaryNeon, size: 16),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
              childCount: albums.length + 1,
            ),
          ),
        ),
      ],
    );
  }
}
