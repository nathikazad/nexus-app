import 'package:flutter_test/flutter_test.dart';
import 'package:nx_notes/domain/document/document_publish.dart';

void main() {
  test('appFlowyContentHash ignores view state and sorts object keys', () {
    final first = appFlowyContentHash({
      'format': 'appflowy_document',
      'document': {
        'children': [
          {
            'data': {
              'delta': [
                {'insert': 'Hello'},
              ],
            },
            'type': 'paragraph',
          },
        ],
        'type': 'page',
      },
      'view_state': {'scroll': 10},
    });
    final second = appFlowyContentHash({
      'view_state': {'scroll': 90},
      'document': {
        'type': 'page',
        'children': [
          {
            'type': 'paragraph',
            'data': {
              'delta': [
                {'insert': 'Hello'},
              ],
            },
          },
        ],
      },
      'format': 'appflowy_document',
    });

    expect(first, second);
    expect(first, startsWith('sha256:'));
  });

  test('appFlowyContentHash includes sorted Topic tags only', () {
    final baseDocument = {
      'format': 'appflowy_document',
      'document': {'type': 'page', 'children': []},
    };
    final first = appFlowyContentHash(
      baseDocument,
      tagsBySystem: const {
        'Topic': ['Spiritual', 'Business', 'Spiritual'],
        'Status': ['Draft'],
      },
    );
    final second = appFlowyContentHash(
      baseDocument,
      tagsBySystem: const {
        'Topic': ['Business', 'Spiritual'],
        'Status': ['Published'],
        'Area': ['Private'],
      },
    );
    final third = appFlowyContentHash(
      baseDocument,
      tagsBySystem: const {
        'Topic': ['Business'],
      },
    );

    expect(first, second);
    expect(first, isNot(third));
  });

  test('published edit marks state dirty when content hash changes', () {
    const state = DocumentPublishState(
      enabled: true,
      dirty: false,
      lastPublishedHash: 'sha256:old',
      status: 'published',
    );

    final updated = state.withCurrentContent({
      'format': 'appflowy_document',
      'document': {'type': 'page', 'children': []},
    });

    expect(updated.dirty, true);
    expect(updated.status, 'pending');
    expect(updated.contentHash, isNot('sha256:old'));
  });

  test('published topic change marks state dirty', () {
    const jsonDocument = {
      'format': 'appflowy_document',
      'document': {'type': 'page', 'children': []},
    };
    final oldHash = appFlowyContentHash(
      jsonDocument,
      tagsBySystem: const {
        'Topic': ['Business'],
      },
    );
    final updated = DocumentPublishState(
      enabled: true,
      dirty: false,
      contentHash: oldHash,
      lastPublishedHash: oldHash,
      status: 'published',
    ).withCurrentContent(
      jsonDocument,
      tagsBySystem: const {
        'Topic': ['Spiritual'],
      },
    );

    expect(updated.dirty, true);
    expect(updated.status, 'pending');
    expect(updated.contentHash, isNot(oldHash));
  });

  test('published status-only tag change does not mark state dirty', () {
    const jsonDocument = {
      'format': 'appflowy_document',
      'document': {'type': 'page', 'children': []},
    };
    final oldHash = appFlowyContentHash(
      jsonDocument,
      tagsBySystem: const {
        'Topic': ['Business'],
        'Status': ['Draft'],
      },
    );
    final updated = DocumentPublishState(
      enabled: true,
      dirty: false,
      contentHash: oldHash,
      lastPublishedHash: oldHash,
      status: 'published',
    ).withCurrentContent(
      jsonDocument,
      tagsBySystem: const {
        'Topic': ['Business'],
        'Status': ['Published'],
      },
    );

    expect(updated.dirty, false);
    expect(updated.status, 'published');
    expect(updated.contentHash, oldHash);
  });

  test('unpublished edit stores hash but does not mark dirty', () {
    final updated = DocumentPublishState.disabled().withCurrentContent({
      'format': 'appflowy_document',
      'document': {'type': 'page', 'children': []},
    });

    expect(updated.enabled, false);
    expect(updated.dirty, false);
    expect(updated.contentHash, startsWith('sha256:'));
  });

  test('publish enable computes hash from content and Topic tags', () {
    const jsonDocument = {
      'format': 'appflowy_document',
      'document': {'type': 'page', 'children': []},
    };
    final expectedHash = appFlowyContentHash(
      jsonDocument,
      tagsBySystem: const {
        'Topic': ['Spiritual'],
      },
    );

    final enabled = DocumentPublishState.disabled().enable(
      jsonDocument: jsonDocument,
      tagsBySystem: const {
        'Topic': ['Spiritual'],
        'Status': ['Draft'],
      },
      publishedAt: '2026-07-04T00:00:00.000Z',
    );

    expect(enabled.enabled, true);
    expect(enabled.dirty, true);
    expect(enabled.contentHash, expectedHash);
  });

  test('pending unpublish stays dirty until mirror activation clears it', () {
    const state = DocumentPublishState(
      enabled: false,
      dirty: true,
      lastPublishedHash: 'sha256:old',
      status: 'pending',
    );

    final updated = state.withCurrentContent({
      'format': 'appflowy_document',
      'document': {'type': 'page', 'children': []},
    });

    expect(updated.enabled, false);
    expect(updated.dirty, true);
    expect(updated.status, 'pending');
  });

  test('activated hash clears dirty safely', () {
    const state = DocumentPublishState(
      enabled: true,
      dirty: true,
      contentHash: 'sha256:abc',
      status: 'pending',
    );

    final activated = state.markActivated(
      activatedHash: 'sha256:abc',
      publishedAt: '2026-07-04T00:00:00.000Z',
    );

    expect(activated.dirty, false);
    expect(activated.lastPublishedHash, 'sha256:abc');
    expect(activated.status, 'published');
  });
}
