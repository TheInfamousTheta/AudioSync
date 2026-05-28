abstract class AuthEvent {}

class CheckAuthSessionEvent extends AuthEvent {}

class SubmitLoginEvent extends AuthEvent {
  final String username;
  final String password;
  SubmitLoginEvent({required this.username, required this.password});
}

class SubmitRegisterEvent extends AuthEvent {
  final String username;
  final String password;
  SubmitRegisterEvent({required this.username, required this.password});
}

class SubmitPreferencesEvent extends AuthEvent {
  final List<String> genres;
  SubmitPreferencesEvent({required this.genres});
}

class TriggerLogoutEvent extends AuthEvent {}
