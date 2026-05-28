import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/core/widgets/track_list_tile.dart';
import 'package:audio_sync/features/album/bloc/album_bloc.dart';
import 'package:audio_sync/features/album/bloc/album_event.dart';
import 'package:audio_sync/features/album/bloc/album_state.dart';
import 'package:audio_sync/features/album/models/album_payload.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_bloc.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_event.dart';
import 'package:audio_sync/features/library/bloc/library_bloc.dart';
import 'package:audio_sync/features/library/bloc/library_event.dart';
import 'package:audio_sync/features/library/bloc/library_state.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';

class AlbumDetailScreen extends StatelessWidget {
  final String albumId;

  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AlbumBloc()..add(FetchAlbumDetailEvent(albumId)),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.surfaceSmoky),
          child: BlocBuilder<AlbumBloc, AlbumState>(
            builder: (context, state) {
              if (state is AlbumLoadingState) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryNeon),
                );
              }
              if (state is AlbumFailureState) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.sync_problem_rounded, color: Colors.redAccent, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        "Failed to sync album details: ${state.errorMessage}",
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                  ),
                );
              }
              if (state is AlbumSuccessState) {
                final album = state.album;
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _AlbumHeroHeader(album: album),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _AlbumMetaRow(album: album),
                          const SizedBox(height: 28),
                          _AlbumTracksList(album: album),
                          const SizedBox(height: 140),
                        ]),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }
}

class _AlbumHeroHeader extends StatelessWidget {
  final AlbumDetailPayload album;

  const _AlbumHeroHeader({required this.album});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 340.0,
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: album.coverArtUrl,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(color: AppColors.surfaceContainerLowest),
              errorWidget: (context, url, error) => Container(color: AppColors.surfaceContainerHigh),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    AppColors.baseSurface.withValues(alpha: 0.85),
                    AppColors.baseSurface,
                  ],
                  stops: const [0.0, 0.4, 0.85, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 24,
              right: 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryNeon.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            "ALBUM COLLECTION",
                            style: TextStyle(
                              color: AppColors.primaryNeon,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          album.title,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                            letterSpacing: -1.0,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          album.artistName.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNeon,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () {
                      if (album.songs.isNotEmpty) {
                        context.read<NowPlayingBloc>().add(
                          UpdateQueueEvent(tracks: album.songs, initialIndex: 0),
                        );
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppGradients.laserEtched,
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: AppColors.onPrimary,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlbumMetaRow extends StatelessWidget {
  final AlbumDetailPayload album;

  const _AlbumMetaRow({required this.album});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMetaItem(album.releaseDate, "RELEASE"),
          _buildMetaItem("${album.songs.length}", "TRACKS"),
          _buildMetaItem(album.playCount, "PLAYS"),
          BlocBuilder<LibraryBloc, LibraryState>(
            builder: (context, libState) {
              final isFavorited = libState is LibrarySuccessState &&
                  libState.favoriteAlbums.any((a) => a.id == album.id);
              return GestureDetector(
                onTap: () {
                  context.read<LibraryBloc>().add(
                    ToggleFavoriteAlbumEvent(
                      MediaAlbum(
                        id: album.id,
                        title: album.title,
                        coverArtUrl: album.coverArtUrl,
                        artistName: album.artistName,
                      ),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: isFavorited ? AppColors.primaryNeon : AppColors.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "FAVORITE",
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceVariant,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _AlbumTracksList extends StatelessWidget {
  final AlbumDetailPayload album;

  const _AlbumTracksList({required this.album});

  @override
  Widget build(BuildContext context) {
    if (album.songs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Text(
            "This album contains no tracks.",
            style: TextStyle(color: AppColors.subText),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tracks",
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: album.songs.length,
          itemBuilder: (context, index) {
            final track = album.songs[index];
            return TrackListTile(
              track: track,
              queueContext: album.songs,
              indexInQueue: index,
            );
          },
        ),
      ],
    );
  }
}
