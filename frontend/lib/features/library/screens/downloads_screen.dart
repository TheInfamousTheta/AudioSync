import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/core/widgets/track_list_tile.dart';
import 'package:audio_sync/features/library/bloc/download_bloc.dart';
import 'package:audio_sync/features/auth/bloc/auth_bloc.dart';
import 'package:audio_sync/features/auth/bloc/auth_state.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.surfaceSmoky),
        child: SafeArea(
          child: BlocBuilder<DownloadBloc, DownloadState>(
            builder: (context, state) {
              if (state is DownloadLoadingState) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryNeon),
                );
              }

              if (state is DownloadFailureState) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load downloads: ${state.message}',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryNeon),
                        onPressed: () {
                          context.read<DownloadBloc>().add(LoadDownloadsEvent());
                        },
                        child: const Text('Retry', style: TextStyle(color: AppColors.baseSurface)),
                      ),
                    ],
                  ),
                );
              }

              if (state is! DownloadSuccessState) {
                return const SizedBox.shrink();
              }

              final allTracks = state.allTracks;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24.0, top: 24.0, right: 24.0, bottom: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Offline Stage',
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                              letterSpacing: -1.0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.sync_rounded, color: AppColors.primaryNeon),
                            onPressed: () {
                              context.read<DownloadBloc>().add(LoadDownloadsEvent());
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: _SyncStatusCard(
                        localCount: state.localTracks.length,
                        remoteCount: state.remoteTracks.length,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24.0)),
                  if (allTracks.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
                        child: _EmptyDownloadsView(),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final track = allTracks[index];
                            return TrackListTile(
                              track: track,
                              queueContext: allTracks,
                              indexInQueue: index,
                            );
                          },
                          childCount: allTracks.length,
                        ),
                      ),
                    ),
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

class _SyncStatusCard extends StatelessWidget {
  final int localCount;
  final int remoteCount;

  const _SyncStatusCard({
    required this.localCount,
    required this.remoteCount,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isOfflineUser = authState is AuthAuthenticatedState &&
            authState.username == 'Offline Maestro';

        return GlassContainer(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOfflineUser ? Colors.orangeAccent : AppColors.primaryNeon,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOfflineUser ? 'OFFLINE ACTIVE' : 'CLOUD SYNC ACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isOfflineUser ? Colors.orangeAccent : AppColors.primaryNeon,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${localCount + remoteCount} Sync entries',
                    style: const TextStyle(fontSize: 11, color: AppColors.subText),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.primaryNeon,
                      count: '$localCount',
                      label: 'OFFLINE CACHED',
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.08)),
                  Expanded(
                    child: _buildMetricItem(
                      icon: Icons.cloud_download_outlined,
                      color: Colors.white.withValues(alpha: 0.5),
                      count: '$remoteCount',
                      label: 'PENDING LOCAL',
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricItem({
    required IconData icon,
    required Color color,
    required String count,
    required String label,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppColors.subText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDownloadsView extends StatelessWidget {
  const _EmptyDownloadsView();

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryNeon.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.primaryNeon.withValues(alpha: 0.3), width: 1.5),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: AppColors.primaryNeon,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your Stage is Silent',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the download arrow on any song tile to take it offline. It will compile directly into your private offline stage.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: AppColors.subText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
