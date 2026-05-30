import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:path_provider/path_provider.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';

class BleOfflineSyncService {
  BluetoothDevice? _connectedBleDevice;
  BluetoothCharacteristic? _bleSyncCharacteristic;
  StreamSubscription? _bleSubscription;
  bool isOfflineMode = false;

  final ja.AudioPlayer _musicPlayer = ja.AudioPlayer();
  MediaTrack? activeTrack;
  bool isSongPlaying = false;

  Function(String log)? onLogUpdate;
  Function(MediaTrack track, bool isPlaying)? onTrackSynced;
  Function(bool isPlaying)? onSongStateChanged;

  /// BLE Offline coordination and discovery setup
  Future<void> setupBleOfflineSync(String deviceId, {required bool isHost}) async {
    isOfflineMode = true;
    onLogUpdate?.call("🔵 Initializing Bluetooth BLE Offline Sync layer...");

    if (!await FlutterBluePlus.isSupported) {
      onLogUpdate?.call("❌ BLE is not supported on this device.");
      return;
    }

    FlutterBluePlus.adapterState.listen((state) {
      if (state != BluetoothAdapterState.on) {
        onLogUpdate?.call("⚠️ Bluetooth adapter is turned off.");
      }
    });

    if (isHost) {
      onLogUpdate?.call("🔵 BLE Advertising Host: 'Spotify_Killer_Sync_Room'...");
    } else {
      onLogUpdate?.call("🔍 Scanning for offline BLE Sync hosts...");
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      
      FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          if (r.device.platformName.contains('Spotify_Killer') || r.device.remoteId.str == deviceId) {
            FlutterBluePlus.stopScan();
            _connectedBleDevice = r.device;
            onLogUpdate?.call("🔗 Found BLE Host. Connecting to ${r.device.platformName}...");
            await r.device.connect(license: License.nonprofit);
            _discoverBleSyncServices(r.device);
            break;
          }
        }
      });
    }
  }

  Future<void> _discoverBleSyncServices(BluetoothDevice device) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (BluetoothService service in services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.write || characteristic.properties.notify) {
            _bleSyncCharacteristic = characteristic;
            await characteristic.setNotifyValue(true);
            
            _bleSubscription = characteristic.onValueReceived.listen((value) {
              final payload = jsonDecode(utf8.decode(value));
              _handleBleOfflineFrame(payload);
            });
            onLogUpdate?.call("🔗 BLE Sync handshake completed. Offline alignment active!");
          }
        }
      }
    } catch (e) {
      onLogUpdate?.call("❌ BLE service discovery failed: $e");
    }
  }

  void _handleBleOfflineFrame(Map<String, dynamic> frame) {
    final command = frame['cmd'];
    if (command == 'PLAY') {
      final track = MediaTrack(
        id: frame['id'],
        title: frame['title'],
        artistName: frame['artist'],
        albumTitle: 'Offline BLE Sync',
        coverArtUrl: '',
        audioStreamUrl: '',
        formatBadge: 'Dolby Atmos',
        durationInSeconds: 0,
      );
      activeTrack = track;
      onTrackSynced?.call(track, true);
      _executeCompensatedPlayback(track, frame['delay'] ?? 0);
    } else if (command == 'PAUSE') {
      _musicPlayer.pause();
      isSongPlaying = false;
      onSongStateChanged?.call(false);
    } else if (command == 'SEEK') {
      _musicPlayer.seek(Duration(milliseconds: ((frame['pos'] as double) * 1000).round()));
    }
  }

  Future<void> _executeCompensatedPlayback(MediaTrack track, int delayMs) async {
    try {
      onLogUpdate?.call("🎵 Stopping current music player...");
      await _musicPlayer.stop();

      final String localPath = await _getLocalCachedPath(track.id);
      final file = File(localPath);
      if (await file.exists()) {
        onLogUpdate?.call("💾 Pre-cached hit! Playing track locally from storage: $localPath");
        await _musicPlayer.setAudioSource(ja.AudioSource.file(localPath));
      } else {
        onLogUpdate?.call("❌ Playback aborted: '${track.title}' is not pre-downloaded for offline sync!");
        return;
      }

      if (delayMs <= 0) {
        onLogUpdate?.call("🎵 Playing immediately!");
        await _musicPlayer.play();
      } else {
        onLogUpdate?.call("🎵 Audio loaded. Delay compensation: ${delayMs}ms");
        Timer(Duration(milliseconds: delayMs), () async {
          try {
            await _musicPlayer.play();
          } catch (e) {
            onLogUpdate?.call("❌ Delayed play failed: $e");
          }
        });
      }

      isSongPlaying = true;
      onSongStateChanged?.call(true);
    } catch (e) {
      onLogUpdate?.call("❌ _executeCompensatedPlayback failed: $e");
    }
  }

  Future<void> broadcastPlay(MediaTrack track) async {
    activeTrack = track;
    onLogUpdate?.call("📢 Playing track via BLE offline sync.");
    
    if (_bleSyncCharacteristic != null) {
      final Map<String, dynamic> bleFrame = {
        'cmd': 'PLAY',
        'id': track.id,
        'title': track.title,
        'artist': track.artistName,
        'delay': 1000,
      };
      await _bleSyncCharacteristic!.write(utf8.encode(jsonEncode(bleFrame)));
      _executeCompensatedPlayback(track, 1000);
    } else {
      onLogUpdate?.call("📢 Playing track instantly (offline no guests connected).");
      _executeCompensatedPlayback(track, 0);
    }
  }

  Future<void> broadcastPlayUnsynced(MediaTrack track) async {
    activeTrack = track;
    onLogUpdate?.call("📢 broadcastPlayUnsynced initiated via BLE. Firing with 600ms safety window.");
    
    if (_bleSyncCharacteristic != null) {
      final Map<String, dynamic> bleFrame = {
        'cmd': 'PLAY',
        'id': track.id,
        'title': track.title,
        'artist': track.artistName,
        'delay': 600,
      };
      await _bleSyncCharacteristic!.write(utf8.encode(jsonEncode(bleFrame)));
      _executeCompensatedPlayback(track, 600);
    } else {
      _executeCompensatedPlayback(track, 0);
    }
  }

  Future<void> broadcastPlayNoNtp(MediaTrack track) async {
    activeTrack = track;
    onLogUpdate?.call("📢 broadcastPlayNoNtp initiated via BLE. Firing instantly with 0ms delay.");
    
    if (_bleSyncCharacteristic != null) {
      final Map<String, dynamic> bleFrame = {
        'cmd': 'PLAY',
        'id': track.id,
        'title': track.title,
        'artist': track.artistName,
        'delay': 0,
      };
      await _bleSyncCharacteristic!.write(utf8.encode(jsonEncode(bleFrame)));
    }
    _executeCompensatedPlayback(track, 0);
  }

  Future<void> broadcastPause() async {
    if (_bleSyncCharacteristic != null) {
      final bleFrame = {'cmd': 'PAUSE'};
      await _bleSyncCharacteristic!.write(utf8.encode(jsonEncode(bleFrame)));
    }
    _musicPlayer.pause();
    isSongPlaying = false;
    onSongStateChanged?.call(false);
  }

  Future<void> broadcastSeek(double posSec) async {
    if (_bleSyncCharacteristic != null) {
      final bleFrame = {'cmd': 'SEEK', 'pos': posSec};
      await _bleSyncCharacteristic!.write(utf8.encode(jsonEncode(bleFrame)));
    }
    _musicPlayer.seek(Duration(milliseconds: (posSec * 1000).round()));
  }

  Future<String> _getLocalCachedPath(String trackId) async {
    final dir = await getApplicationDocumentsDirectory();
    return "${dir.path}/downloads/track_$trackId.mp3";
  }

  void pauseLocalPlayer() {
    _musicPlayer.pause();
    isSongPlaying = false;
    onSongStateChanged?.call(false);
  }

  void resumeLocalPlayer() {
    _musicPlayer.play();
    isSongPlaying = true;
    onSongStateChanged?.call(true);
  }

  void stopAudio() {
    _musicPlayer.stop();
    isSongPlaying = false;
    activeTrack = null;
    onSongStateChanged?.call(false);
    onLogUpdate?.call("🔇 Offline BLE Audio stopped and playback state reset.");
  }

  Future<void> disconnect() async {
    _bleSubscription?.cancel();
    _connectedBleDevice?.disconnect();
    _connectedBleDevice = null;
    _bleSyncCharacteristic = null;
    stopAudio();
  }

  void dispose() {
    disconnect();
    _musicPlayer.dispose();
  }
}
