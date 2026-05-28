import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/core/widgets/audio_cache_manager.dart';
import 'package:audio_sync/core/widgets/track_list_tile.dart';
import 'package:audio_sync/features/explore/bloc/explore_bloc.dart';
import 'package:audio_sync/features/explore/bloc/explore_event.dart';
import 'package:audio_sync/features/explore/bloc/explore_state.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_bloc.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_event.dart';
import 'package:audio_sync/features/search/bloc/search_bloc.dart';
import 'package:audio_sync/features/search/bloc/search_event.dart';
import 'package:audio_sync/features/search/screens/search_screen.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/features/explore/models/explore_payload.dart';
import 'package:audio_sync/core/network/api_client.dart';


class ExploreScreen extends StatelessWidget {
  final VoidCallback? onSearchTap;

  const ExploreScreen({super.key, this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExploreBloc()..add(FetchExploreDataEvent()),
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.surfaceSmoky),
          child: BlocBuilder<ExploreBloc, ExploreState>(
            builder: (context, state) {
              if (state is ExploreLoadingState) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryNeon),
                );
              }

              if (state is ExploreFailureState) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sync_problem_rounded, color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          "Failed to load Explore: ${state.errorMessage}",
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

              if (state is ExploreSuccessState) {
                final feed = state.feed;

                // Pre-cache Explore suggestions (Midnight Picks)
                for (final track in feed.midnightPicks) {
                  MidnightAudioCache().preCacheTrack(track.id, track.audioStreamUrl);
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 72.0)),
                    SliverToBoxAdapter(child: _ExploreHeader(onSearchTap: onSearchTap)),
                    const SliverToBoxAdapter(child: SizedBox(height: 32.0)),
                    SliverToBoxAdapter(child: _CuratedBentoGrid(onSearchTap: onSearchTap)),
                    const SliverToBoxAdapter(child: SizedBox(height: 40.0)),
                    SliverToBoxAdapter(
                      child: _MoodsAndGenresList(
                        feed: feed,
                        onSearchTap: onSearchTap,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 40.0)),
                    SliverToBoxAdapter(child: _MidnightPicksList(feed: feed)),
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

class _ExploreHeader extends StatelessWidget {
  final VoidCallback? onSearchTap;
  const _ExploreHeader({this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Explore",
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 18.0),
          GestureDetector(
            onTap: onSearchTap ?? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: AppColors.onSurfaceVariant),
                  SizedBox(width: 14),
                  Text(
                    "Artists, songs, or podcasts",
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      color: AppColors.subText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CuratedBentoGrid extends StatelessWidget {
  final VoidCallback? onSearchTap;

  const _CuratedBentoGrid({this.onSearchTap});

  void _showMidnightSessionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const _MidnightSessionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  height: 196,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: const DecorationImage(
                      image: NetworkImage(
                        "https://lh3.googleusercontent.com/aida-public/AB6AXuDGMidm1YZc5aUROA06AWyCerZPnteU2idtW5qmlQ5SmXQDd7MKumEAwiFva6jcbf977JsPLHadvBgdlFpyJyGok3xpOca_tjuYY3qGHXKAoLPjWj5EFB6G7Erhrh3Q5RlQiq-Zz9cf738FFfZ0mkjZ4pWPSAv7Vl8EyHOlAMazsPSIusoFIrJh92FU51Lf_zk2Lm0jmKyCq4NOwxN2h2zJrTXtHR1ReNyqvcC9zO34xKRwNnr8b6tcJXSQ8IaewS0NwcMfINHjAiw"
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    SizedBox(
                      height: 91,
                      child: GestureDetector(
                        onTap: () {
                          context.read<SearchBloc>().add(TriggerQueryEvent("Top Charts"));
                          if (onSearchTap != null) {
                            onSearchTap!.call();
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
                          }
                        },
                        child: const GlassContainer(
                          padding: EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(Icons.trending_up_rounded, color: AppColors.primaryNeon, size: 24),
                                  Icon(Icons.arrow_forward_rounded, color: AppColors.onSurfaceVariant, size: 16),
                                ],
                              ),
                              Text(
                                "Global Charts",
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 91,
                      child: GestureDetector(
                        onTap: () {
                          context.read<SearchBloc>().add(TriggerQueryEvent("Discover New"));
                          if (onSearchTap != null) {
                            onSearchTap!.call();
                          } else {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
                          }
                        },
                        child: const GlassContainer(
                          padding: EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(Icons.auto_awesome_rounded, color: AppColors.primaryNeon, size: 22),
                                  Icon(Icons.north_east_rounded, color: AppColors.onSurfaceVariant, size: 16),
                                ],
                              ),
                              Text(
                                "For You",
                                style: TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => _showMidnightSessionSheet(context),
            child: Container(
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                image: const DecorationImage(
                  image: NetworkImage(
                    "https://lh3.googleusercontent.com/aida-public/AB6AXuBnA2fM80__WPKKMHSPNg9x5nZrmGn-o9CqZsXymiWSPFvmaZY9IqpKbW8_ibt6Q4xWUYJiE3d3M6QLUVWOkMYiLJ3BOe5Q6PPDfE6saV3kHyYUcZZ0iDa2lllqOp1qhyV2ResmLGSU7kN7WTF3bW194hu1ZbVNkt7c3rhJ22xzVl_uXzDHoV8gUefUk94c4cbZxtqJ0V95Wp_mrDLTF-PuUmARKp-R_b4J63VzwyLCB15PX-uQtjnD9tvdNG9waUPbiksBMr0MPbk"
                  ),
                  fit: BoxFit.cover,
                  opacity: 0.6,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      AppColors.primaryNeon.withValues(alpha: 0.08),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.5),
                            border: Border.all(color: AppColors.primaryNeon, width: 1.5),
                          ),
                          child: const Icon(Icons.sensors_rounded, color: AppColors.primaryNeon, size: 20),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Midnight Sessions",
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              "LIVE NOW",
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryNeon,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MidnightSessionSheet extends StatelessWidget {
  const _MidnightSessionSheet();

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Midnight Sessions Live',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNeon.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 10),
                        SizedBox(width: 4),
                        Text(
                          'LIVE',
                          style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Join thousands of concurrent listeners vibing to late night ambient soul.',
                style: TextStyle(fontFamily: 'Manrope', fontSize: 13, color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem("4,812", "LISTENERS"),
                  _buildStatItem("128 kbps", "QUALITY"),
                  _buildStatItem("Ambient", "GENRE"),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNeon,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      final broadcastData = await ApiClient().fetchLiveBroadcast();
                      final track = MediaTrack.fromJson(broadcastData);
                      if (context.mounted) {
                        context.read<NowPlayingBloc>().add(LoadTrackEvent(track));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        context.read<NowPlayingBloc>().add(
                          LoadTrackEvent(
                            MediaTrack(
                              id: 'midnight-session-live',
                              title: 'Midnight Session Live Broadcast',
                              artistName: 'Midnight DJ Team',
                              albumTitle: 'Midnight Broadcasts',
                              coverArtUrl: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500',
                              audioStreamUrl: 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3',
                              formatBadge: 'Hi-Res Lossless',
                              durationInSeconds: 422,
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text(
                    'TUNE IN NOW',
                    style: TextStyle(color: AppColors.baseSurface, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.onSurface),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Manrope', fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class _MoodsAndGenresList extends StatelessWidget {
  final ExploreFeed feed;
  final VoidCallback? onSearchTap;

  const _MoodsAndGenresList({required this.feed, this.onSearchTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            "Moods & Genres",
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 16.0),
        SizedBox(
          height: 112,
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            itemCount: feed.moodsAndGenres.length,
            itemBuilder: (context, index) {
              final mood = feed.moodsAndGenres[index];
              final gradientColors = mood.colors.map((c) {
                final hexString = c.replaceAll('#', '');
                return Color(int.parse('FF$hexString', radix: 16));
              }).toList();

              return Padding(
                padding: const EdgeInsets.only(right: 14.0),
                child: GestureDetector(
                  onTap: () {
                    context.read<SearchBloc>().add(TriggerQueryEvent(mood.title));
                    if (onSearchTap != null) {
                      onSearchTap!();
                    } else {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
                    }
                  },
                  child: Container(
                    width: 168,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: gradientColors.length >= 2 
                            ? gradientColors 
                            : [AppColors.primaryNeon, AppColors.onPrimaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mood.title,
                          style: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MidnightPicksList extends StatelessWidget {
  final ExploreFeed feed;
  const _MidnightPicksList({required this.feed});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Midnight Picks",
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 16.0),
          Column(
            children: List.generate(feed.midnightPicks.length, (index) {
              final track = feed.midnightPicks[index];
              return TrackListTile(
                track: track,
                queueContext: feed.midnightPicks,
                indexInQueue: index,
              );
            }),
          ),
        ],
      ),
    );
  }
}
