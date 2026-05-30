import 'dart:math' as math;
import 'dart:typed_data';

class FFTEngine {
  /// Computes the in-place Cooley-Tukey Radix-2 FFT (Forward or Inverse)
  static void transform(Float64List real, Float64List imag, {bool inverse = false}) {
    final int n = real.length;
    if (n == 0) return;
    if ((n & (n - 1)) != 0) {
      throw ArgumentError("FFT length must be a power of 2 (found $n)");
    }

    // 1. Bit-reversal permutation (decimation-in-time)
    int j = 0;
    for (int i = 0; i < n; i++) {
      if (i < j) {
        final double tempReal = real[i];
        real[i] = real[j];
        real[j] = tempReal;

        final double tempImag = imag[i];
        imag[i] = imag[j];
        imag[j] = tempImag;
      }
      int bit = n >> 1;
      while (bit <= j && bit > 0) {
        j -= bit;
        bit >>= 1;
      }
      j += bit;
    }

    // 2. Cooley-Tukey decimation-in-time butterfly passes
    for (int len = 2; len <= n; len <<= 1) {
      final double angle = (inverse ? 2.0 : -2.0) * math.pi / len;
      final double wreal = math.cos(angle);
      final double wimag = math.sin(angle);

      for (int i = 0; i < n; i += len) {
        double ur = 1.0;
        double ui = 0.0;
        final int half = len >> 1;

        for (int k = 0; k < half; k++) {
          final int idx1 = i + k;
          final int idx2 = i + k + half;

          // Complex multiplication butterfly: t = data[idx2] * u
          final double tr = real[idx2] * ur - imag[idx2] * ui;
          final double ti = real[idx2] * ui + imag[idx2] * ur;

          // Butterfly update equations
          real[idx2] = real[idx1] - tr;
          imag[idx2] = imag[idx1] - ti;

          real[idx1] += tr;
          imag[idx1] += ti;

          // Advance twiddle factor: u *= w
          final double nextUr = ur * wreal - ui * wimag;
          ui = ur * wimag + ui * wreal;
          ur = nextUr;
        }
      }
    }

    // 3. Normalize array if performing inverse transform
    if (inverse) {
      for (int i = 0; i < n; i++) {
        real[i] /= n;
        imag[i] /= n;
      }
    }
  }

  /// Helper to compute next power of 2 for input sizing padding
  static int nextPowerOf2(int val) {
    int p = 1;
    while (p < val) {
      p <<= 1;
    }
    return p;
  }

  /// Performs complex element-wise multiplication with conjugate of second signal: out = a * conj(b)
  static void complexMultiplyConjugate(
    Float64List aReal,
    Float64List aImag,
    Float64List bReal,
    Float64List bImag,
    Float64List outReal,
    Float64List outImag,
  ) {
    final int n = aReal.length;
    for (int i = 0; i < n; i++) {
      // (ar + i*ai) * (br - i*bi) = (ar*br + ai*bi) + i*(ai*br - ar*bi)
      final double ar = aReal[i];
      final double ai = aImag[i];
      final double br = bReal[i];
      final double bi = bImag[i];

      outReal[i] = ar * br + ai * bi;
      outImag[i] = ai * br - ar * bi;
    }
  }
}
