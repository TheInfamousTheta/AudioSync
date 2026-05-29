// lib/features/navigation/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/features/home/screens/home_screen.dart';
import 'package:audio_sync/features/party/presentation/screens/party_sync_screen.dart';
import 'package:audio_sync/features/library/screens/library_screen.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_bloc.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_state.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_event.dart';
import 'package:audio_sync/features/now_playing/screens/now_playing_screen.dart';
import 'package:audio_sync/features/explore/screens/explore_screen.dart';
import 'package:audio_sync/features/party/presentation/bloc/party_bloc.dart';
import 'package:audio_sync/features/party/presentation/bloc/party_state.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    const HomeScreen(),
    const ExploreScreen(),
    const PartySyncScreen(),
    const LibraryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PartyBloc, PartyState>(
      builder: (context, partyState) {
        final isPartyJoined = partyState is PartyJoinedState;
        final hideNavBar = isPartyJoined && _currentIndex == 2;

        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: Stack(
            children: [
              IndexedStack(index: _currentIndex, children: _pages),

              // Floating Mini-Player Component View
              BlocBuilder<NowPlayingBloc, NowPlayingState>(
                builder: (context, state) {
                  if (state is PlayerActiveState && !hideNavBar) {
                    return Positioned(
                      left: 16,
                      right: 16,
                      bottom: 112, // Positioned exactly 12px above the bottom nav bar (24 + 76 = 100)
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NowPlayingScreen(),
                            ),
                          );
                        },
                        child: GlassContainer(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          borderRadius: 16,
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: (state.track.coverArtUrl.startsWith('http://') || state.track.coverArtUrl.startsWith('https://'))
                                    ? CachedNetworkImage(
                                        imageUrl: state.track.coverArtUrl,
                                        width: 44,
                                        height: 44,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: AppColors.containerHighest,
                                          width: 44,
                                          height: 44,
                                        ),
                                        errorWidget: (context, url, error) => Container(
                                          color: AppColors.containerHighest,
                                          width: 44,
                                          height: 44,
                                        ),
                                      )
                                    : Container(
                                        color: AppColors.containerHighest,
                                        width: 44,
                                        height: 44,
                                        child: const Icon(
                                          Icons.music_note_rounded,
                                          color: Colors.white30,
                                          size: 22,
                                        ),
                                      ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      state.track.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    Text(
                                      state.track.artistName,
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
                              IconButton(
                                icon: Icon(
                                  state.isPlaying
                                      ? Icons.pause_circle_filled_rounded
                                      : Icons.play_circle_filled_rounded,
                                  color: AppColors.primaryNeon,
                                  size: 32,
                                ),
                                onPressed: () {
                                  context.read<NowPlayingBloc>().add(
                                    TogglePlaybackEvent(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),

              // True Floating Premium Glassmorphic Bottom Navigation Bar
              if (!hideNavBar)
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 24,
                  child: GlassContainer(
                    borderRadius: 24,
                    child: Container(
                      height: 76,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildNavItem(0, Icons.home_rounded, "Home"),
                          _buildNavItem(1, Icons.explore_outlined, "Explore"),
                          _buildNavItem(2, Icons.sync_rounded, "Sync"),
                          _buildNavItem(3, Icons.library_music_outlined, "Library"),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primaryNeon : AppColors.subText.withValues(alpha: 0.7),
              size: 26,
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isSelected ? AppColors.primaryNeon : AppColors.subText.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
