import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocabulary_trainer/data/trainer_store.dart';
import 'package:vocabulary_trainer/domain/practice_session.dart';

import '../support/fixtures.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  Future<({SqliteTrainerStore store, Database database})>
  openMemoryStore() async {
    final database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
    );
    await SqliteTrainerStore.createTables(database);
    return (store: SqliteTrainerStore(database), database: database);
  }

  test(
    'initializes, persists attempts and deduplicates completed items',
    () async {
      final opened = await openMemoryStore();
      final store = opened.store;
      await store.reconcile(sampleDataset());

      expect(await store.activeEntries(), hasLength(1));
      expect(await store.activeVocabularyVersion(), 1);
      expect(await store.practiceHistory(), isEmpty);
      expect(
        await store.recordAttempt(
          attemptId: 'session:0',
          entryId: 'sample-1',
          correct: true,
        ),
        isTrue,
      );
      expect(await store.practiceHistory(), {
        'sample-1': const PracticeHistory(
          completedAttempts: 1,
          incorrectAttempts: 0,
        ),
      });
      expect(
        await store.recordAttempt(
          attemptId: 'session:0',
          entryId: 'sample-1',
          correct: false,
        ),
        isFalse,
      );
      expect(
        await store.recordAttempt(
          attemptId: 'session:1',
          entryId: 'sample-1',
          correct: false,
        ),
        isTrue,
      );
      final progress = await store.progress();
      expect(progress.itemsPracticed, 2);
      expect(progress.correctAnswers, 1);
      expect(progress.incorrectAnswers, 1);
      expect(progress.uniqueEntriesCorrect, 1);
      expect(progress.uniqueEntriesIncorrect, 1);
      expect(await store.practiceHistory(), {
        'sample-1': const PracticeHistory(
          completedAttempts: 2,
          incorrectAttempts: 1,
        ),
      });
      await store.close();
    },
  );

  test(
    'reconciles changed entries and retires removed entries preserving history',
    () async {
      final opened = await openMemoryStore();
      final store = opened.store;
      await store.reconcile(
        sampleDataset(
          entries: [
            sampleEntry(id: 'changed'),
            sampleEntry(id: 'retired'),
          ],
        ),
      );
      await store.recordAttempt(
        attemptId: 'old-session:0',
        entryId: 'changed',
        correct: true,
      );
      await store.recordAttempt(
        attemptId: 'old-session:1',
        entryId: 'retired',
        correct: false,
      );
      await store.reconcile(
        sampleDataset(
          version: 2,
          entries: [
            sampleEntry(id: 'changed', german: 'das Gebäude'),
            sampleEntry(id: 'new'),
          ],
        ),
      );

      expect(await store.activeVocabularyVersion(), 2);
      final entries = await store.activeEntries();
      expect(entries.map((entry) => entry.id).toSet(), {'changed', 'new'});
      expect(
        entries.singleWhere((entry) => entry.id == 'changed').german.primary,
        'das Gebäude',
      );
      final progress = await store.progress();
      expect(progress.activeVocabularyCount, 2);
      expect(progress.itemsPracticed, 2);
      expect(progress.correctAnswers, 1);
      expect(progress.incorrectAnswers, 1);
      expect(progress.uniqueEntriesCorrect, 1);
      expect(progress.uniqueEntriesIncorrect, 0);
      await store.close();
    },
  );

  test('same vocabulary version does not reconcile changed contents', () async {
    final opened = await openMemoryStore();
    final store = opened.store;
    await store.reconcile(sampleDataset());
    await store.reconcile(
      sampleDataset(entries: [sampleEntry(german: 'changed content')]),
    );

    expect((await store.activeEntries()).single.german.primary, 'das Haus');
    await store.close();
  });

  test(
    'new vocabulary version refreshes accented examples and keeps history',
    () async {
      final opened = await openMemoryStore();
      final store = opened.store;
      await store.reconcile(
        sampleDataset(
          version: 3,
          entries: [
            sampleEntry(
              germanExample: 'Die T\uFFFD ist offen.',
              portugueseExample: 'A porta est\uFFFD aberta.',
            ),
          ],
        ),
      );
      await store.recordAttempt(
        attemptId: 'accent-session:0',
        entryId: 'sample-1',
        correct: true,
      );

      await store.reconcile(
        sampleDataset(
          version: 4,
          entries: [
            sampleEntry(
              germanExample: 'Die T\u00FCr ist offen.',
              portugueseExample: 'A porta est\u00E1 aberta.',
            ),
          ],
        ),
      );

      final entry = (await store.activeEntries()).single;
      expect(entry.germanExample, 'Die T\u00FCr ist offen.');
      expect(entry.portugueseExample, 'A porta est\u00E1 aberta.');
      expect((await store.progress()).correctAnswers, 1);
      expect(await store.activeVocabularyVersion(), 4);
      await store.close();
    },
  );

  test(
    'migrates prior vocabulary rows and fills their examples on reconcile',
    () async {
      final database = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
      );
      await database.execute('''
      CREATE TABLE vocabulary_entries (
        id TEXT PRIMARY KEY,
        level TEXT NOT NULL,
        de_primary TEXT NOT NULL,
        de_accepted TEXT NOT NULL,
        pt_primary TEXT NOT NULL,
        pt_accepted TEXT NOT NULL,
        active INTEGER NOT NULL
      )
    ''');
      await database.execute('''
      CREATE TABLE practice_attempts (
        attempt_id TEXT PRIMARY KEY,
        entry_id TEXT NOT NULL,
        correct INTEGER NOT NULL,
        completed_at INTEGER NOT NULL
      )
    ''');
      await database.execute('''
      CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)
    ''');
      await database.insert('vocabulary_entries', {
        'id': 'sample-1',
        'level': 'beginner',
        'de_primary': 'das Haus',
        'de_accepted': '["das Haus","Haus"]',
        'pt_primary': 'a casa',
        'pt_accepted': '["a casa","casa"]',
        'active': 1,
      });
      await database.insert('practice_attempts', {
        'attempt_id': 'legacy-session:0',
        'entry_id': 'sample-1',
        'correct': 1,
        'completed_at': 1,
      });
      await database.insert('metadata', {
        'key': 'vocabulary_version',
        'value': '3',
      });

      await SqliteTrainerStore.upgradeTables(database, 1, 2);
      final store = SqliteTrainerStore(database);
      await store.reconcile(sampleDataset(version: 4));

      final entry = (await store.activeEntries()).single;
      expect(entry.germanExample, 'Das Haus ist wichtig.');
      expect(entry.portugueseExample, 'A casa é importante.');
      expect((await store.progress()).itemsPracticed, 1);
      expect(await store.activeVocabularyVersion(), 4);
      await store.close();
    },
  );

  test('failed transaction leaves the existing active store intact', () async {
    final opened = await openMemoryStore();
    final store = opened.store;
    await store.reconcile(sampleDataset());
    await opened.database.execute('''
      CREATE TRIGGER fail_entry_update BEFORE UPDATE ON vocabulary_entries
      BEGIN SELECT RAISE(ABORT, 'forced update failure'); END
    ''');

    await expectLater(
      store.reconcile(
        sampleDataset(version: 2, entries: [sampleEntry(german: 'changed')]),
      ),
      throwsA(anything),
    );
    expect((await store.activeEntries()).single.german.primary, 'das Haus');
    await store.close();
  });

  test('practice progress is available after reopening the database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vocabulary-trainer-test-',
    );
    final databasePath = p.join(directory.path, 'persisted.db');
    try {
      var database = await databaseFactoryFfi.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) => SqliteTrainerStore.createTables(db),
        ),
      );
      var store = SqliteTrainerStore(database);
      await store.reconcile(sampleDataset());
      await store.recordAttempt(
        attemptId: 'persisted-session:0',
        entryId: 'sample-1',
        correct: true,
      );
      await store.close();

      database = await databaseFactoryFfi.openDatabase(databasePath);
      store = SqliteTrainerStore(database);
      final progress = await store.progress();
      expect(progress.itemsPracticed, 1);
      expect(progress.correctAnswers, 1);
      expect(await store.practiceHistory(), {
        'sample-1': const PracticeHistory(
          completedAttempts: 1,
          incorrectAttempts: 0,
        ),
      });
      await store.close();
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
