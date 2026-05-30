import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_session/audio_session.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
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
  bool _isNtpSuspended = false;

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
  
  bool _isPreloadingChirp = false;
  bool _isStartingMic = false;

  // Real-time Acoustic Synchronization Matrix states
  String? localUsername;
  bool isHost = false;
  int _acousticOffset = 0;
  int _hostAcousticDelay = 0;
  final Map<String, Map<String, dynamic>> _alignmentDataMap = {};
  final Map<String, Map<String, dynamic>> _pendingGuestAlignments = {};
  Completer<void>? _syncCompleter;

  // Multi-client FDMA coordination variables
  String? hostId;
  List<dynamic> members = const [];
  Uint8List? _hostCapturedMonoBuffer;
  int? _hostTSelf;
  bool simulateGuestDelay300ms = false;

  int getGuestIndex(String targetUserId) {
    final guests = members.where((m) {
      final mUserId = m['userId'] as String? ?? '';
      return mUserId != hostId;
    }).toList();
    
    guests.sort((a, b) {
      final String idA = a['userId'] as String? ?? '';
      final String idB = b['userId'] as String? ?? '';
      return idA.compareTo(idB);
    });

    final idx = guests.indexWhere((m) {
      final mUserId = m['userId'] as String? ?? '';
      return mUserId == targetUserId;
    });
    return idx != -1 ? idx : 0;
  }

  int getMyGuestIndex() {
    if (localUsername == null) return 0;
    final guests = members.where((m) {
      final mUserId = m['userId'] as String? ?? '';
      return mUserId != hostId;
    }).toList();
    
    guests.sort((a, b) {
      final String idA = a['userId'] as String? ?? '';
      final String idB = b['userId'] as String? ?? '';
      return idA.compareTo(idB);
    });

    final idx = guests.indexWhere((m) => m['username'] == localUsername);
    return idx != -1 ? idx : 0;
  }

  Future<void> _preloadAllChirpsToDisk() async {
    if (Platform.isWindows) return;
    try {
      final tempDir = await getTemporaryDirectory();
      
      // 1. Preload Host Chirp
      final hostChirp = DSPEngine.generateChirpTemplate(
        fStart: 1500.0,
        fEnd: 3000.0,
        targetSampleRate: DSPEngine.sampleRate,
      );
      final hostWav = _packageFloatsToWav(hostChirp, DSPEngine.sampleRate);
      final hostFile = File('${tempDir.path}/host_chirp_template.wav');
      await hostFile.writeAsBytes(hostWav);
      
      // 2. Preload Guest Chirps
      for (int i = 0; i < 4; i++) {
        final double cStart = 3500.0 + (i * 400.0);
        final double cEnd = 3800.0 + (i * 400.0);
        final guestChirp = DSPEngine.generateChirpTemplate(
          fStart: cStart,
          fEnd: cEnd,
          targetSampleRate: DSPEngine.sampleRate,
        );
        final guestWav = _packageFloatsToWav(guestChirp, DSPEngine.sampleRate);
        final guestFile = File('${tempDir.path}/guest_chirp_template_$i.wav');
        await guestFile.writeAsBytes(guestWav);
      }
      onLogUpdate?.call("⚡ All calibration chirp templates preloaded on disk successfully!");
    } catch (e) {
      onLogUpdate?.call("⚠️ Failed preloading calibration chirps: $e");
    }
  }

  Future<void> preloadChirpPlayer() async {
    if (Platform.isWindows) return;
    if (_isPreloadingChirp) {
      onLogUpdate?.call("⏳ Preload already in progress. Skipping duplicate request.");
      return;
    }
    _isPreloadingChirp = true;
    try {
      final tempDir = await getTemporaryDirectory();
      String path;
      if (isHost) {
        path = '${tempDir.path}/host_chirp_template.wav';
      } else {
        final int guestIndex = getMyGuestIndex();
        path = '${tempDir.path}/guest_chirp_template_${guestIndex.clamp(0, 3)}.wav';
      }
      
      // Verify file exists, if not generate it on the fly
      final file = File(path);
      if (!await file.exists()) {
        onLogUpdate?.call("⚠️ Chirp file not found at $path. Re-generating...");
        await _preloadAllChirpsToDisk();
      }

      // Check if path is already loaded to avoid redundant setAudioSource calls!
      if (_dynamicChirpPath == path && _chirpPlayer.audioSource != null) {
        onLogUpdate?.call("📦 Chirp template already preloaded. Skipping redundant setAudioSource.");
        _isPreloadingChirp = false;
        return;
      }

      _dynamicChirpPath = path;
      onLogUpdate?.call("📦 Preloading chirp player with template: $path");
      
      // Stop to clear active play state and prevent auto-play on source change
      await _chirpPlayer.stop();
      
      await _chirpPlayer.setAudioSource(ja.AudioSource.file(path));
      await _chirpPlayer.setVolume(1.0);
    } catch (e) {
      onLogUpdate?.call("⚠️ Failed to preload chirp player: $e");
    } finally {
      _isPreloadingChirp = false;
    }
  }

  static Future<BackgroundDSPResult> runBackgroundDSPIsolate(BackgroundDSPArgs args) {
    return Isolate.run(() => DSPEngine.processAudioBackground(args));
  }

  static Future<int> runLocatePeakIsolate(Float32List signal, Float32List template) {
    return Isolate.run(() => DSPEngine.locatePeakIndex(signal, template));
  }

  Future<void> initialize() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.defaultToSpeaker | AVAudioSessionCategoryOptions.allowBluetooth,
        avAudioSessionMode: AVAudioSessionMode.measurement,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      ));
      await session.setActive(true);
      onLogUpdate?.call("🔊 Audio session warmed up & configured for Play-and-Record measurement mode successfully.");
    } catch (e) {
      onLogUpdate?.call("⚠️ Audio session configuration warning: $e");
    }

    if (!SoLoud.instance.isInitialized) {
      await SoLoud.instance.init();
    }
    // 1. Generate and write wav files to disk first (fast, no permissions needed)
    await _preloadAllChirpsToDisk();
    
    // 2. Start microphone stream in the background (may prompt OS permission dialog)
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
    _acousticOffset = 0;
    _hostAcousticDelay = 0;
    _alignmentDataMap.clear();
    _isNtpSuspended = false;
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
    _isNtpSuspended = false;
    onSongStateChanged?.call(false);
    onLogUpdate?.call("🔇 Audio stopped and playback state reset.");
  }

  void _sendSocketMessage(String event, Map<String, dynamic> data) {
    if (_wsChannel != null) {
      _wsChannel!.sink.add(jsonEncode({'event': event, 'data': data}));
    }
  }

  void _triggerWANTimesync() {
    if (_isNtpSuspended) {
      onLogUpdate?.call("⏳ Background NTP sync updates suspended to maintain active timeline lock.");
      return;
    }
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
        _acousticOffset = 0;
        _hostAcousticDelay = 0;
        onCalculationComplete?.call(0.0, 0.0, "⚡ Syncing: calibration in progress...");
        executeDynamicAcousticSync();
        break;
      }

      case 'sync:alignment': {
        final userId = data['userId'] as String;
        final username = data['username'] as String;
        final tSelf = data['tSelf'] as int;
        final tCross = data['tCross'] as int;
        final guestSampleRate = data['sampleRate'] as int? ?? DSPEngine.sampleRate;

        onLogUpdate?.call("📥 Alignment data received from $username ($userId): tSelf=$tSelf, tCross=$tCross, sampleRate=$guestSampleRate");

        _alignmentDataMap[userId] = {
          'tSelf': tSelf,
          'tCross': tCross,
          'sampleRate': guestSampleRate,
          'username': username,
        };

        if (isHost && userId != hostId) {
          if (_hostCapturedMonoBuffer != null && _hostTSelf != null) {
            // Host correlation is done! Process instantly.
            _correlateGuestAndComputeConsensus(userId, username, tSelf, tCross, guestSampleRate);
          } else {
            // Host is still recording/correlating! Queue alignment.
            _pendingGuestAlignments[userId] = {
              'userId': userId,
              'username': username,
              'tSelf': tSelf,
              'tCross': tCross,
              'sampleRate': guestSampleRate,
            };
            onLogUpdate?.call("⏳ Host correlation pending. Queued $username's alignment.");
          }
        }
        break;
      }

      case 'sync:offset': {
        final targetUsername = data['username'] as String?;
        final offsetMs = data['offsetMs'] as int;

        if (localUsername != null && localUsername == targetUsername) {
          _acousticOffset = offsetMs;
          onLogUpdate?.call("🎯 Acoustic calibration lock applied to player pipeline: ${_acousticOffset}ms delay compensation");

          onCalculationComplete?.call(
            _acousticOffset.toDouble(),
            0.0,
            "Calibration Lock: ${_acousticOffset}ms compensation",
          );
        }
        break;
      }

      case 'playback:play': {
        final track = MediaTrack.fromJson(data);
        final playAtServer = data['playAt'] as int;
        final bool isUnsynced = data['isUnsynced'] == true;
        final bool isNoNtp = data['isNoNtp'] == true;
        onLogUpdate?.call("📥 playback:play received from socket. track: '${track.title}', isUnsynced: $isUnsynced, isNoNtp: $isNoNtp");

        if (isNoNtp) {
          _acousticOffset = 0;
          onLogUpdate?.call("📢 No-NTP play directive received. Playing instantly upon packet receipt.");
          
          if (isHost) {
            onLogUpdate?.call("📢 Skipping redundant No-NTP play directive received from myself.");
            break;
          }
          
          _executeCompensatedPlayback(track, 0);
          break;
        }

        if (isUnsynced) {
          _acousticOffset = 0;
          onLogUpdate?.call("📢 Unsynced play directive received. Resetting calibration offsets.");
          
          if (isHost) {
            onLogUpdate?.call("📢 Skipping redundant unsynced play directive received from myself.");
            break;
          }
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

  void broadcastPlaylistUpdate() {
    _sendSocketMessage('playlist:update', {});
  }

  /// Dynamically synthesizes chirp on-demand, plays via Soloud, records mic, and processes in background Isolate
  Future<void> executeDynamicAcousticSync() async {
    _isNtpSuspended = true;
    try {
      // 1. INSTANTLY STOP AND SILENCE MUSIC PLAYER TO PREVENT ACOUSTIC SATURATION
      try {
        if (_musicPlayer.playing) {
          onLogUpdate?.call("🤫 Sync trigger received. Stopping music player instantly to clear noise floor.");
          await _musicPlayer.stop();
        }
      } catch (_) {}

      if (_isAcousticSyncing) {
        onLogUpdate?.call("⏳ Acoustic sync already in progress. Skipping.");
        return;
      }
      _isAcousticSyncing = true;

      // FORCE RESTART MICROPHONE STREAM TO SECURE AUDIO SESSION FOCUS & CLEAR STALE BUFFERS
      onLogUpdate?.call("🎙️ Securing raw microphone focus...");
      await _stopMicrophoneStream();
      await _startContinuousMicrophoneStream();

      // 1. Capture snapshot start marker BEFORE generating or playing chirps to guarantee complete waveform inclusion
      final int snapshotStartMarker = _totalBytesRecorded;

      onLogUpdate?.call("⚡ Generating dynamic calibration chirps...");

      final int targetRate = Platform.isWindows ? 48000 : DSPEngine.sampleRate;
      final bool isPC = Platform.isWindows;

      // Allocate dynamic sub-band based on Host/Client FDMA roles
      Float32List selfChirpData;
      Float32List crossChirpData;

      if (isHost) {
        selfChirpData = DSPEngine.generateChirpTemplate(
          fStart: 1000.0,
          fEnd: 2000.0,
          targetSampleRate: targetRate,
        );
        crossChirpData = selfChirpData;
      } else {
        final int guestIndex = getMyGuestIndex();
        final double cStart = 2200.0 + (guestIndex.clamp(0, 3) * 450.0);
        final double cEnd = 2500.0 + (guestIndex.clamp(0, 3) * 450.0);

        onLogUpdate?.call("⚡ Assigned Client dynamic sub-band: ${cStart.round()}–${cEnd.round()}Hz (Index: $guestIndex)");

        selfChirpData = DSPEngine.generateChirpTemplate(
          fStart: cStart,
          fEnd: cEnd,
          targetSampleRate: targetRate,
        );
        crossChirpData = DSPEngine.generateChirpTemplate(
          fStart: 1000.0,
          fEnd: 2000.0,
          targetSampleRate: targetRate,
        );
      }

      // Load dynamic WAV directly into SoLoud heap
      final Uint8List wavBytes = _packageFloatsToWav(selfChirpData, targetRate);
      bool playedViaSoLoud = false;
      try {
        _activeChirpSource = await SoLoud.instance.loadMem(
          "dynamic_calibration_chirp.wav",
          wavBytes,
          mode: LoadMode.memory,
        );
        onLogUpdate?.call("⚡ Dynamic chirp loaded to SoLoud memory successfully.");
        SoLoud.instance.play(_activeChirpSource!);
        playedViaSoLoud = true;
      } catch (e) {
        onLogUpdate?.call("⚠️ SoLoud chirp playback failed, falling back to just_audio: $e");
      }

      // Emit chirp instantly (using SoLoud or just_audio fallback)
      onLogUpdate?.call("🔊 Emitting calibration chirp (${isHost ? '1.5–3.0' : 'dynamic High'}kHz — audible reference).");
      if (!playedViaSoLoud) {
        try {
          if (_dynamicChirpPath == null) {
            await preloadChirpPlayer();
          }
          await _chirpPlayer.seek(Duration.zero);
          _chirpPlayer.play();
        } catch (e) {
          onLogUpdate?.call("❌ Fallback chirp playback failed: $e");
        }
      }

      // 2. CHECK MICROPHONE STREAM STATUS BEFORE RECORDING SNAPSHOT
      if (!_isMicStreaming) {
        onLogUpdate?.call("⚠️ Microphone stream inactive. Cannot capture calibration snapshot.");
        _isAcousticSyncing = false;
        _isNtpSuspended = false;
        onCalculationComplete?.call(0.0, 0.0, "❌ Calibration failed. Mic stream inactive.");
        
        // Send failed alignment immediately so we don't block
        if (!isHost) {
          _sendSocketMessage('sync:alignment', {
            'tSelf': -1,
            'tCross': -1,
            'username': localUsername,
          });
        }
        return;
      }

      // Acoustic timeline capture (using snapshotStartMarker captured before chirp emission)
      final int targetLength = (targetRate * 1.5 * (Platform.isWindows ? 8 : 2)).toInt(); // channels * 2 bytes
      final Uint8List capturedBuffer = Uint8List(targetLength);

      // Await 1.5s recording snapshot
      await Future.delayed(const Duration(milliseconds: 1500));

      // Stop player to clear playing state
      try {
        _chirpPlayer.stop();
      } catch (_) {}

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

      if (isHost) {
        // Host saves captured monoBuffer to correlate guest chirps on demand
        _hostCapturedMonoBuffer = monoBuffer;

        // Correlate Host's Low Band against raw capture to locate host's own tSelf
        final dspArgs = BackgroundDSPArgs(
          rawCapturedBytes: monoBuffer,
          selfTemplate: selfChirpData,
          crossTemplate: selfChirpData,
        );
        final dspAnalysis = await PartySyncService.runBackgroundDSPIsolate(dspArgs);

        _hostTSelf = dspAnalysis.tSelf;
        _isAcousticSyncing = false;
        onLogUpdate?.call("🎯 Host capture completed. Local self peak index: $_hostTSelf");

        // Register host's own alignment for consensus
        _alignmentDataMap[hostId ?? "host"] = {
          'tSelf': _hostTSelf,
          'tCross': _hostTSelf,
          'username': localUsername,
        };

        // Process any pending guest alignments that arrived early!
        if (_pendingGuestAlignments.isNotEmpty) {
          onLogUpdate?.call("⚡ Processing ${_pendingGuestAlignments.length} pending guest alignments...");
          final pendingCopy = Map<String, Map<String, dynamic>>.from(_pendingGuestAlignments);
          _pendingGuestAlignments.clear();
          
          pendingCopy.forEach((uid, alignData) {
            _correlateGuestAndComputeConsensus(
              alignData['userId'] as String,
              alignData['username'] as String,
              alignData['tSelf'] as int,
              alignData['tCross'] as int,
              alignData['sampleRate'] as int? ?? DSPEngine.sampleRate,
            );
          });
        }

        // Cleanup Host Soloud buffer immediately to purge heap
        if (_activeChirpSource != null) {
          SoLoud.instance.disposeSource(_activeChirpSource!);
          _activeChirpSource = null;
        }
      } else {
        // Guest processes self & cross correlations as usual
        final dspArgs = BackgroundDSPArgs(
          rawCapturedBytes: monoBuffer,
          selfTemplate: selfChirpData,
          crossTemplate: crossChirpData,
        );

        final dspAnalysis = await PartySyncService.runBackgroundDSPIsolate(dspArgs);

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
          'sampleRate': targetRate,
          'username': localUsername,
        });
      }
    } catch (e, st) {
      onLogUpdate?.call("❌ Critical error inside executeDynamicAcousticSync: $e\n$st");
      _isAcousticSyncing = false;
      _isNtpSuspended = false;
      onCalculationComplete?.call(0.0, 0.0, "❌ Calibration error: $e");
      if (isHost && _syncCompleter != null && !_syncCompleter!.isCompleted) {
        _syncCompleter!.complete();
      }
    }
  }

  Future<void> _executeCompensatedPlayback(MediaTrack track, int targetLocalTimeOrDelay) async {
    _isNtpSuspended = true;
    try {
      await _stopMicrophoneStream();
      await _resetAudioSessionToPlayback();
    } catch (_) {}

    try {
      AudioSystemManager().player.stop();
    } catch (_) {}

    try {
      onLogUpdate?.call("🎵 Stopping current music player...");
      await _musicPlayer.stop();

      if (track.audioStreamUrl.isEmpty) {
        onLogUpdate?.call("⚠️ Warning: Received track audioStreamUrl is empty!");
      }

      if (track.id == 'test_sound_track') {
        final tempDir = await getTemporaryDirectory();
        final testSoundFile = File('${tempDir.path}/test_sound_sharp_2500hz.wav');
        onLogUpdate?.call("🔊 Checking test sound WAV at: ${testSoundFile.path}");
        if (!await testSoundFile.exists()) {
          onLogUpdate?.call("🔊 Synthesizing 2500Hz test sound WAV pop programmatically...");
          final targetRate = Platform.isWindows ? 48000 : DSPEngine.sampleRate;
          final testSoundFloats = DSPEngine.generateTestSound(targetSampleRate: targetRate);
          final testSoundWavBytes = _packageFloatsToWav(testSoundFloats, targetRate);
          await testSoundFile.writeAsBytes(testSoundWavBytes);
          onLogUpdate?.call("🔊 Saved synthesized WAV test pop to disk.");
        }
        onLogUpdate?.call("🔊 Loading test sound file into player...");
        await _musicPlayer.setAudioSource(ja.AudioSource.file(testSoundFile.path));
        onLogUpdate?.call("🔊 Test sound source set successfully.");
      } else {
        // Cache-first high-precision local storage playback verification
        final String localPath = await _getLocalCachedPath(track.id);
        final file = File(localPath);
        if (await file.exists()) {
          onLogUpdate?.call("💾 Pre-cached hit! Playing track locally from storage: $localPath");
          await _musicPlayer.setAudioSource(ja.AudioSource.file(localPath));
        } else {
          // Direct stream play through the proxy url
          onLogUpdate?.call("☁️ Cache miss. Streaming remote URL: ${track.audioStreamUrl}");
          await _musicPlayer.setAudioSource(ja.AudioSource.uri(Uri.parse(track.audioStreamUrl)));
        }
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

    final guests = members.where((m) => m['userId'] != hostId).toList();

    if (guests.isNotEmpty) {
      // Clear previous acoustic sync metrics before starting the new session calibration
      _alignmentDataMap.clear();
      _hostAcousticDelay = 0;
      _acousticOffset = 0;
      _hostCapturedMonoBuffer = null;
      _hostTSelf = null;
      _syncCompleter = Completer<void>();

      onLogUpdate?.call("⚡ Triggering rapid acoustic calibration pass with ${guests.length} guest(s)...");
      onCalculationComplete?.call(0.0, 0.0, "⚡ Syncing: calibration in progress...");
      _sendSocketMessage('sync:trigger', {});

      // Wait for consensus calculations to complete, up to a 4.5-second barrier timeout
      await _syncCompleter!.future.timeout(
        const Duration(milliseconds: 4500),
        onTimeout: () {
          onLogUpdate?.call("⚠️ Acoustic calibration consensus barrier timed out. Using current offsets.");
          onCalculationComplete?.call(
            0.0,
            0.0,
            "⚠️ Lock Timeout. Using unsynced fallback.",
          );
        },
      ).catchError((_) => null); // Catch timeout exception safely to ensure playback still launches
    } else {
      onLogUpdate?.call("📢 Playing track instantly (offline or no guests connected).");
      _hostAcousticDelay = 0;
      _acousticOffset = 0;
      onCalculationComplete?.call(
        0.0,
        0.0,
        "Lock: Instantly synced play",
      );
    }

    final int schedulingWindow = track.id == 'test_sound_track'
        ? (guests.isNotEmpty ? 1200 : 200)
        : (guests.isNotEmpty ? 2500 : 600); // 2500ms for real remote song tracks to ensure robust buffering!

    final playAt = Date.nowMs() + _serverClockOffset + schedulingWindow;
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

  Future<void> broadcastPlayUnsynced(MediaTrack track) async {
    activeTrack = track;
    _hostAcousticDelay = 0;
    _acousticOffset = 0;
    
    final playAt = Date.nowMs() + _serverClockOffset + 600; // 600ms safety window for unsynced
    onLogUpdate?.call("📢 broadcastPlayUnsynced initiated. playAt: $playAt");
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

    // Play locally immediately on the Host to bypass WebSocket roundtrip latency
    onLogUpdate?.call("📢 Executing local instant unsynced playback on Host...");
    _executeCompensatedPlayback(track, Date.nowMs() + 600);
  }

  Future<void> broadcastPlayNoNtp(MediaTrack track) async {
    activeTrack = track;
    _hostAcousticDelay = 0;
    _acousticOffset = 0;
    onLogUpdate?.call("📢 broadcastPlayNoNtp initiated. Firing instantly with 0ms delay.");
    
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
      'playAt': 0,
      'isNoNtp': true,
    });

    // Play locally immediately on the Host with 0ms delay
    _executeCompensatedPlayback(track, 0);
  }

  Future<void> broadcastPause() async {
    _sendSocketMessage('playback:pause', {});
  }

  Future<void> broadcastSeek(double posSec) async {
    _sendSocketMessage('playback:seek', {'positionInSeconds': posSec});
  }

  /// Initialize continuous circular microphone stream
  Future<void> _startContinuousMicrophoneStream() async {
    if (_isMicStreaming) return;
    if (_isStartingMic) return;
    _isStartingMic = true;
    try {
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
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      );

      final stream = await _audioRecorder.startStream(config);
      _isMicStreaming = true;
      onLogUpdate?.call("🎙️ Mic circular buffer pipeline active (${rate}Hz, Raw No-DSP Mode).");

      int chunkDiagCount = 0;
      _recorderSubscription = stream.listen((chunk) {
        final length = chunk.length;

        // Calculate peak amplitude in this chunk to verify microphone activity
        int maxSample = 0;
        for (int i = 0; i < length - 1; i += 2) {
          final int val = (chunk[i] | (chunk[i + 1] << 8)).toSigned(16).abs();
          if (val > maxSample) maxSample = val;
        }
        chunkDiagCount++;
        if (chunkDiagCount % 200 == 0) {
          onLogUpdate?.call("🎙️ [Mic Diagnostic] Chunk #$chunkDiagCount | Peak Amplitude: $maxSample");
        }

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
    } finally {
      _isStartingMic = false;
    }
  }

  Future<void> _stopMicrophoneStream() async {
    try {
      await _recorderSubscription?.cancel();
      _recorderSubscription = null;
      await _audioRecorder.stop();
    } catch (_) {}
    _isMicStreaming = false;
  }

  Future<void> _resetAudioSessionToPlayback() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());
      await session.setActive(true);
      onLogUpdate?.call("🔊 Audio session successfully reset to high-fidelity Playback-only mode.");
    } catch (e) {
      onLogUpdate?.call("⚠️ Failed to restore audio session to high-fidelity playback: $e");
    }
  }

  // BLE Offline coordination methods extracted to BleOfflineSyncService

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
    // Unify filename with DownloadManager exact pattern track_$trackId.mp3
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

  void _correlateGuestAndComputeConsensus(String userId, String username, int tSelf, int tCross, int guestSampleRate) {
    if (_hostCapturedMonoBuffer == null || _hostTSelf == null) return;
    
    // Calculate guest index in deterministic sorted list
    final int guestIndex = getGuestIndex(userId);
    
    final double gStart = 2200.0 + (guestIndex.clamp(0, 3) * 450.0);
    final double gEnd = 2500.0 + (guestIndex.clamp(0, 3) * 450.0);
    final int targetRate = Platform.isWindows ? 48000 : DSPEngine.sampleRate;

    onLogUpdate?.call("⚡ Correlating $username on sub-band ${gStart.round()}–${gEnd.round()}Hz (Index: $guestIndex)...");

    // Run single correlation inside background isolate to avoid UI thread lag
    final template = DSPEngine.generateChirpTemplate(
      fStart: gStart,
      fEnd: gEnd,
      targetSampleRate: targetRate,
    );

    final Float32List signal = DSPEngine.convertBytesToFloat32(_hostCapturedMonoBuffer!);
    PartySyncService.runLocatePeakIsolate(signal, template).then((tCrossPc) {
      bool isFailure = false;
      String missingDevice = "";

      if (_hostTSelf == -1) {
        isFailure = true;
        missingDevice = localUsername ?? "Host";
      } else if (tSelf == -1 || tCross == -1) {
        isFailure = true;
        missingDevice = username;
      } else if (tCrossPc == -1) {
        isFailure = true;
        missingDevice = "Host (missed $username)";
      }

      if (simulateGuestDelay300ms) {
        isFailure = false; // Force success to allow robust local testing bypass!
      }

      if (isFailure) {
        onLogUpdate?.call("⚠️ Calibration failure detected! Missing: $missingDevice");
        onLogUpdate?.call("❌ Calibration failed. Falling back to default sync.");
        onCalculationComplete?.call(0, 0, "❌ Calibration failed. Using 0ms fallback.");
        
        // Fallback: Client offset = 0, Host delay = 0
        _hostAcousticDelay = 0;
        _sendSocketMessage('sync:offset', {
          'userId': userId,
          'offsetMs': 0,
        });
        
        _isNtpSuspended = false;
        
        if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
          _syncCompleter!.complete();
        }
        return;
      }

      onLogUpdate?.call("🎯 Peak located for $username: tCrossPc=$tCrossPc");

      // Calculate relative delay offset using double chirps consensus with Guest's actual sample rate
      double rawMsOffset = 0.0;
      bool isRealSyncSuccessful = (_hostTSelf != -1 && tSelf != -1 && tCross != -1 && tCrossPc != -1);

      if (isRealSyncSuccessful) {
        final double dtPhone = (tCross - tSelf) / guestSampleRate.toDouble();
        final double dtPc = (tCrossPc - (_hostTSelf ?? 0)) / targetRate.toDouble();
        rawMsOffset = ((dtPhone - dtPc) / 2) * 1000;
      } else {
        rawMsOffset = 0.0;
      }

      if (simulateGuestDelay300ms) {
        rawMsOffset -= 300.0;
        onLogUpdate?.call("🧪 Adding +300ms simulated test delay. (Calculated sync: ${isRealSyncSuccessful ? (rawMsOffset + 300.0).toStringAsFixed(2) : 'failed, using 0ms fallback'} ms)");
      }

      onLogUpdate?.call("🎯 Acoustic Sync consensus for $username: ${rawMsOffset.toStringAsFixed(2)} ms");

      onCalculationComplete?.call(
        rawMsOffset, 
        rawMsOffset.abs() * 0.343, 
        "Lock: $username delay is ${rawMsOffset.round()}ms",
      );

      if (rawMsOffset < 0) {
        // Host is leading: Host delays itself, Client plays immediately (0 delay)
        _hostAcousticDelay = rawMsOffset.abs().round();
        _acousticOffset = _hostAcousticDelay;
        _sendSocketMessage('sync:offset', {
          'userId': userId,
          'username': username,
          'offsetMs': 0,
        });
      } else {
        // Client is leading: Client delays itself, Host plays immediately (0 delay)
        _hostAcousticDelay = 0;
        _acousticOffset = 0;
        _sendSocketMessage('sync:offset', {
          'userId': userId,
          'username': username,
          'offsetMs': rawMsOffset.round(),
        });
      }

      // Complete the sync barrier completer since consensus was computed
      if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
        _syncCompleter!.complete();
      }
    });
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
