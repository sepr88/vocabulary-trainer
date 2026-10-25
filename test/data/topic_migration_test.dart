import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vocabulary_trainer/data/trainer_store.dart';
import 'package:vocabulary_trainer/domain/conjugation_session.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('v3 to v4 topic migration preserves both practice histories', () async {
    final directory = await Directory.systemTemp.createTemp(
      'vocabulary-topic-migration-',
    );
    final database = await databaseFactoryFfi.openDatabase(
      p.join(directory.path, 'migration.db'),
    );
    addTearDown(() => directory.delete(recursive: true));
    await _createVersionThreeSchema(database);
    await database.insert('practice_attempts', {
      'attempt_id': 'vocab-attempt',
      'entry_id': 'stable-entry',
      'correct': 1,
      'completed_at': 100,
    });
    await database.insert('conjugation_attempts', {
      'attempt_id': 'conjugation-attempt',
      'conjugation_id': 'stable-conjugation',
      'subject_id': 'ich',
      'language': 'de',
      'level': 'beginner',
      'correct': 0,
      'completed_at': 200,
    });

    await SqliteTrainerStore.upgradeTables(database, 3, 4);
    final store = SqliteTrainerStore(database);
    await store.reconcile(
      VocabularyDataset(
        version: 6,
        entries: [
          VocabularyEntry(
            id: 'stable-entry',
            level: ProficiencyLevel.beginner,
            topic: 'family-and-people',
            german: const LanguageForm(
              primary: 'die Familie',
              accepted: ['die Familie'],
            ),
            portuguese: const LanguageForm(
              primary: 'a família',
              accepted: ['a família'],
            ),
            germanExample: 'Hier ist die Familie.',
            portugueseExample: 'Aqui está a família.',
          ),
        ],
        conjugations: [
          ConjugationEntry(
            id: 'stable-conjugation',
            language: ConjugationLanguage.german,
            level: ProficiencyLevel.beginner,
            topic: 'daily-life-and-home',
            infinitive: 'wohnen',
            tense: 'presentIndicative',
            subjects: const [
              ConjugationSubject(
                id: 'ich',
                primary: 'wohne',
                accepted: ['wohne'],
              ),
            ],
          ),
        ],
      ),
    );

    expect((await store.activeEntries()).single.topic, 'family-and-people');
    expect(
      (await store.activeConjugations()).single.topic,
      'daily-life-and-home',
    );
    expect(
      (await store.vocabularySelectionHistory())['stable-entry']!.attemptCount,
      1,
    );
    expect(
      (await store.conjugationSelectionHistory())[const ConjugationPromptKey(
            'stable-conjugation',
            'ich',
          )]!
          .attemptCount,
      1,
    );
    await store.close();
  });
}

Future<void> _createVersionThreeSchema(Database database) async {
  await database.execute('''
    CREATE TABLE vocabulary_entries (
      id TEXT PRIMARY KEY, level TEXT NOT NULL, de_primary TEXT NOT NULL,
      de_accepted TEXT NOT NULL, pt_primary TEXT NOT NULL,
      pt_accepted TEXT NOT NULL, de_example TEXT NOT NULL,
      pt_example TEXT NOT NULL, active INTEGER NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE practice_attempts (
      attempt_id TEXT PRIMARY KEY, entry_id TEXT NOT NULL,
      correct INTEGER NOT NULL, completed_at INTEGER NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)
  ''');
  await database.execute('''
    CREATE TABLE conjugations (
      id TEXT PRIMARY KEY, language TEXT NOT NULL, level TEXT NOT NULL,
      infinitive TEXT NOT NULL, tense TEXT NOT NULL, subjects TEXT NOT NULL,
      active INTEGER NOT NULL
    )
  ''');
  await database.execute('''
    CREATE TABLE conjugation_attempts (
      attempt_id TEXT PRIMARY KEY, conjugation_id TEXT NOT NULL,
      subject_id TEXT NOT NULL, language TEXT NOT NULL, level TEXT NOT NULL,
      correct INTEGER NOT NULL, completed_at INTEGER NOT NULL
    )
  ''');
}
