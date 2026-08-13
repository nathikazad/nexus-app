import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/domain/document/document_audio.dart';

void main() {
  test('parses block timing and maps live playback positions', () {
    final manifest = DocumentAudioManifest.tryParse(<String, Object>{
      'duration_ms': 2000,
      'blocks': <Object>[
        <String, Object>{
          'block_index': 0,
          'block_key': 'paragraph:first',
          'start_ms': 0,
          'end_ms': 900,
        },
        <String, Object>{
          'block_index': 1,
          'block_key': 'paragraph:second',
          'start_ms': 1100,
          'end_ms': 2000,
        },
      ],
    });

    expect(manifest, isNotNull);
    expect(
      manifest!.blockAt(const Duration(milliseconds: 400))?.blockKey,
      'paragraph:first',
    );
    expect(
      manifest.blockForKey('paragraph:second')?.start,
      const Duration(milliseconds: 1100),
    );
    expect(manifest.blockAt(const Duration(milliseconds: 1000)), isNull);
  });

  test('rejects malformed manifests', () {
    expect(DocumentAudioManifest.tryParse(const <String, Object>{}), isNull);
    expect(
      DocumentAudioManifest.tryParse(<String, Object>{
        'duration_ms': 10,
        'blocks': <Object>[
          <String, Object>{'block_key': 'missing timing'},
        ],
      }),
      isNull,
    );
  });
}
