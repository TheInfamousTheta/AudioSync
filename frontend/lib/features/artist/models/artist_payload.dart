// lib/features/artist/models/artist_payload.dart
import 'package:audio_sync/features/home/dashboard_payload.dart';

class ArtistProfile {
  final String id;
  final String name;
  final String description;
  final String coverImageUrl;
  final String bioImageUrl;
  final String monthlyListeners;
  final String followersCount;
  final String releasesCount;
  final String awardsCount;
  final bool isVerified;
  final String biography;
  final List<MediaTrack> popularTracks;
  final List<ArtistPlaylist> playlists;

  ArtistProfile({
    required this.id,
    required this.name,
    required this.description,
    required this.coverImageUrl,
    required this.bioImageUrl,
    required this.monthlyListeners,
    required this.followersCount,
    required this.releasesCount,
    required this.awardsCount,
    required this.isVerified,
    required this.biography,
    required this.popularTracks,
    required this.playlists,
  });

  factory ArtistProfile.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['popularTracks'] as List<dynamic>? ?? [];
    final rawPlaylists = json['playlists'] as List<dynamic>? ?? [];

    return ArtistProfile(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Velvet Echoes',
      description: json['description'] ?? 'Neo-Jazz & Ambient Soul',
      coverImageUrl: json['coverImageUrl'] ?? 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=800',
      bioImageUrl: json['bioImageUrl'] ?? 'https://images.unsplash.com/photo-1511192336575-5a79af67a629?w=500',
      monthlyListeners: json['monthlyListeners'] ?? '1.2M',
      followersCount: json['followersCount'] ?? '158K',
      releasesCount: json['releasesCount'] ?? '24',
      awardsCount: json['awardsCount'] ?? '12',
      isVerified: json['isVerified'] ?? true,
      biography: json['biography'] ?? 'Velvet Echoes blends late-night saxophone melodies with atmospheric electronic production.',
      popularTracks: rawTracks.map((t) => MediaTrack.fromJson(t)).toList(),
      playlists: rawPlaylists.map((p) => ArtistPlaylist.fromJson(p)).toList(),
    );
  }
}

class ArtistPlaylist {
  final String id;
  final String title;
  final String coverArtUrl;

  ArtistPlaylist({
    required this.id,
    required this.title,
    required this.coverArtUrl,
  });

  factory ArtistPlaylist.fromJson(Map<String, dynamic> json) {
    return ArtistPlaylist(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverArtUrl: json['coverArtUrl'] ?? '',
    );
  }
}
