// lib/features/home/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/core/widgets/audio_cache_manager.dart';
import 'package:audio_sync/core/widgets/track_list_tile.dart';
import 'package:audio_sync/features/home/bloc/home_bloc.dart';
import 'package:audio_sync/features/home/bloc/home_event.dart';
import 'package:audio_sync/features/home/bloc/home_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc()..add(FetchDashboardDataEvent()),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.surfaceSmoky),
          child: BlocBuilder<HomeBloc, HomeState>(
            builder: (context, state) {
              if (state is HomeLoadingState) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryNeon,
                  ),
                );
              }

              if (state is HomeFailureState) {
                return Center(
                  child: Text(
                    "Data Sync Error: ${state.errorMessage}",
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              if (state is HomeSuccessState) {
                // Pre-cache recently played tracks
                for (final track in state.recentlyPlayed) {
                  MidnightAudioCache().preCacheTrack(track.id, track.audioStreamUrl);
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 72.0)),

                    // Welcome Header
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Evening, Maestro.",
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                                letterSpacing: -1.0,
                              ),
                            ),
                            SizedBox(height: 6.0),
                            Text(
                              "Your curated stage is ready for the night.",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 14,
                                color: AppColors.subText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24.0)),

                    // Premium Hero Selection Block
                    if (state.featured != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: GlassContainer(
                            padding: const EdgeInsets.all(20.0),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    state.featured!.coverArtUrl,
                                    width: 84,
                                    height: 84,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 84,
                                      height: 84,
                                      decoration: BoxDecoration(
                                        gradient: AppGradients.laserEtched,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20.0),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryNeon
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          "DOLBY ATMOS",
                                          style: TextStyle(
                                            color: AppColors.primaryNeon,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        state.featured!.title,
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontFamily: 'Plus Jakarta Sans',
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.onSurface,
                                        ),
                                      ),
                                      Text(
                                        "Featured Selection • ${state.featured!.artistName}",
                                        maxLines: 1,
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 12,
                                          color: AppColors.subText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 32.0)),

                    // History Section Header
                    if (state.recentlyPlayed.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24.0,
                            vertical: 8.0,
                          ),
                          child: Text(
                            "Recently Played",
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
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final track = state.recentlyPlayed[index];
                              return TrackListTile(
                                track: track,
                                queueContext: state.recentlyPlayed,
                                indexInQueue: index,
                              );
                            },
                            childCount: state.recentlyPlayed.length,
                          ),
                        ),
                      ),
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 120.0)),
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
