import 'dart:typed_data';

// ============================================================
// SCRAMBLER — per-project keystream string hider
// ============================================================
// Sensitive strings (config endpoint, attribution key, messaging
// sender id, browser version fragments) are stored as scrambled byte
// lists instead of plaintext literals, so a raw string dump of the
// binary reveals nothing greppable.
//
// Scheme (kept symmetric so `tool/pack_secrets.dart` encodes with the
// exact same routine that [reveal] decodes with):
//   1. A salt phrase is folded into a 32-bit FNV-1a hash.
//   2. That hash seeds an xorshift32 stream of [_ringSize] bytes.
//   3. output[i] = input[i] ^ ring[i % ringSize] ^ ((i * 31 + 17) & 0xFF).
//      The affine positional term makes repeated plaintext bytes encode
//      to different ciphertext depending on offset.
//
// ─────────────────────────────────────────────────────────────
// FINGERPRINT — unique to Ash Rise. Do not reuse [_saltPhrase] or
// [_ringSize] in any other project; if either changes, re-run
// `dart run tool/pack_secrets.dart` and repaste the arrays into
// lib/wire/packed_secrets.dart.
// ─────────────────────────────────────────────────────────────
const String _saltPhrase = 'pV7#kLm2qXr8';
const int _ringSize = 29;

Uint8List _buildRing() {
  int hash = 0x811C9DC5;
  for (final int c in _saltPhrase.codeUnits) {
    hash = (hash ^ c) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }

  int state = hash == 0 ? 0x9E3779B9 : hash;
  final Uint8List ring = Uint8List(_ringSize);
  for (int i = 0; i < _ringSize; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    ring[i] = (state >> 16) & 0xFF;
  }
  return ring;
}

final Uint8List _ring = _buildRing();

/// Decodes a scrambled byte list back into its original string. An empty
/// list decodes to "" — the graceful path used before real credentials
/// are packed via `tool/pack_secrets.dart`.
String reveal(List<int> packed) {
  if (packed.isEmpty) return '';
  final Uint8List out = Uint8List(packed.length);
  for (int i = 0; i < packed.length; i++) {
    out[i] = (packed[i] ^ _ring[i % _ringSize] ^ ((i * 31 + 17) & 0xFF)) & 0xFF;
  }
  return String.fromCharCodes(out);
}
