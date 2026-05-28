// lib/features/home/bloc/home_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/network/api_client.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/features/home/bloc/home_event.dart';
import 'package:audio_sync/features/home/bloc/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final ApiClient _apiClient = ApiClient();

  HomeBloc() : super(HomeLoadingState()) {
    on<FetchDashboardDataEvent>((event, emit) async {
      emit(HomeLoadingState());
      try {
        final data = await _apiClient.fetchHomeDashboard();

        final Map<String, dynamic>? rawFeatured = data['featured'];
        final List<dynamic> rawRecent = data['recentlyPlayed'] ?? [];
        final List<dynamic> rawMadeForYou = data['madeForYou'] ?? [];
        final List<dynamic> rawNewReleases = data['newReleases'] ?? [];

        emit(
          HomeSuccessState(
            featured: rawFeatured != null
                ? MediaAlbum.fromJson(rawFeatured)
                : null,
            recentlyPlayed: rawRecent
                .map((json) => MediaTrack.fromJson(json))
                .toList(),
            madeForYou: rawMadeForYou
                .map((json) => MediaAlbum.fromJson(json))
                .toList(),
            newReleases: rawNewReleases
                .map((json) => MediaTrack.fromJson(json))
                .toList(),
          ),
        );
      } catch (e) {
        emit(HomeFailureState(e.toString()));
      }
    });
  }
}
