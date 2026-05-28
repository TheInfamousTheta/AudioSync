import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/features/artist/bloc/artist_bloc.dart';
import 'package:audio_sync/features/artist/bloc/artist_event.dart';
import 'package:audio_sync/features/artist/bloc/artist_state.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_bloc.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_event.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_state.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/features/artist/models/artist_payload.dart';

class ArtistDetailScreen extends StatelessWidget {
  final String artistId;
  final String artistName;

  const ArtistDetailScreen({
    super.key,
    required this.artistId,
    required this.artistName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ArtistBloc()..add(FetchArtistDataEvent(artistId)),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.surfaceSmoky),
          child: BlocBuilder<ArtistBloc, ArtistState>(
            builder: (context, state) {
              if (state is ArtistLoadingState) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryNeon),
                );
              }

              if (state is ArtistFailureState) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sync_problem_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          "Failed to sync artist details: ${state.errorMessage}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (state is ArtistSuccessState) {
                final profile = state.profile;

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _ArtistHeroHeader(profile: profile),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _PopularTracksSection(tracks: profile.popularTracks),
                          const SizedBox(height: 40),
                          _AboutArtistSection(profile: profile),
                          const SizedBox(height: 40),
                          _ArtistPlaylistsSection(playlists: profile.playlists),
                          const SizedBox(height: 120),
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

class _ArtistHeroHeader extends StatelessWidget {
  final ArtistProfile profile;
  const _ArtistHeroHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 380.0,
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
              imageUrl: profile.coverImageUrl,
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
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    AppColors.baseSurface.withValues(alpha: 0.8),
                    AppColors.baseSurface,
                  ],
                  stops: const [0.0, 0.4, 0.85, 1.0],
                ),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (profile.isVerified)
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.primaryNeon, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'VERIFIED ARTIST',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 6),
                  Text(
                    profile.name,
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurface,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${profile.monthlyListeners} MONTHLY LISTENERS',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryNeon,
                      letterSpacing: 1.0,
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

class _PopularTracksSection extends StatelessWidget {
  final List<MediaTrack> tracks;
  const _PopularTracksSection({required this.tracks});

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Popular Tracks',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        BlocBuilder<NowPlayingBloc, NowPlayingState>(
          builder: (context, nowPlayingState) {
            final activeTrackId = nowPlayingState is PlayerActiveState ? nowPlayingState.track.id : null;
            final isPlaying = nowPlayingState is PlayerActiveState ? nowPlayingState.isPlaying : false;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final track = tracks[index];
                final isActive = track.id == activeTrackId;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () {
                      context.read<NowPlayingBloc>().add(LoadTrackEvent(track));
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isActive
                            ? AppColors.surfaceContainerLow.withValues(alpha: 0.4)
                            : Colors.transparent,
                        border: isActive
                            ? Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.2), width: 1)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            alignment: Alignment.center,
                            child: isActive
                                ? Icon(
                                    isPlaying ? Icons.volume_up_rounded : Icons.volume_mute_rounded,
                                    color: AppColors.primaryNeon,
                                    size: 16,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: CachedNetworkImage(
                              imageUrl: track.coverArtUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(color: AppColors.surfaceContainerHigh, width: 44, height: 44),
                              errorWidget: (context, url, error) => Container(color: AppColors.surfaceContainerHigh, width: 44, height: 44),
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
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isActive ? AppColors.primaryNeon : AppColors.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  track.albumTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 11,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatDurationInSeconds(track.durationInSeconds),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _formatDurationInSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class _AboutArtistSection extends StatelessWidget {
  final ArtistProfile profile;
  const _AboutArtistSection({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'About the Artist',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GlassContainer(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: profile.bioImageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: AppColors.surfaceContainerHigh),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                profile.biography,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 1,
                color: AppColors.outlineVariant.withValues(alpha: 0.15),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(profile.releasesCount, 'RELEASES'),
                  _buildStatItem(profile.followersCount, 'FOLLOWERS'),
                  _buildStatItem(profile.awardsCount, 'AWARDS'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          count,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}

class _ArtistPlaylistsSection extends StatelessWidget {
  final List<ArtistPlaylist> playlists;
  const _ArtistPlaylistsSection({required this.playlists});

  @override
  Widget build(BuildContext context) {
    if (playlists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Artist Playlists',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.84,
          ),
          itemCount: playlists.length > 2 ? 2 : playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            return GlassContainer(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: CachedNetworkImage(
                        imageUrl: playlist.coverArtUrl,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: AppColors.surfaceContainerHigh),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    playlist.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
