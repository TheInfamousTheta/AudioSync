// lib/main.dart (Refactored Entry)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/widgets/audio_systems_manager.dart';
import 'package:audio_sync/features/now_playing/bloc/now_playing_bloc.dart';
import 'package:audio_sync/features/search/bloc/search_bloc.dart';
import 'package:audio_sync/features/library/bloc/library_bloc.dart';
import 'package:audio_sync/features/library/bloc/library_event.dart';
import 'package:audio_sync/features/library/bloc/download_bloc.dart';
import 'package:audio_sync/features/navigation/main_shell.dart';
import 'package:audio_sync/features/auth/bloc/auth_bloc.dart';
import 'package:audio_sync/features/auth/bloc/auth_event.dart';
import 'package:audio_sync/features/party/presentation/bloc/party_bloc.dart';
import 'package:audio_sync/features/auth/bloc/auth_state.dart';
import 'package:audio_sync/features/auth/screens/auth_screen.dart';
import 'package:audio_sync/features/auth/screens/preferences_screen.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Failed to load .env file: $e");
  }

  AudioSystemManager.init();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.baseSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AudioSyncApp());
}

class AudioSyncApp extends StatelessWidget {
  const AudioSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc()..add(CheckAuthSessionEvent())),
        BlocProvider(create: (_) => NowPlayingBloc()),
        BlocProvider(create: (_) => SearchBloc()),
        BlocProvider(create: (_) => LibraryBloc()..add(LoadLibraryEvent())),
        BlocProvider(create: (_) => DownloadBloc()..add(LoadDownloadsEvent())),
        BlocProvider(create: (_) => PartyBloc()),
      ],
      child: MaterialApp(
        title: 'AudioSync',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: AppColors.baseSurface,
          primaryColor: AppColors.primaryNeon,
          fontFamily: 'Manrope',
        ),
        home: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            if (state is AuthAuthenticatedState) {
              FlutterNativeSplash.remove();
              return const MainShell();
            } else if (state is AuthNeedsOnboardingState) {
              FlutterNativeSplash.remove();
              return const PreferencesScreen();
            } else if (state is AuthInitialState) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryNeon,
                  ),
                ),
              );
            } else {
              FlutterNativeSplash.remove();
              return const AuthScreen();
            }
          },
        ),
      ),
    );
  }
}
