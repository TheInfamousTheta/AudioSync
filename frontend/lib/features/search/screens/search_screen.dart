import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/core/widgets/glass_container.dart';
import 'package:audio_sync/core/widgets/track_list_tile.dart';
import 'package:audio_sync/features/search/bloc/search_bloc.dart';
import 'package:audio_sync/features/search/bloc/search_event.dart';
import 'package:audio_sync/features/search/bloc/search_state.dart';
import 'package:audio_sync/features/album/screens/album_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final searchBloc = context.read<SearchBloc>();
    _controller = TextEditingController(text: searchBloc.currentQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SearchBloc, SearchState>(
      listener: (context, state) {
        final query = context.read<SearchBloc>().currentQuery;
        if (_controller.text != query) {
          _controller.text = query;
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.surfaceSmoky),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 24.0, top: 24.0, bottom: 16.0),
                  child: Text(
                    'Search',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    borderRadius: 12,
                    child: TextField(
                      controller: _controller,
                      onChanged: (value) {
                        context.read<SearchBloc>().add(
                          TriggerQueryEvent(value),
                        );
                      },
                      cursorColor: AppColors.primaryNeon,
                      style: const TextStyle(color: AppColors.onSurface),
                      decoration: const InputDecoration(
                        hintText: 'Artists, tracks, or albums...',
                        hintStyle: TextStyle(
                          color: AppColors.subText,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        icon: Icon(
                          Icons.search_rounded,
                          color: AppColors.primaryNeon,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                Expanded(
                  child: BlocBuilder<SearchBloc, SearchState>(
                    builder: (context, state) {
                      if (state is SearchInitialState) {
                        return const Center(
                          child: Text(
                            'Enter a query to explore the stage.',
                            style: TextStyle(color: AppColors.subText),
                          ),
                        );
                      }

                      if (state is SearchLoadingState) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryNeon,
                          ),
                        );
                      }

                      if (state is SearchFailureState) {
                        return Center(
                          child: Text(
                            'Conduit Failure: ${state.errorMessage}',
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        );
                      }

                      if (state is SearchSuccessState) {
                        if (state.songs.isEmpty && state.albums.isEmpty) {
                          return const Center(
                            child: Text(
                              'No entries match your search query.',
                              style: TextStyle(color: AppColors.subText),
                            ),
                          );
                        }

                        return CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            if (state.songs.isNotEmpty) ...[
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                    vertical: 12.0,
                                  ),
                                  child: Text(
                                    'Tracks',
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final track = state.songs[index];
                                    return TrackListTile(
                                      track: track,
                                      queueContext: state.songs,
                                      indexInQueue: index,
                                    );
                                  }, childCount: state.songs.length),
                                ),
                              ),
                            ],
                            if (state.albums.isNotEmpty) ...[
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                    vertical: 12.0,
                                  ),
                                  child: Text(
                                    'Albums',
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                ),
                                sliver: SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio: 0.82,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final album = state.albums[index];
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
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: Image.network(
                                                  album.coverArtUrl,
                                                  width: double.infinity,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) =>
                                                      Container(
                                                        color: AppColors
                                                            .containerHighest,
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
                                            Text(
                                              album.artistName,
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
                                    );
                                  }, childCount: state.albums.length),
                                ),
                              ),
                            ],
                            const SliverToBoxAdapter(
                              child: SizedBox(height: 24),
                            ),
                          ],
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
