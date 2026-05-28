abstract class AuthState {}

class AuthInitialState extends AuthState {}

class AuthLoadingState extends AuthState {}

class AuthUnauthenticatedState extends AuthState {
  final String? message;
  AuthUnauthenticatedState({this.message});
}

class AuthNeedsOnboardingState extends AuthState {
  final String token;
  final String username;
  AuthNeedsOnboardingState({required this.token, required this.username});
}

class AuthAuthenticatedState extends AuthState {
  final String token;
  final String username;
  final List<String> preferences;

  AuthAuthenticatedState({
    required this.token,
    required this.username,
    required this.preferences,
  });
}

class AuthFailureState extends AuthState {
  final String errorMessage;
  AuthFailureState(this.errorMessage);
}
