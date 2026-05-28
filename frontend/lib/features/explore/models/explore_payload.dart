// lib/features/explore/models/explore_payload.dart
import 'package:audio_sync/features/home/dashboard_payload.dart';

class ExploreFeed {
  final List<MoodGenreItem> moodsAndGenres;
  final List<MediaTrack> midnightPicks;

  ExploreFeed({
    required this.moodsAndGenres,
    required this.midnightPicks,
  });

  factory ExploreFeed.fromJson(Map<String, dynamic> json) {
    final rawMoods = json['moodsAndGenres'] as List<dynamic>? ?? [];
    final rawPicks = json['midnightPicks'] as List<dynamic>? ?? [];

    return ExploreFeed(
      moodsAndGenres: rawMoods.map((m) => MoodGenreItem.fromJson(m)).toList(),
      midnightPicks: rawPicks.map((p) => MediaTrack.fromJson(p)).toList(),
    );
  }
}

class MoodGenreItem {
  final String id;
  final String title;
  final List<String> colors;

  MoodGenreItem({
    required this.id,
    required this.title,
    required this.colors,
  });

  factory MoodGenreItem.fromJson(Map<String, dynamic> json) {
    final rawColors = json['colors'] as List<dynamic>? ?? [];
    return MoodGenreItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      colors: rawColors.map((c) => c.toString()).toList(),
    );
  }
}
