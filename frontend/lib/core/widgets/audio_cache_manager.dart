import 'dart:io';
import 'package:http/http.dart' as http;

class MidnightAudioCache {
  static final MidnightAudioCache _instance = MidnightAudioCache._internal();
  factory MidnightAudioCache() => _instance;
  MidnightAudioCache._internal();

  final Set<String> _cachingTrackIds = {};
  static const int maxCacheSizeBytes = 200 * 1024 * 1024; // 200 MB limit

  Future<void> preCacheTrack(String trackId, String url) async {
    // Ignore invalid/mock session tracks
    if (trackId == 'midnight-session-live' || url.isEmpty) return;
    
    if (_cachingTrackIds.contains(trackId)) return;
    _cachingTrackIds.add(trackId);

    try {
      final file = getCachedFile(trackId);
      if (await file.exists()) {
        await touchFile(file);
        _cachingTrackIds.remove(trackId);
        return;
      }

      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      });

      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        await touchFile(file);
        _evictOldCacheIfNeeded();
      }
    } catch (_) {} finally {
      _cachingTrackIds.remove(trackId);
    }
  }

  File getCachedFile(String trackId) {
    final tempDir = Directory.systemTemp;
    final file = File('${tempDir.path}/track_cache_$trackId.mp3');
    touchFile(file);
    return file;
  }

  Future<bool> isCached(String trackId) async {
    final file = File('${Directory.systemTemp.path}/track_cache_$trackId.mp3');
    final exists = await file.exists();
    if (exists) {
      await touchFile(file);
    }
    return exists;
  }

  Future<void> touchFile(File file) async {
    try {
      if (await file.exists()) {
        await file.setLastModified(DateTime.now());
      }
    } catch (_) {}
  }

  Future<void> _evictOldCacheIfNeeded() async {
    try {
      final tempDir = Directory.systemTemp;
      final files = tempDir.listSync().whereType<File>().where((file) {
        final name = file.path.split(Platform.pathSeparator).last;
        return name.startsWith('track_cache_') && name.endsWith('.mp3');
      }).toList();

      int totalSize = 0;
      final List<MapEntry<File, int>> fileSizes = [];

      for (final file in files) {
        try {
          final len = await file.length();
          totalSize += len;
          fileSizes.add(MapEntry(file, len));
        } catch (_) {}
      }

      if (totalSize <= maxCacheSizeBytes) return;

      // Sort files by modification time (oldest first)
      final List<MapEntry<File, DateTime>> fileMods = [];
      for (final entry in fileSizes) {
        try {
          final modTime = await entry.key.lastModified();
          fileMods.add(MapEntry(entry.key, modTime));
        } catch (_) {}
      }

      fileMods.sort((a, b) => a.value.compareTo(b.value));

      int bytesToEvict = totalSize - (maxCacheSizeBytes * 0.7).toInt(); // Target 70% capacity
      int evictedBytes = 0;

      for (final entry in fileMods) {
        if (evictedBytes >= bytesToEvict) break;
        try {
          final file = entry.key;
          final fileSize = fileSizes.firstWhere((e) => e.key.path == file.path).value;
          await file.delete();
          evictedBytes += fileSize;
        } catch (_) {}
      }
    } catch (_) {}
  }
}
