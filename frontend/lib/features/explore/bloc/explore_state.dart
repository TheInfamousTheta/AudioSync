// lib/features/explore/bloc/explore_state.dart
import 'package:audio_sync/features/explore/models/explore_payload.dart';

abstract class ExploreState {}

class ExploreLoadingState extends ExploreState {}

class ExploreFailureState extends ExploreState {
  final String errorMessage;
  ExploreFailureState(this.errorMessage);
}

class ExploreSuccessState extends ExploreState {
  final ExploreFeed feed;
  ExploreSuccessState(this.feed);
}
