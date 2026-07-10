// ignore_for_file: avoid_print
// ============================================================
// PACK SECRETS — encodes plaintext secrets into scrambled arrays
// ============================================================
// Mirrors lib/cipher/scrambler.dart byte-for-byte. Run with:
//   dart run tool/pack_secrets.dart
// then paste the printed arrays into lib/wire/packed_secrets.dart.
//
// Always run through `dart run` (native 64-bit ints). A PowerShell
// port overflows at 32 bits and corrupts the output bytes.
//
// Keep [saltPhrase] / [ringSize] identical to scrambler.dart.
// ============================================================

const String saltPhrase = 'pV7#kLm2qXr8';
const int ringSize = 29;

List<int> buildRing() {
  int hash = 0x811C9DC5;
  for (final int c in saltPhrase.codeUnits) {
    hash = (hash ^ c) & 0xFFFFFFFF;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  int state = hash == 0 ? 0x9E3779B9 : hash;
  final List<int> ring = List<int>.filled(ringSize, 0);
  for (int i = 0; i < ringSize; i++) {
    state ^= (state << 13) & 0xFFFFFFFF;
    state ^= state >> 17;
    state ^= (state << 5) & 0xFFFFFFFF;
    state &= 0xFFFFFFFF;
    ring[i] = (state >> 16) & 0xFF;
  }
  return ring;
}

final List<int> ring = buildRing();

List<int> pack(String plain) {
  final List<int> bytes = plain.codeUnits;
  final List<int> out = List<int>.filled(bytes.length, 0);
  for (int i = 0; i < bytes.length; i++) {
    out[i] = (bytes[i] ^ ring[i % ringSize] ^ ((i * 31 + 17) & 0xFF)) & 0xFF;
  }
  return out;
}

void emit(String label, String plain) {
  if (plain.isEmpty) {
    print('// $label — (empty, fill in later)');
    print('const <int>[],\n');
    return;
  }
  final List<int> packed = pack(plain);
  print('// $label  <= "$plain"');
  print('const <int>[${packed.join(', ')}],\n');
}

void main() {
  // ── Known now ──
  const String configEndpoint = 'https://ashhrise.com/config.php';
  const String gcdBase = 'https://gcdsdk.appsflyer.com/install_data/v4.0/';
  const String chromeVersion = '149.0.7742.118';
  const String webkitVersion = '537.36';

  // ── Provided by the manager (AppsFlyer + Firebase) ──
  const String attributionKey = 'Y8jcHTxWmW6rvLRCuwNZMA'; // AppsFlyer Dev Key
  const String messagingSender = '629072335129'; // Firebase project number

  print('=== Ash Rise pack_secrets ===\n');
  emit('configEndpoint', configEndpoint);
  emit('gcdBase', gcdBase);
  emit('chromeVersion', chromeVersion);
  emit('webkitVersion', webkitVersion);
  emit('attributionKey', attributionKey);
  emit('messagingSender', messagingSender);
}
