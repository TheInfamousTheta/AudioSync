import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:audio_sync/features/party/data/services/fft_engine.dart';
import 'package:audio_sync/features/party/data/services/dsp_engine.dart';

void main() {
  group('FFTEngine Tests', () {
    test('FFT length non-power of 2 throws ArgumentError', () {
      final real = Float64List(7);
      final imag = Float64List(7);
      expect(() => FFTEngine.transform(real, imag), throwsArgumentError);
    });

    test('FFT transform and inverse transform reconstructs original signal', () {
      // 1. Generate a test signal: a simple sine wave at 440Hz sampled at 8000Hz
      const int size = 64; // Power of 2
      final double sampleRate = 8000.0;
      final double frequency = 440.0;

      final originalReal = Float64List(size);
      final real = Float64List(size);
      final imag = Float64List(size);

      for (int i = 0; i < size; i++) {
        double t = i / sampleRate;
        originalReal[i] = math.sin(2 * math.pi * frequency * t);
        real[i] = originalReal[i];
        imag[i] = 0.0;
      }

      // 2. Perform forward transform
      FFTEngine.transform(real, imag, inverse: false);

      // 3. Perform inverse transform
      FFTEngine.transform(real, imag, inverse: true);

      // 4. Verify reconstruction
      for (int i = 0; i < size; i++) {
        expect(real[i], closeTo(originalReal[i], 1e-9));
        expect(imag[i], closeTo(0.0, 1e-9));
      }
    });

    test('complexMultiplyConjugate computes correct values', () {
      final aReal = Float64List.fromList([1.0, 2.0]);
      final aImag = Float64List.fromList([2.0, 3.0]);
      final bReal = Float64List.fromList([3.0, 4.0]);
      final bImag = Float64List.fromList([4.0, 5.0]);

      final outReal = Float64List(2);
      final outImag = Float64List(2);

      FFTEngine.complexMultiplyConjugate(aReal, aImag, bReal, bImag, outReal, outImag);

      // Index 0: (1 + 2i) * (3 - 4i) = (3 + 8) + i(6 - 4) = 11 + 2i
      expect(outReal[0], 11.0);
      expect(outImag[0], 2.0);

      // Index 1: (2 + 3i) * (4 - 5i) = (8 + 15) + i(12 - 10) = 23 + 2i
      expect(outReal[1], 23.0);
      expect(outImag[1], 2.0);
    });

    test('nextPowerOf2 returns correct values', () {
      expect(FFTEngine.nextPowerOf2(0), 1);
      expect(FFTEngine.nextPowerOf2(1), 1);
      expect(FFTEngine.nextPowerOf2(5), 8);
      expect(FFTEngine.nextPowerOf2(8), 8);
      expect(FFTEngine.nextPowerOf2(100), 128);
    });
  });

  group('DSPEngine & PNR & Correlation Tests', () {
    test('generateChirpTemplate output size and value properties', () {
      final chirp = DSPEngine.generateChirpTemplate(
        fStart: 1000.0,
        fEnd: 2000.0,
        duration: 0.01, // 10ms
        targetSampleRate: 44100,
      );

      // Expected size = 44100 * 0.01 = 441 samples
      expect(chirp.length, 441);
      // Sinusoid values should be within [-1.0, 1.0]
      for (final val in chirp) {
        expect(val, greaterThanOrEqualTo(-1.0));
        expect(val, lessThanOrEqualTo(1.0));
      }
    });

    test('locatePeakIndex returns -1 under low Peak-to-Noise Ratio (PNR)', () {
      // 1. Create a quiet recording of noise
      final recording = Float32List(1024);
      final random = math.Random(42);
      for (int i = 0; i < recording.length; i++) {
        recording[i] = (random.nextDouble() * 2 - 1) * 0.01; // Tiny noise
      }

      // 2. Generate a chirp template
      final template = DSPEngine.generateChirpTemplate(
        fStart: 1000.0,
        fEnd: 2000.0,
        duration: 0.005, // 5ms -> 220 samples
        targetSampleRate: 44100,
      );

      // Since there is no signal correlation peak, the PNR should be low and return -1
      final peakIndex = DSPEngine.locatePeakIndex(recording, template);
      expect(peakIndex, -1);
    });

    test('locatePeakIndex finds correct peak offset with high PNR', () {
      // 1. Generate chirp template
      final template = DSPEngine.generateChirpTemplate(
        fStart: 1000.0,
        fEnd: 3000.0,
        duration: 0.005, // 5ms
        targetSampleRate: 44100,
      );

      final int templateLen = template.length; // ~220 samples
      const int targetOffset = 100;
      final int recordingLen = templateLen + targetOffset + 100; // ~420 samples

      final recording = Float32List(recordingLen);
      // Leave silence/low-noise before offset, then embed template, then silence after
      for (int i = 0; i < templateLen; i++) {
        recording[targetOffset + i] = template[i];
      }

      // Add a tiny bit of noise to ensure noise-floor is non-zero
      final random = math.Random(123);
      for (int i = 0; i < recording.length; i++) {
        recording[i] += (random.nextDouble() * 2 - 1) * 0.001;
      }

      // 2. Find peak index
      final peakIndex = DSPEngine.locatePeakIndex(recording, template);

      // Verify it successfully locked onto the correct first-arrival index (90 under 60% threshold)
      expect(peakIndex, 90);
    });

    test('convertBytesToFloat32 converts Int16 bytes properly', () {
      // Create a 4 byte Uint8List representing two 16-bit integers: [32768, -16384]
      // 32767 is max positive signed 16-bit: [0xFF, 0x7F]
      // -32768 is min negative signed 16-bit: [0x00, 0x80]
      final rawBytes = Uint8List.fromList([
        0xFF, 0x7F, // 32767
        0x00, 0x80, // -32768
      ]);

      final floatList = DSPEngine.convertBytesToFloat32(rawBytes);
      expect(floatList.length, 2);
      expect(floatList[0], closeTo(32767.0 / 32768.0, 1e-5));
      expect(floatList[1], closeTo(-32768.0 / 32768.0, 1e-5));
    });
  });
}
