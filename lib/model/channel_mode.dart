/// Which experience the shell locked onto for this install.
///
/// - [remote] → returning user previously routed to the WebView (gray).
/// - [local]  → returning user previously routed to the game (white).
/// - [fresh]  → first launch, not yet decided.
enum ChannelMode {
  remote,
  local,
  fresh;

  static ChannelMode decode(String? raw) {
    switch (raw) {
      case 'remote':
        return ChannelMode.remote;
      case 'local':
        return ChannelMode.local;
      default:
        return ChannelMode.fresh;
    }
  }

  String encode() => name;
}
