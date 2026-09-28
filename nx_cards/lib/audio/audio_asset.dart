import 'package:nx_cards/browser/browser.dart';

final class AudioAsset {
  const AudioAsset(this.url, this.sha256, this.bytes);
  final String url;
  final String sha256;
  final int? bytes;

  factory AudioAsset.fromUrl(String url) {
    final name = Uri.parse(url).queryParameters['name'] ?? '';
    final match = RegExp(r'^\d+-([a-f0-9]{64})\.mp3$').firstMatch(name);
    if (match == null) {
      throw const FormatException('Audio needs updated sync metadata');
    }
    return AudioAsset(url, match.group(1)!, null);
  }

  void validate() {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        (bytes != null && bytes! <= 0)) {
      throw const FormatException('Invalid audio metadata');
    }
    if (AudioAsset.fromUrl(url).sha256 != sha256) {
      throw const FormatException('Audio URL does not match its hash');
    }
  }

  static Iterable<AudioAsset> forContent(LanguageCardContent content) sync* {
    AudioAsset asset(String url, String? hash, int? bytes) =>
        AudioAsset(url, hash ?? '', bytes);
    if (content.audioUrl case final url? when url.isNotEmpty) {
      yield asset(url, content.audioSha256, content.audioBytes);
    }
    for (final example in content.examples) {
      if (example.audioUrl case final url? when url.isNotEmpty) {
        yield asset(url, example.audioSha256, example.audioBytes);
      }
    }
  }
}
