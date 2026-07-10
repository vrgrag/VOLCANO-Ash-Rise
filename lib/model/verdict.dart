/// Parsed reply from the config (gate) endpoint.
///
/// Wire format is `{ ok, url, expires, message }`; the fields are renamed
/// here but the JSON keys are mapped verbatim so the backend contract is
/// preserved exactly.
class Verdict {
  const Verdict({
    required this.allowed,
    this.link,
    this.note,
    this.ttl,
  });

  /// Backend `ok` — true means show the WebView with [link].
  final bool allowed;

  /// Backend `url` — the content URL to display.
  final String? link;

  /// Backend `message` — diagnostic note.
  final String? note;

  /// Backend `expires` — unix seconds after which [link] should be refreshed.
  final int? ttl;

  factory Verdict.fromMap(Map<String, dynamic> map) {
    return Verdict(
      allowed: map['ok'] as bool? ?? false,
      link: map['url'] as String?,
      note: map['message'] as String?,
      ttl: map['expires'] as int?,
    );
  }

  factory Verdict.denied(String note) => Verdict(allowed: false, note: note);

  bool get hasLink => link != null && link!.isNotEmpty;
}
