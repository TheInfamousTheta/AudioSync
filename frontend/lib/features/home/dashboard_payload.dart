// lib/features/home/models/dashboard_payload.dart

class MediaTrack {
  final String id;
  final String title;
  final String artistName;
  final String albumTitle;
  final String coverArtUrl;
  final String audioStreamUrl;
  final String formatBadge;
  final int durationInSeconds;

  MediaTrack({
    required this.id,
    required this.title,
    required this.artistName,
    required this.albumTitle,
    required this.coverArtUrl,
    required this.audioStreamUrl,
    required this.formatBadge,
    required this.durationInSeconds,
  });

  factory MediaTrack.fromJson(Map<String, dynamic> json) {
    return MediaTrack(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      artistName: json['artistName'] ?? '',
      albumTitle: json['albumTitle'] ?? 'Midnight City Sessions',
      coverArtUrl: json['coverArtUrl'] ?? '',
      audioStreamUrl: json['audioStreamUrl'] ?? '',
      formatBadge: json['formatBadge'] ?? 'Dolby Atmos',
      durationInSeconds: json['durationInSeconds'] ?? 0,
    );
  }
}

class MediaAlbum {
  final String id;
  final String title;
  final String coverArtUrl;
  final String artistName;

  MediaAlbum({
    required this.id,
    required this.title,
    required this.coverArtUrl,
    required this.artistName,
  });

  factory MediaAlbum.fromJson(Map<String, dynamic> json) {
    return MediaAlbum(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      coverArtUrl: json['coverArtUrl'] ?? '',
      artistName: json['artistName'] ?? '',
    );
  }
}
