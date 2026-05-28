// lib/features/explore/bloc/explore_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/core/network/api_client.dart';
import 'package:audio_sync/features/explore/bloc/explore_event.dart';
import 'package:audio_sync/features/explore/bloc/explore_state.dart';
import 'package:audio_sync/features/explore/models/explore_payload.dart';

class ExploreBloc extends Bloc<ExploreEvent, ExploreState> {
  final ApiClient _apiClient = ApiClient();

  ExploreBloc() : super(ExploreLoadingState()) {
    on<FetchExploreDataEvent>((event, emit) async {
      emit(ExploreLoadingState());
      try {
        final data = await _apiClient.fetchExploreFeed();
        final feed = ExploreFeed.fromJson(data);
        emit(ExploreSuccessState(feed));
      } catch (e) {
        emit(ExploreFailureState(e.toString()));
      }
    });
  }
}
