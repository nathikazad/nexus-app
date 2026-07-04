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

  test('unpublished edit stores hash but does not mark dirty', () {
    final updated = DocumentPublishState.disabled().withCurrentContent({
      'format': 'appflowy_document',
      'document': {'type': 'page', 'children': []},
    });

    expect(updated.enabled, false);
    expect(updated.dirty, false);
    expect(updated.contentHash, startsWith('sha256:'));
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
