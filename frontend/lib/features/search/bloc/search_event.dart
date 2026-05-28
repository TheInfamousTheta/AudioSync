abstract class SearchEvent {}

class TriggerQueryEvent extends SearchEvent {
  final String query;

  TriggerQueryEvent(this.query);
}

class ClearSearchEvent extends SearchEvent {}
