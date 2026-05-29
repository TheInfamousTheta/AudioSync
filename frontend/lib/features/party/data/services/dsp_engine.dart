import 'dart:math' as math;
import 'dart:typed_data';

/// Parameter wrapper used to pass unified payloads to the background Isolate task runner thread
class BackgroundDSPArgs {
  final Uint8List rawCapturedBytes;
  final Float32List selfTemplate;
  final Float32List crossTemplate;

  BackgroundDSPArgs({
    required this.rawCapturedBytes,
    required this.selfTemplate,
    required this.crossTemplate,
  });
}

/// Structural container holding calculated peak indicators returned from the Isolate worker thread
class BackgroundDSPResult {
  final int tSelf;
  final int tCross;

  BackgroundDSPResult({required this.tSelf, required this.tCross});
}

class DSPEngine {
  static const int sampleRate = 44100; 

  /// Generates a Float32 linear frequency modulated chirp template array
  static Float32List generateChirpTemplate({
    required double fStart,
    required double fEnd,
    double duration = 0.05,
    required int targetSampleRate,
  }) {
    final int numSamples = (targetSampleRate * duration).toInt();
    final Float32List chirp = Float32List(numSamples);

    for (int i = 0; i < numSamples; i++) {
      double t = i / targetSampleRate;
      double phase = 2 * math.pi * (fStart * t + 0.5 * (fEnd - fStart) / duration * t * t);
      chirp[i] = math.sin(phase);
    }
    return chirp;
  }

  /// Entry point running inside a separate Isolate thread background container.
  /// Handles byte parsing and correlation algorithms concurrently.
  static BackgroundDSPResult processAudioBackground(BackgroundDSPArgs args) {
    // 1. Execute O(N) integer-to-float byte normalization on the background thread
    final Float32List recordedSignal = convertBytesToFloat32(args.rawCapturedBytes);

    // 2. Execute heavy cross-correlation sliding dot-product scans sequentially
    int tSelf = locatePeakIndex(recordedSignal, args.selfTemplate);
    int tCross = locatePeakIndex(recordedSignal, args.crossTemplate);

    return BackgroundDSPResult(tSelf: tSelf, tCross: tCross);
  }

  /// Highly robust cross-correlation peak scan engine using a First-Arrival Detector.
  /// Safely rejects late multipath reflections and suppresses hardware processing latency variations.
  static int locatePeakIndex(Float32List recording, Float32List template) {
    final int recLength = recording.length;
    final int tempLength = template.length;
    final int searchWindowLength = recLength - tempLength;
    
    if (searchWindowLength <= 0) return -1;

    // Track cross-correlation scores across the entire window
    final Float32List scores = Float32List(searchWindowLength + 1);
    double globalMax = 0.0;
    double sumScores = 0.0;

    // PERFORMANCE OPTIMIZATION: Local references prevent array boundary/property 
    // lookup overhead checks on every single nested loop iteration cycle.
    final Float32List localRec = recording;
    final Float32List localTemp = template;

    for (int i = 0; i <= searchWindowLength; i++) {
      double currentSum = 0.0;
      
      for (int j = 0; j < tempLength; j++) {
        currentSum += localRec[i + j] * localTemp[j];
      }
      
      double absScore = currentSum.abs();
      scores[i] = absScore;
      sumScores += absScore;

      if (absScore > globalMax) {
        globalMax = absScore;
      }
    }

    if (globalMax == 0) return -1;

    // Calculate background noise floor average score
    double avgNoise = sumScores / scores.length;
    
    // Peak-to-Noise Ratio (PNR) validation gate check
    if ((globalMax / avgNoise) < 3.5) {
      return -1; 
    }

    // FIX B: FIRST-ARRIVAL LINE-OF-SIGHT DETECTOR
    // Bypasses the absolute highest global peak (which is frequently a loud wall/desk echo reflection) 
    // and catches the earliest wavefront crossing an optimized energy threshold instead.
    double arrivalThreshold = globalMax * 0.60; // 60% of absolute maximum energy height
    
    for (int i = 2; i < scores.length - 2; i++) {
      if (scores[i] >= arrivalThreshold) {
        // Local maxima confirmation check (ensures it is a local peak vertex)
        if (scores[i] > scores[i - 1] && scores[i] > scores[i + 1]) {
          return i; // Return the true direct Line-of-Sight arrival index!
        }
      }
    }

    // Fallback: If no clear local peak crosses the threshold branch cleanly,
    // lock back onto the traditional absolute maximum global index score.
    int maxIdx = 0;
    double maxV = 0.0;
    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > maxV) {
        maxV = scores[i];
        maxIdx = i;
      }
    }
    return maxIdx;
  }

  /// Converts raw 16-bit signed integer byte array buffer arrays to normalized Float32 vectors
  static Float32List convertBytesToFloat32(Uint8List rawBytes) {
    final int int16Count = rawBytes.length ~/ 2;
    final Int16List int16Data = Int16List.view(rawBytes.buffer, rawBytes.offsetInBytes, int16Count);
    final Float32List float32Data = Float32List(int16Count);

    for (int i = 0; i < int16Count; i++) {
      float32Data[i] = int16Data[i] / 32768.0;
    }
    return float32Data;
  }

  /// Generates a Float32 click/pop sound with rapid exponential decay envelope for alignment tests
  static Float32List generateTestSound({
    double freq = 2500.0,
    double duration = 0.15,
    required int targetSampleRate,
  }) {
    final int numSamples = (targetSampleRate * duration).toInt();
    final Float32List sound = Float32List(numSamples);
    for (int i = 0; i < numSamples; i++) {
      double t = i / targetSampleRate;
      double envelope = math.exp(-12.0 * t); // slightly slower decay for much higher audibility
      sound[i] = math.sin(2 * math.pi * freq * t) * envelope;
    }
    return sound;
  }
}

