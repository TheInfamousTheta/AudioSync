import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:audio_sync/core/app_config.dart';
import 'package:audio_sync/features/home/dashboard_payload.dart';
import 'package:audio_sync/core/widgets/audio_systems_manager.dart';
import 'dsp_engine.dart';

class PartySyncService {
  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  final _audioRecorder = AudioRecorder();

  Function(String log)? onLogUpdate;
  Function(double offsetMs, double distanceMeters, String statusText)? onCalculationComplete;
  Function(bool isPlaying)? onSongStateChanged;
  Function(MediaTrack track, bool isPlaying)? onTrackSynced;
  Function()? onPlaylistUpdated;

  // Real-time synchronization calibration states
  bool _isAcousticSyncing = false;
  
  // WAN Time sync states (NTP-like RTT calculation)
  int _serverClockOffset = 0; // serverTime - localTime
  int _roundTripTime = 0;
  Timer? _ntpTimer;

  // Circular audio recording buffer
  StreamSubscription<List<int>>? _recorderSubscription;
  late Uint8List _circularBuffer;
  int _writePointer = 0;
  int _totalBytesRecorded = 0;
  bool _isMicStreaming = false;

  // Media playback
  final ja.AudioPlayer _musicPlayer = ja.AudioPlayer();
  final ja.AudioPlayer _chirpPlayer = ja.AudioPlayer();
  String? _dynamicChirpPath;
  MediaTrack? activeTrack;
  bool isSongPlaying = false;

  // Dynamic chirp sources
  AudioSource? _activeChirpSource;
  
  // Bluetooth BLE coordination states
  BluetoothDevice? _connectedBleDevice;
  BluetoothCharacteristic? _bleSyncCharacteristic;
  StreamSubscription? _bleSubscription;
  bool isOfflineMode = false;

  // Real-time Acoustic Synchronization Matrix states
  String? localUsername;
  bool isHost = false;
  int _acousticOffset = 0;
  int _hostAcousticDelay = 0;
  final Map<String, Map<String, dynamic>> _alignmentDataMap = {};
  Completer<void>? _syncCompleter;

  Future<void> initialize() async {
    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init();
    }
    await _startContinuousMicrophoneStream();

    // Register stream event listeners for robust debug feedback
    _musicPlayer.playbackEventStream.listen((event) {
      // Quietly process events
    }, onError: (Object e, StackTrace st) {
      onLogUpdate?.call("❌ [Music Player Event Error] $e");
    });

    _musicPlayer.playerStateStream.listen((state) {
      onLogUpdate?.call("ℹ️ [Player State] processingState: ${state.processingState}, playing: ${state.playing}");
    }, onError: (Object e, StackTrace st) {
      onLogUpdate?.call("❌ [Player State Error] $e");
    });
  }

  /// Establishes the real-time WebSocket signaling conduit
  Future<void> connectWebSocket(String partyId, String token) async {
    isOfflineMode = false;
    await disconnect();

    String cleanedToken = token.trim();
    if (cleanedToken.endsWith('#')) {
      cleanedToken = cleanedToken.substring(0, cleanedToken.length - 1);
    }

    // Map http/https base url to ws/wss ws endpoints
    String wsUrl = AppConfig.apiBaseUrl
        .replaceAll('http://', 'ws://')
        .replaceAll('https://', 'wss://');
    if (wsUrl.endsWith('/')) {
      wsUrl = '${wsUrl}party/sync?token=$cleanedToken';
    } else {
      wsUrl = '$wsUrl/party/sync?token=$cleanedToken';
    }

    onLogUpdate?.call("🔌 Connecting to party synchronization server: $wsUrl");
    try {
      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Join Room immediately
      _sendSocketMessage('party:join', {'partyId': partyId});

      _wsSubscription = _wsChannel!.stream.listen((message) {
        final payload = jsonDecode(message);
        _handleIncomingSocketMessage(payload['event'], payload['data']);
      }, onError: (err) {
        onLogUpdate?.call("❌ WebSocket channel exception: $err");
      }, onDone: () {
        onLogUpdate?.call("🔌 WebSocket channel disconnected.");
      });

      // Warm up Server-Client time sync calibration
      _triggerWANTimesync();
      _ntpTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        _triggerWANTimesync();
      });
    } catch (e) {
      onLogUpdate?.call("❌ Failed to resolve WebSocket: $e");
    }
  }

  /// Disconnects active web socket and stops time sync heartbeats
  Future<void> disconnect() async {
    _ntpTimer?.cancel();
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    _connectedBleDevice?.disconnect();
    _bleSubscription?.cancel();
    _connectedBleDevice = null;
    _bleSyncCharacteristic = null;
    _acousticOffset = 0;
    _hostAcousticDelay = 0;
    _alignmentDataMap.clear();
    stopAudio(); // Stop playback and mic on every disconnect
  }

  /// Stops local audio playback and resets playback state
  void stopAudio() {
    _musicPlayer.stop();
    isSongPlaying = false;
    activeTrack = null;
    _acousticOffset = 0;
    _hostAcousticDelay = 0;
    _alignmentDataMap.clear();
    onSongStateChanged?.call(false);
    onLogUpdate?.call("🔇 Audio stopped and playback state reset.");
  }

  void _sendSocketMessage(String event, Map<String, dynamic> data) {
    if (_wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({'event': event, 'data': data}));
    }
  }

  void _triggerWANTimesync() {
    _sendSocketMessage('sync:ping', {'clientTx': Date.nowMs()});
  }

  void _handleIncomingSocketMessage(String event, Map<String, dynamic> data) {
    switch (event) {
      case 'sync:pong': {
        final clientTx = data['clientTx'] as int;
        final serverRx = data['serverRx'] as int;
        final clientRx = Date.nowMs();

        _roundTripTime = (clientRx - clientTx);
        // Server time offset estimation: server_time = local_time + offset
        _serverClockOffset = (serverRx - (clientTx + clientRx) ~/ 2);
        onLogUpdate?.call("🎯 Network Lock. RTT: ${_roundTripTime}ms | Offset: ${_serverClockOffset}ms");
        break;
      }

      case 'sync:trigger': {
        onLogUpdate?.call("🎙️ Sync trigger frame received from server. Running acoustic alignment...");
        executeDynamicAcousticSync();
        break;
      }

      case 'sync:alignment': {
        final userId = data['userId'] as String;
        final username = data['username'] as String;
        final tSelf = data['tSelf'] as int;
        final tCross = data['tCross'] as int;

        onLogUpdate?.call("📥 Alignment data received from $username ($userId): tSelf=$tSelf, tCross=$tCross");

        _alignmentDataMap[userId] = {'tSelf': tSelf, 'tCross': tCross, 'username': username};

        if (isHost) {
          // Find host's own alignment data in the map
          Map<String, dynamic>? hostAlign;
          String? hostId;
          _alignmentDataMap.forEach((uid, val) {
            if (val['username'] == localUsername) {
              hostAlign = val;
              hostId = uid;
            }
          });

          if (hostAlign != null) {
            final int tSelfPc = hostAlign!['tSelf'] as int;
            final int tCrossPc = hostAlign!['tCross'] as int;

            // Compute offset for any CLIENT that is NOT the host
            _alignmentDataMap.forEach((uid, val) {
              if (uid != hostId) {
                final int tSelfPhone = val['tSelf'] as int;
                final int tCrossPhone = val['tCross'] as int;
                final String clientUsername = val['username'] as String;

                // Calculate relative delay offset using double chirps consensus
                final double dtPhone = (tCrossPhone - tSelfPhone) / DSPEngine.sampleRate;
                final double dtPc = (tCrossPc - tSelfPc) / (Platform.isWindows ? 48000.0 : DSPEngine.sampleRate.toDouble());
                final double rawMsOffset = ((dtPhone - dtPc) / 2) * 1000;

                onLogUpdate?.call("🎯 Acoustic Sync consensus computed for client $clientUsername: ${rawMsOffset.toStringAsFixed(2)} ms");

                if (rawMsOffset < 0) {
                  // Host is leading: Host delays itself, Client plays immediately (0 delay)
                  _hostAcousticDelay = rawMsOffset.abs().round();
                  _sendSocketMessage('sync:offset', {
                    'userId': uid,
                    'offsetMs': 0,
                  });
                } else {
                  // Client is leading: Client delays itself, Host plays immediately (0 delay)
                  _hostAcousticDelay = 0;
                  _sendSocketMessage('sync:offset', {
                    'userId': uid,
                    'offsetMs': rawMsOffset.round(),
                  });
                }
              }
            });

            // Complete the sync barrier completer since consensus was computed
            if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
              _syncCompleter!.complete();
            }
          }
        }
        break;
      }

      case 'sync:offset': {
        final targetUserId = data['userId'] as String;
        final offsetMs = data['offsetMs'] as int;

        // Find my own record by localUsername in the alignment data map
        final myUserId = _alignmentDataMap.keys.firstWhere(
          (uid) => _alignmentDataMap[uid]?['username'] == localUsername,
          orElse: () => "",
        );

        if (myUserId.isNotEmpty && targetUserId == myUserId) {
          _acousticOffset = offsetMs;
          onLogUpdate?.call("🎯 Acoustic calibration lock applied to player pipeline: ${_acousticOffset}ms delay compensation");
        }
        break;
      }

      case 'playback:play': {
        final track = MediaTrack.fromJson(data);
        final playAtServer = data['playAt'] as int;
        final bool isUnsynced = data['isUnsynced'] == true;

        if (isUnsynced) {
          _acousticOffset = 0;
          onLogUpdate?.call("📢 Unsynced play directive received. Resetting calibration offsets.");
        }

        activeTrack = track;
        onTrackSynced?.call(track, true);

        final targetLocalTime = playAtServer - _serverClockOffset;
        final now = Date.nowMs();
        final playDelay = targetLocalTime - now;

        onLogUpdate?.call("🎵 Playback directive: '${track.title}'. Server Start Time: $playAtServer. Delay compensation: ${playDelay}ms");
        _executeCompensatedPlayback(track, targetLocalTime);
        break;
      }

      case 'playback:pause': {
        onLogUpdate?.call("🤫 Pause playback directive received.");
        _musicPlayer.pause();
        isSongPlaying = false;
        onSongStateChanged?.call(false);
        break;
      }

      case 'playback:seek': {
        final positionSec = data['positionInSeconds'] as double;
        onLogUpdate?.call("⏳ Seek playback directive received: ${positionSec}s");
        _musicPlayer.seek(Duration(milliseconds: (positionSec * 1000).round()));
        break;
      }

      case 'playlist:update': {
        onLogUpdate?.call("🔄 Playlist update notice received from server.");
        onPlaylistUpdated?.call();
        break;
      }

      case 'party:member_joined': {
        final username = data['username'] as String;
        onLogUpdate?.call("👋 Member joined: $username");
        break;
      }
    }
  }

  /// Notifies all room members that the collaborative playlist has changed
  void broadcastPlaylistUpdate() {
    if (!isOfflineMode) {
      _sendSocketMessage('playlist:update', {});
    }
  }

  /// Dynamically synthesizes chirp on-demand, plays via Soloud, records mic, and processes in background Isolate
  Future<void> executeDynamicAcousticSync() async {
    if (_isAcousticSyncing || !_isMicStreaming) return;
    _isAcousticSyncing = true;
    onLogUpdate?.call("⚡ Generating dynamic calibration chirps in-memory...");

    final int targetRate = Platform.isWindows ? 48000 : DSPEngine.sampleRate;
    final bool isPC = Platform.isWindows;

    // Two distinct chirp bands: local device emits 'self' chirp, cross-template matches remote device's band
    final Float32List selfChirpData = DSPEngine.generateChirpTemplate(
      fStart: isPC ? 1500 : 3500,
      fEnd: isPC ? 3000 : 5000,
      targetSampleRate: targetRate
    );
    final Float32List crossChirpData = DSPEngine.generateChirpTemplate(
      fStart: isPC ? 3500 : 1500,
      fEnd: isPC ? 5000 : 3000,
      targetSampleRate: targetRate
    );

    // Convert self chirp to WAV and load into SoLoud
    final Uint8List wavBytes = _packageFloatsToWav(selfChirpData, targetRate);

    // Load dynamic WAV directly into SoLoud heap
    if (Platform.isWindows) {
      try {
        _activeChirpSource = await SoLoud.instance.loadMem(
          "dynamic_calibration_chirp.wav",
          wavBytes,
          mode: LoadMode.memory,
        );
        onLogUpdate?.call("⚡ Dynamic chirp loaded to SoLoud memory.");
      } catch (e) {
        onLogUpdate?.call("❌ Dynamic chirp synthesis failed: $e");
        _isAcousticSyncing = false;
        return;
      }
    } else {
      try {
        final tempDir = await getTemporaryDirectory();
        final chirpFile = File('${tempDir.path}/dynamic_chirp.wav');
        await chirpFile.writeAsBytes(wavBytes);
        _dynamicChirpPath = chirpFile.path;
        onLogUpdate?.call("⚡ Dynamic chirp saved to temp file.");
      } catch (e) {
        onLogUpdate?.call("❌ Dynamic chirp file save failed: $e");
        _isAcousticSyncing = false;
        return;
      }
    }

    // Acoustic timeline capture
    final snapshotStartMarker = _totalBytesRecorded;
    final int targetLength = (targetRate * 1.5 * (Platform.isWindows ? 8 : 2)).toInt(); // channels * 2 bytes
    final Uint8List capturedBuffer = Uint8List(targetLength);

    // Emit chirp instantly
    onLogUpdate?.call("🔊 Emitting calibration chirp (${isPC ? '1.5–3.0' : '3.5–5.0'}kHz — audible reference).");
    if (Platform.isWindows) {
      if (_activeChirpSource != null) {
        SoLoud.instance.play(_activeChirpSource!);
      }
    } else if (_dynamicChirpPath != null) {
      await _chirpPlayer.setAudioSource(ja.AudioSource.file(_dynamicChirpPath!));
      await _chirpPlayer.setVolume(1.0);
      _chirpPlayer.play();
    }

    // Await 1.5s recording snapshot
    await Future.delayed(const Duration(milliseconds: 1500));

    // Extract snapshot from circular mic buffer
    int startIdx = snapshotStartMarker % _circularBuffer.length;
    if (startIdx < 0) startIdx += _circularBuffer.length;
    if (startIdx + targetLength <= _circularBuffer.length) {
      capturedBuffer.setRange(0, targetLength, _circularBuffer, startIdx);
    } else {
      final part1 = _circularBuffer.length - startIdx;
      capturedBuffer.setRange(0, part1, _circularBuffer, startIdx);
      capturedBuffer.setRange(part1, targetLength, _circularBuffer, 0);
    }

    // Process mono conversion if multichannel (Windows microphone inputs)
    Uint8List monoBuffer = capturedBuffer;
    if (isPC) {
      monoBuffer = _extractMonoFromMultichannel(capturedBuffer, 4);
    }

    final dspArgs = BackgroundDSPArgs(
      rawCapturedBytes: monoBuffer,
      selfTemplate: selfChirpData,
      crossTemplate: crossChirpData,
    );

    final dspAnalysis = await Isolate.run(() {
      return DSPEngine.processAudioBackground(dspArgs);
    });

    // Cleanup Soloud buffer immediately to purge heap
    if (_activeChirpSource != null) {
      SoLoud.instance.disposeSource(_activeChirpSource!);
      _activeChirpSource = null;
    }

    _isAcousticSyncing = false;
    onLogUpdate?.call("🎯 Acoustic capture completed. Peak index: ${dspAnalysis.tSelf}");
    
    // Send alignment consensus data to Room Coordinator
    _sendSocketMessage('sync:alignment', {
      'tSelf': dspAnalysis.tSelf,
      'tCross': dspAnalysis.tCross,
    });
  }

  /// Compensated WAN execution
  Future<void> _executeCompensatedPlayback(MediaTrack track, int targetLocalTimeOrDelay) async {
    try {
      AudioSystemManager().player.stop();
    } catch (_) {}

    try {
      onLogUpdate?.call("🎵 Stopping current music player...");
      await _musicPlayer.stop();

      if (track.audioStreamUrl.isEmpty) {
        onLogUpdate?.call("⚠️ Warning: Received track audioStreamUrl is empty!");
      }

      if (isOfflineMode) {
        // STRICT PLAYBACK LOCK: Only execute pre-downloaded local cached files
        final String localPath = await _getLocalCachedPath(track.id);
        final file = File(localPath);
        if (!await file.exists()) {
          onLogUpdate?.call("❌ Playback aborted: '${track.title}' is not pre-downloaded for offline sync!");
          return;
        }
        onLogUpdate?.call("💾 Playing local cached file offline: $localPath");
        await _musicPlayer.setAudioSource(ja.AudioSource.file(localPath));
      } else {
        // Direct stream play through the proxy url
        onLogUpdate?.call("🎵 Loading stream URL: ${track.audioStreamUrl}");
        await _musicPlayer.setAudioSource(ja.AudioSource.uri(Uri.parse(track.audioStreamUrl)));
      }

      int remainingDelayMs;
      if (targetLocalTimeOrDelay > 1000000000000) {
        // It's an absolute epoch timestamp!
        final targetPlayTime = targetLocalTimeOrDelay + _acousticOffset;
        remainingDelayMs = targetPlayTime - Date.nowMs();
        onLogUpdate?.call("🎵 Audio loaded. Target epoch: $targetPlayTime. Current epoch: ${Date.nowMs()}. Remaining delay: ${remainingDelayMs}ms");
      } else {
        // It's a relative delay!
        remainingDelayMs = targetLocalTimeOrDelay + _acousticOffset;
        onLogUpdate?.call("🎵 Audio loaded. Relative delay: ${targetLocalTimeOrDelay}ms. Remaining delay: ${remainingDelayMs}ms");
      }

      if (remainingDelayMs <= 0) {
        onLogUpdate?.call("🎵 Playing immediately!");
        await _musicPlayer.play();
      } else {
        Timer(Duration(milliseconds: remainingDelayMs), () async {
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

    if (!isOfflineMode) {
      // Clear previous acoustic sync metrics before starting the new session calibration
      _alignmentDataMap.clear();
      _hostAcousticDelay = 0;
      _syncCompleter = Completer<void>();

      onLogUpdate?.call("⚡ Triggering rapid acoustic calibration pass...");
      _sendSocketMessage('sync:trigger', {});

      // Wait for consensus calculations to complete, up to a 2.5-second barrier timeout
      await _syncCompleter!.future.timeout(
        const Duration(milliseconds: 2500),
        onTimeout: () {
          onLogUpdate?.call("⚠️ Acoustic calibration consensus barrier timed out. Using current offsets.");
        },
      );
    }

    final playAt = Date.nowMs() + _serverClockOffset + 1200 + _hostAcousticDelay;
    
    if (isOfflineMode && _bleSyncCharacteristic != null) {
      // Offline Bluetooth BLE sync command broadcast
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
      // WebSocket server command broadcast
      _sendSocketMessage('playback:play', {
        'id': track.id,
        'trackId': track.id,
        'title': track.title,
        'artistName': track.artistName,
        'albumTitle': track.albumTitle,
        'coverArtUrl': track.coverArtUrl,
        'audioStreamUrl': track.audioStreamUrl,
        'formatBadge': track.formatBadge,
        'durationInSeconds': track.durationInSeconds,
        'playAt': playAt,
      });
    }
  }

  Future<void> broadcastPlayUnsynced(MediaTrack track) async {
    activeTrack = track;
    _hostAcousticDelay = 0;
    
    final playAt = Date.nowMs() + _serverClockOffset + 200; // Fast start for unsynced
    
    if (isOfflineMode && _bleSyncCharacteristic != null) {
      final Map<String, dynamic> bleFrame = {
        'cmd': 'PLAY',
        'id': track.id,
        'title': track.title,
        'artist': track.artistName,
        'delay': 200,
      };
      await _bleSyncCharacteristic!.write(utf8.encode(jsonEncode(bleFrame)));
      _executeCompensatedPlayback(track, 200);
    } else {
      _sendSocketMessage('playback:play', {
        'id': track.id,
        'trackId': track.id,
        'title': track.title,
        'artistName': track.artistName,
        'albumTitle': track.albumTitle,
        'coverArtUrl': track.coverArtUrl,
        'audioStreamUrl': track.audioStreamUrl,
        'formatBadge': track.formatBadge,
        'durationInSeconds': track.durationInSeconds,
        'playAt': playAt,
        'isUnsynced': true,
      });
    }
  }

  Future<void> broadcastPause() async {
    if (isOfflineMode && _bleSyncCharacteristic != null) {
      final bleFrame = {'cmd': 'PAUSE'};
      await _bleSyncCharacteristic!.write(utf8.encode(jsonEncode(bleFrame)));
      _musicPlayer.pause();
      isSongPlaying = false;
      onSongStateChanged?.call(false);
    } else {
      _sendSocketMessage('playback:pause', {});
    }
  }

  Future<void> broadcastSeek(double posSec) async {
    if (isOfflineMode && _bleSyncCharacteristic != null) {
      final bleFrame = {'cmd': 'SEEK', 'pos': posSec};
      await _bleSyncCharacteristic!.write(utf8.encode(jsonEncode(bleFrame)));
      _musicPlayer.seek(Duration(milliseconds: (posSec * 1000).round()));
    } else {
      _sendSocketMessage('playback:seek', {'positionInSeconds': posSec});
    }
  }

  /// Initialize continuous circular microphone stream
  Future<void> _startContinuousMicrophoneStream() async {
    if (_isMicStreaming) return;
    if (!await _audioRecorder.hasPermission()) {
      onLogUpdate?.call("❌ Microphone permissions rejected.");
      return;
    }

    final int rate = Platform.isWindows ? 48000 : DSPEngine.sampleRate;
    final int channels = Platform.isWindows ? 4 : 1;
    const int frameSize = 2; // PCM16 bits
    final byteFrame = channels * frameSize;

    _circularBuffer = Uint8List(rate * byteFrame * 5); // 5 seconds buffer
    _writePointer = 0;
    _totalBytesRecorded = 0;

    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: rate,
      numChannels: channels,
    );

    try {
      final stream = await _audioRecorder.startStream(config);
      _isMicStreaming = true;
      onLogUpdate?.call("🎙️ Mic circular buffer pipeline active (${rate}Hz).");

      _recorderSubscription = stream.listen((chunk) {
        final length = chunk.length;
        if (_writePointer + length <= _circularBuffer.length) {
          _circularBuffer.setRange(_writePointer, _writePointer + length, chunk);
          _writePointer += length;
        } else {
          final part1 = _circularBuffer.length - _writePointer;
          final part2 = length - part1;
          _circularBuffer.setRange(_writePointer, _circularBuffer.length, chunk, 0);
          _circularBuffer.setRange(0, part2, chunk, part1);
          _writePointer = part2;
        }
        _totalBytesRecorded += length;
      });
    } catch (e) {
      onLogUpdate?.call("❌ Mic stream initialization failed: $e");
    }
  }

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
      // Host discovery advertise settings (In real app, starts BLE advertising)
      onLogUpdate?.call("🔵 BLE Advertising Host: 'Spotify_Killer_Sync_Room'...");
    } else {
      // Client scans for Host
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

  // --- AUDIO FILE UTILITIES ---

  Uint8List _packageFloatsToWav(Float32List floats, int sampleRate) {
    final Int16List intBuffer = Int16List(floats.length);
    for (int i = 0; i < floats.length; i++) {
      intBuffer[i] = (floats[i] * 32767).toInt().clamp(-32768, 32767);
    }
    final Uint8List rawAudio = Uint8List.view(intBuffer.buffer);

    final ByteData header = ByteData(44);
    header.setUint32(0, 0x52494646, Endian.big);                 // "RIFF"
    header.setUint32(4, 36 + rawAudio.length, Endian.little);    // Size
    header.setUint32(8, 0x57415645, Endian.big);                 // "WAVE"
    header.setUint32(12, 0x666d7420, Endian.big);                // "fmt "
    header.setUint32(16, 16, Endian.little);                     // Subchunk1Size
    header.setUint16(20, 1, Endian.little);                      // AudioFormat (PCM)
    header.setUint16(22, 1, Endian.little);                      // NumChannels (Mono)
    header.setUint32(24, sampleRate, Endian.little);             // SampleRate
    header.setUint32(28, sampleRate * 2, Endian.little);         // ByteRate
    header.setUint16(32, 2, Endian.little);                      // BlockAlign
    header.setUint16(34, 16, Endian.little);                     // BitsPerSample
    header.setUint32(36, 0x64617461, Endian.big);                // "data"
    header.setUint32(40, rawAudio.length, Endian.little);        // data length

    final wav = Uint8List(44 + rawAudio.length);
    wav.setRange(0, 44, header.buffer.asUint8List());
    wav.setRange(44, wav.length, rawAudio);
    return wav;
  }

  Uint8List _extractMonoFromMultichannel(Uint8List multiBytes, int totalChannels) {
    const int frameSize = 2; // PCM16
    final int rawFrame = totalChannels * frameSize;
    final int totalFrames = multiBytes.length ~/ rawFrame;
    final mono = Uint8List(totalFrames * frameSize);

    int monoOffset = 0;
    for (int i = 0; i < totalFrames * rawFrame; i += rawFrame) {
      mono[monoOffset] = multiBytes[i];
      mono[monoOffset + 1] = multiBytes[i + 1];
      monoOffset += frameSize;
    }
    return mono;
  }

  Future<String> _getLocalCachedPath(String trackId) async {
    final dir = await getApplicationDocumentsDirectory();
    // Resolves file directly matching local download database specifications
    return "${dir.path}/downloads/$trackId.mp3";
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

  void dispose() {
    disconnect();
    _ntpTimer?.cancel();
    _recorderSubscription?.cancel();
    _audioRecorder.dispose();
    _musicPlayer.dispose();
    _chirpPlayer.dispose();
  }
}

class Date {
  static int nowMs() => DateTime.now().millisecondsSinceEpoch;
}
