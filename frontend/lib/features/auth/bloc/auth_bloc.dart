import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audio_sync/core/network/api_client.dart';
import 'package:audio_sync/features/auth/bloc/auth_event.dart';
import 'package:audio_sync/features/auth/bloc/auth_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ApiClient _apiClient = ApiClient();

  Future<void> _saveToken(String token) async {
    try {
      await File('.midnight_token').writeAsString(token);
      debugPrint('AuthBloc: Token persisted to local directory.');
    } catch (_) {
      try {
        await File('${Directory.systemTemp.path}/.midnight_token').writeAsString(token);
        debugPrint('AuthBloc: Local directory write failed. Saved to system temp instead.');
      } catch (e) {
        debugPrint('AuthBloc CRITICAL: Token storage write failed on all paths: $e');
      }
    }
  }

  Future<String?> _readToken() async {
    try {
      final f = File('.midnight_token');
      if (await f.exists()) {
        final token = await f.readAsString();
        if (token.trim().isNotEmpty) return token.trim();
      }
    } catch (_) {}
    try {
      final f = File('${Directory.systemTemp.path}/.midnight_token');
      if (await f.exists()) {
        final token = await f.readAsString();
        if (token.trim().isNotEmpty) return token.trim();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _deleteToken() async {
    try {
      final f = File('.midnight_token');
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    try {
      final f = File('${Directory.systemTemp.path}/.midnight_token');
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    debugPrint('AuthBloc: Token deleted from all paths.');
  }

  AuthBloc() : super(AuthInitialState()) {
    on<CheckAuthSessionEvent>((event, emit) async {
      debugPrint('AuthBloc: CheckAuthSessionEvent received.');
      emit(AuthLoadingState());
      try {
        final token = await _readToken();
        if (token != null) {
          debugPrint('AuthBloc: Found persisted token. Verifying session...');
          try {
            final result = await _apiClient.verifyToken(token);
            final user = result['user'];
            final username = user['username'] as String? ?? 'Maestro';
            final preferences = List<String>.from(user['preferences'] ?? []);

            debugPrint('AuthBloc: Session verified for user: $username');
            if (preferences.isEmpty) {
              debugPrint('AuthBloc: User needs onboarding. Emitting AuthNeedsOnboardingState.');
              emit(AuthNeedsOnboardingState(token: token, username: username));
            } else {
              debugPrint('AuthBloc: User authenticated. Emitting AuthAuthenticatedState.');
              emit(
                AuthAuthenticatedState(
                  token: token,
                  username: username,
                  preferences: preferences,
                ),
              );
            }
            return;
          } catch (e) {
            final errStr = e.toString().toLowerCase();
            final isNetworkError = errStr.contains('socketexception') ||
                errStr.contains('clientexception') ||
                errStr.contains('failed to connect') ||
                errStr.contains('connection refused') ||
                errStr.contains('timeout') ||
                errStr.contains('conduit error');

            if (isNetworkError) {
              debugPrint('AuthBloc: Network unreachable. Bypassing check and entering offline mode.');
              emit(
                AuthAuthenticatedState(
                  token: token,
                  username: 'Offline Maestro',
                  preferences: const ['Lofi', 'Chill Blue', 'Night Drive'],
                ),
              );
              return;
            } else {
              debugPrint('AuthBloc: Token verification failed: $e. Clearing token.');
              await _deleteToken();
            }
          }
        } else {
          debugPrint('AuthBloc: No persisted token found.');
        }
        emit(AuthUnauthenticatedState());
      } catch (e) {
        debugPrint('AuthBloc error checking session: $e');
        emit(AuthFailureState(e.toString()));
      }
    });

    on<SubmitLoginEvent>((event, emit) async {
      debugPrint('AuthBloc: SubmitLoginEvent received for user: "${event.username}"');
      emit(AuthLoadingState());
      try {
        final result = await _apiClient.login(event.username, event.password);
        final token = result['token'] as String;
        final user = result['user'];
        final username = user['username'] as String? ?? 'Maestro';
        final preferences = List<String>.from(user['preferences'] ?? []);

        debugPrint('AuthBloc: API login successful for $username. Saving token...');
        await _saveToken(token);

        if (preferences.isEmpty) {
          debugPrint('AuthBloc: Preferences empty. Emitting AuthNeedsOnboardingState.');
          emit(AuthNeedsOnboardingState(token: token, username: username));
        } else {
          debugPrint('AuthBloc: Login complete. Emitting AuthAuthenticatedState.');
          emit(
            AuthAuthenticatedState(
              token: token,
              username: username,
              preferences: preferences,
            ),
          );
        }
      } catch (e) {
        debugPrint('AuthBloc login error: $e');
        emit(AuthFailureState(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<SubmitRegisterEvent>((event, emit) async {
      debugPrint('AuthBloc: SubmitRegisterEvent received for user: "${event.username}"');
      emit(AuthLoadingState());
      try {
        await _apiClient.register(event.username, event.password);
        debugPrint('AuthBloc: Registration successful. Directing to login...');
        emit(AuthUnauthenticatedState(message: 'Registration successful! Please login.'));
      } catch (e) {
        debugPrint('AuthBloc registration error: $e');
        emit(AuthFailureState(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<SubmitPreferencesEvent>((event, emit) async {
      debugPrint('AuthBloc: SubmitPreferencesEvent received.');
      final currentState = state;
      if (currentState is! AuthNeedsOnboardingState) {
        debugPrint('AuthBloc error: SubmitPreferencesEvent received but current state is not AuthNeedsOnboardingState.');
        return;
      }

      emit(AuthLoadingState());
      try {
        final result = await _apiClient.savePreferences(currentState.token, event.genres);
        final user = result['user'];
        final username = user['username'] as String? ?? currentState.username;
        final preferences = List<String>.from(user['preferences'] ?? []);

        debugPrint('AuthBloc: Preferences saved. Emitting AuthAuthenticatedState.');
        emit(
          AuthAuthenticatedState(
            token: currentState.token,
            username: username,
            preferences: preferences,
          ),
        );
      } catch (e) {
        debugPrint('AuthBloc save preferences error: $e');
        emit(AuthFailureState(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<TriggerLogoutEvent>((event, emit) async {
      debugPrint('AuthBloc: TriggerLogoutEvent received.');
      final currentState = state;
      String token = '';
      if (currentState is AuthAuthenticatedState) {
        token = currentState.token;
      } else if (currentState is AuthNeedsOnboardingState) {
        token = currentState.token;
      }

      emit(AuthLoadingState());
      if (token.isNotEmpty) {
        try {
          await _apiClient.logout(token);
        } catch (_) {}
      }

      await _deleteToken();
      emit(AuthUnauthenticatedState());
    });
  }
}
