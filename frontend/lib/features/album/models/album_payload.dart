import 'package:audio_sync/features/home/dashboard_payload.dart';

class AlbumDetailPayload {
  final String id;
  final String title;
  final String coverArtUrl;
  final String artistName;
  final String releaseDate;
  final String playCount;
  final List<MediaTrack> songs;

  AlbumDetailPayload({
    required this.id,
    required this.title,
    required this.coverArtUrl,
    required this.artistName,
    required this.releaseDate,
    required this.playCount,
    required this.songs,
  });

  factory AlbumDetailPayload.fromJson(Map<String, dynamic> json) {
    final rawSongs = json['songs'] as List<dynamic>? ?? [];
    return AlbumDetailPayload(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverArtUrl: json['coverArtUrl'] ?? '',
      artistName: json['artistName'] ?? '',
      releaseDate: json['releaseDate'] ?? '',
      playCount: json['playCount'] ?? '0',
      songs: rawSongs.map((t) => MediaTrack.fromJson(t)).toList(),
    );
  }
}
