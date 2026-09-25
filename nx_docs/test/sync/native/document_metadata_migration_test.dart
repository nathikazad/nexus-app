import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nx_docs/sync/native/notes_database.dart';
import 'package:nx_offline/src/storage/content_files_native.dart';

void main() {
  for (final fileBacked in [false, true]) {
    test(
      'v7 removes metadata and preserves content, fileBacked=$fileBacked',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'docs-metadata-',
        );
        final file = File('${directory.path}/notes.sqlite');
        final files = DirectoryContentFiles(
          Directory('${directory.path}/content'),
        );
        var database = NotesDatabase(
          NativeDatabase(file),
          migrationFiles: files,
        );
        final content = jsonEncode({
          'title': 'Keep this title',
          'document': 'Keep all the text',
          'status': 'Draft',
          'tags_by_system': {
            'Status': ['Draft'],
            'Topic': ['Ideas'],
          },
          'publish': {'status': 'published'},
        });
        final stored = fileBacked
            ? await files.write('documents', 'one', content)
            : content;
        await database.customStatement(
          'INSERT INTO local_documents (local_id,account_key,document_json,local_updated_at,sync_state) VALUES (?,?,?,?,?)',
          ['one', 'account', stored, 1, 'pending'],
        );
        await database.customStatement(
          'INSERT INTO sync_outbox (operation_id,account_key,aggregate_id,operation_type,payload_json,status,created_at) VALUES (?,?,?,?,?,?,?)',
          [
            'op',
            'account',
            'one',
            'update',
            jsonEncode({'body_ref': stored, 'document_id': 1}),
            'queued',
            1,
          ],
        );
        await database.customStatement('PRAGMA user_version = 6');
        await database.close();
        database = NotesDatabase(NativeDatabase(file), migrationFiles: files);
        final row = await database
            .customSelect('SELECT document_json FROM local_documents')
            .getSingle();
        final migrated =
            jsonDecode(await files.read(row.read<String>('document_json')))
                as Map;
        expect(migrated.containsKey('status'), isFalse);
        expect(migrated['tags_by_system'], {
          'Topic': ['Ideas'],
        });
        expect(migrated['document'], 'Keep all the text');
        expect(migrated['title'], 'Keep this title');
        expect(migrated['publish'], {'status': 'published'});
        final queued = await database
            .customSelect('SELECT payload_json,status FROM sync_outbox')
            .getSingle();
        expect(queued.read<String>('status'), 'queued');
        final payload = jsonDecode(queued.read<String>('payload_json')) as Map;
        final queuedDocument = jsonDecode(
          await files.read(payload['body_ref'] as String),
        );
        expect(queuedDocument, migrated);
        expect(payload['document_id'], 1);
        await database.close();
        database = NotesDatabase(NativeDatabase(file), migrationFiles: files);
        expect(
          (await database
                  .customSelect('SELECT count(*) AS n FROM local_documents')
                  .getSingle())
              .read<int>('n'),
          1,
        );
        await database.close();
        await directory.delete(recursive: true);
      },
    );
  }
}
