import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:rxdart/subjects.dart';

class DownloadManager {
  static final DownloadManager _instance = DownloadManager._internal();
  factory DownloadManager() => _instance;
  DownloadManager._internal();

  final _progressSubject = BehaviorSubject<Map<String, double>>.seeded({});
  Stream<Map<String, double>> get progressStream => _progressSubject.stream;
  Map<String, double> get currentProgress => _progressSubject.value;

  final Set<String> _downloadingIds = {};
  Set<String> get downloadingIds => _downloadingIds;

  Future<Directory> get _downloadsDir async {
    final docDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docDir.path}/downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> get _indexFile async {
    final dir = await _downloadsDir;
    final file = File('${dir.path}/index.json');
    if (!await file.exists()) {
      await file.writeAsString(json.encode([]));
    }
    return file;
  }

  Future<void> downloadTrack(MediaTrack track) async {
    if (track.id == 'midnight-session-live' || track.audioStreamUrl.isEmpty) return;
    if (_downloadingIds.contains(track.id)) return;

    _downloadingIds.add(track.id);
    _updateProgress(track.id, 0.0);

    try {
      final dir = await _downloadsDir;
      final file = File('${dir.path}/track_${track.id}.mp3');

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(track.audioStreamUrl));
      request.headers['User-Agent'] =
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

      final response = await client.send(request);
      final totalBytes = response.contentLength ?? 0;
      int downloadedBytes = 0;

      final fileSink = file.openWrite();

      await response.stream.forEach((chunk) {
        fileSink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          final progress = downloadedBytes / totalBytes;
          _updateProgress(track.id, progress);
        }
      });

      await fileSink.close();
      client.close();

      // Update Index
      await _addTrackToIndex(track);
      _updateProgress(track.id, 1.0);
    } catch (e) {
      debugPrint('DownloadManager: Error downloading track ${track.id}: $e');
      _removeProgress(track.id);
      // Clean up partial file on failure
      try {
        final dir = await _downloadsDir;
        final file = File('${dir.path}/track_${track.id}.mp3');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    } finally {
      _downloadingIds.remove(track.id);
    }
  }

  Future<void> deleteTrack(String trackId) async {
    try {
      final dir = await _downloadsDir;
      final file = File('${dir.path}/track_$trackId.mp3');
      if (await file.exists()) {
        await file.delete();
      }
      await _removeTrackFromIndex(trackId);
      _removeProgress(trackId);
    } catch (e) {
      debugPrint('DownloadManager: Error deleting track $trackId: $e');
    }
  }

  Future<bool> isDownloaded(String trackId) async {
    try {
      final dir = await _downloadsDir;
      final file = File('${dir.path}/track_$trackId.mp3');
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  Future<String?> getLocalTrackPath(String trackId) async {
    if (await isDownloaded(trackId)) {
      final dir = await _downloadsDir;
      return '${dir.path}/track_$trackId.mp3';
    }
    return null;
  }

  Future<List<MediaTrack>> getDownloadedTracks() async {
    try {
      final file = await _indexFile;
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((j) => MediaTrack.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _addTrackToIndex(MediaTrack track) async {
    try {
      final file = await _indexFile;
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);

      // Check if already in index
      final exists = jsonList.any((j) => j['id'] == track.id);
      if (!exists) {
        jsonList.add({
          'id': track.id,
          'title': track.title,
          'artistName': track.artistName,
          'albumTitle': track.albumTitle,
          'coverArtUrl': track.coverArtUrl,
          'audioStreamUrl': track.audioStreamUrl,
          'formatBadge': track.formatBadge,
          'durationInSeconds': track.durationInSeconds,
        });
        await file.writeAsString(json.encode(jsonList));
      }
    } catch (e) {
      debugPrint('DownloadManager: Error adding track to index: $e');
    }
  }

  Future<void> _removeTrackFromIndex(String trackId) async {
    try {
      final file = await _indexFile;
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);

      jsonList.removeWhere((j) => j['id'] == trackId);
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('DownloadManager: Error removing track from index: $e');
    }
  }

  void _updateProgress(String trackId, double progress) {
    final current = Map<String, double>.from(_progressSubject.value);
    current[trackId] = progress;
    _progressSubject.add(current);
  }

  void _removeProgress(String trackId) {
    final current = Map<String, double>.from(_progressSubject.value);
    current.remove(trackId);
    _progressSubject.add(current);
  }
}
