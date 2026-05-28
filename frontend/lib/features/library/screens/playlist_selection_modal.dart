import 'dart:ui';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/features/library/bloc/library_bloc.dart';
import 'package:audio_sync/features/library/bloc/library_event.dart';
import 'package:audio_sync/features/library/bloc/library_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PlaylistSelectionModal extends StatelessWidget {
  final MediaTrack track;

  const PlaylistSelectionModal({super.key, required this.track});

  static void show(BuildContext context, MediaTrack track) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PlaylistSelectionModal(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 40,
        ),
        decoration: BoxDecoration(
          color: AppColors.baseSurface.withValues(alpha: 0.85),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Add to Playlist',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a stage playlist for "${track.title}"',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.subText,
              ),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: BlocBuilder<LibraryBloc, LibraryState>(
                builder: (context, state) {
                  if (state is LibraryLoadingState) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.primaryNeon),
                      ),
                    );
                  }

                  if (state is! LibrarySuccessState) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: Text(
                          'Could not load playlists.',
                          style: TextStyle(color: Colors.redAccent),
                        ),
                      ),
                    );
                  }

                  final playlists = state.customPlaylists;

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: playlists.length + 1,
                    itemBuilder: (context, index) {
                      if (index == playlists.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: GestureDetector(
                            onTap: () => _showCreatePlaylistDialog(context),
                            child: GlassContainer(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              borderRadius: 14,
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: AppColors.primaryNeon.withValues(alpha: 0.12),
                                    ),
                                    child: const Icon(
                                      Icons.add_rounded,
                                      color: AppColors.primaryNeon,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  const Text(
                                    'Create New Playlist',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryNeon,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      final playlist = playlists[index];
                      final playlistName = playlist['name'] as String? ?? 'Untitled';
                      final tracksList = playlist['tracks'] as List<dynamic>? ?? [];
                      final trackCount = tracksList.length;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: GestureDetector(
                          onTap: () {
                            context.read<LibraryBloc>().add(
                              AddTrackToPlaylistEvent(
                                playlistId: playlist['id'].toString(),
                                track: track,
                              ),
                            );
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppColors.containerHighest,
                                content: Text(
                                  'Added "${track.title}" to "$playlistName"',
                                  style: const TextStyle(color: AppColors.onSurface),
                                ),
                              ),
                            );
                          },
                          child: GlassContainer(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            borderRadius: 14,
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    color: AppColors.containerHighest.withValues(alpha: 0.4),
                                  ),
                                  child: const Icon(
                                    Icons.queue_music_rounded,
                                    color: AppColors.onSurface,
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
                                      Text(
                                        '$trackCount tracks',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.subText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.subText,
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
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

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
                  hintText: 'Description (Optional)',
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
                  context.read<LibraryBloc>().add(
                    CreatePlaylistEvent(
                      name: name,
                      description: descController.text.trim(),
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
}
