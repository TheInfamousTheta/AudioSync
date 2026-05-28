import 'package:audio_sync/core/theme/app_colors.dart';
import 'package:audio_sync/core/theme/app_gradients.dart';
import 'package:audio_sync/features/auth/bloc/auth_bloc.dart';
import 'package:audio_sync/features/auth/bloc/auth_event.dart';
import 'package:audio_sync/features/auth/bloc/auth_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:audio_sync/features/navigation/main_shell.dart';


class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  final List<Map<String, dynamic>> _availableGenres = [
    {
      'id': 'Lofi',
      'title': 'Lofi Chill',
      'tagline': 'Dusty vinyl beats & warm acoustic chords.',
      'gradient': const [Color(0xff8E2DE2), Color(0xff4A00E0)],
    },
    {
      'id': 'Synthwave',
      'title': 'Synthwave Pulse',
      'tagline': 'Cyberpunk grids & retro analog soundscapes.',
      'gradient': const [Color(0xfff857a6), Color(0xffff5858)],
    },
    {
      'id': 'Midnight Jazz',
      'title': 'Midnight Jazz',
      'tagline': 'Velvet saxophone melodies & ambient dark blues.',
      'gradient': const [Color(0xff00b09b), Color(0xff96c93d)],
    },
    {
      'id': 'Chill Blue',
      'title': 'Ambient Soul',
      'tagline': 'Drifting synthesizer drones & deep atmospheres.',
      'gradient': const [Color(0xff6a11cb), Color(0xff2575fc)],
    },
    {
      'id': 'Neon Pulse',
      'title': 'Neon Pulse',
      'tagline': 'High-energy electronic beats for midnight coding.',
      'gradient': const [Color(0xffFF4E50), Color(0xffF9D423)],
    },
    {
      'id': 'Acoustic',
      'title': 'Acoustic Waves',
      'tagline': 'Organic string echoes & live concert echoes.',
      'gradient': const [Color(0xff00c6ff), Color(0xff0072ff)],
    },
  ];

  final Set<String> _selectedGenres = {};

  void _toggleGenre(String genreId) {
    setState(() {
      if (_selectedGenres.contains(genreId)) {
        _selectedGenres.remove(genreId);
      } else {
        _selectedGenres.add(genreId);
      }
    });
  }

  void _submitPreferences() {
    if (_selectedGenres.isNotEmpty) {
      context.read<AuthBloc>().add(
            SubmitPreferencesEvent(genres: _selectedGenres.toList()),
          );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.containerHighest,
          content: const Text(
            'Please select at least one frequency to tune your stage.',
            style: TextStyle(color: AppColors.onSurface),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticatedState) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const MainShell()),
            );
          }
        },
        child: Stack(
          children: [
            // Background smoky gradient
            Container(
              decoration: const BoxDecoration(
                gradient: AppGradients.surfaceSmoky,
              ),
            ),
  
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Info
                  Padding(
                    padding: const EdgeInsets.only(left: 24.0, right: 24.0, top: 32.0, bottom: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tune Your Acoustics',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                            letterSpacing: -1.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Select preferred acoustic frequencies to customize your dashboard stage.',
                          style: TextStyle(
                            color: AppColors.subText.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
  
                  // Genre Bento Grid
                  Expanded(
                    child: BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoadingState;
  
                        return GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16.0,
                            mainAxisSpacing: 16.0,
                            childAspectRatio: 0.95,
                          ),
                          itemCount: _availableGenres.length,
                          itemBuilder: (context, index) {
                            final genre = _availableGenres[index];
                            final genreId = genre['id'] as String;
                            final isSelected = _selectedGenres.contains(genreId);
                            final colors = genre['gradient'] as List<Color>;
  
                            return GestureDetector(
                              onTap: isLoading ? null : () => _toggleGenre(genreId),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.all(16.0),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryNeon.withValues(alpha: 0.06)
                                      : AppColors.surfaceContainerLow.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryNeon
                                        : Colors.white.withValues(alpha: 0.06),
                                    width: isSelected ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Colored circle representation
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: colors,
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.primaryNeon,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                    const Spacer(),
                                    Text(
                                      genre['title'] as String,
                                      style: const TextStyle(
                                        fontFamily: 'Plus Jakarta Sans',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      genre['tagline'] as String,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.subText,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
  
                  // Active Submit panel
                  BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      final isLoading = state is AuthLoadingState;
  
                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: GestureDetector(
                          onTap: isLoading ? null : _submitPreferences,
                          child: Container(
                            width: double.infinity,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: AppGradients.laserEtched,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryNeon.withValues(alpha: 0.25),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Center(
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: AppColors.baseSurface,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text(
                                      'Initialize Stage',
                                      style: TextStyle(
                                        color: AppColors.baseSurface,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
