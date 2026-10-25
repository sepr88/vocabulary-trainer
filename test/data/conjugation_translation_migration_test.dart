import 'dart:convert';
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

  test(
    'v4 to v5 adds translations and reconciliation preserves practice history',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'vocabulary-translation-migration-',
      );
      final database = await databaseFactoryFfi.openDatabase(
        p.join(directory.path, 'migration.db'),
      );
      addTearDown(() => directory.delete(recursive: true));
      await _createVersionFourSchema(database);
      await database.insert('vocabulary_entries', {
        'id': 'stable-entry',
        'level': 'beginner',
        'topic': '',
        'de_primary': 'Haus',
        'de_accepted': jsonEncode(['Haus']),
        'pt_primary': 'casa',
        'pt_accepted': jsonEncode(['casa']),
        'de_example': 'Das Haus ist groß.',
        'pt_example': 'A casa é grande.',
        'active': 1,
      });
      await database.insert('practice_attempts', {
        'attempt_id': 'vocab-attempt',
        'entry_id': 'stable-entry',
        'correct': 1,
        'completed_at': 100,
      });
      await database.insert('conjugations', {
        'id': 'stable-conjugation',
        'language': 'de',
        'level': 'beginner',
        'topic': 'daily-life-and-home',
        'infinitive': 'sein',
        'tense': 'presentIndicative',
        'subjects': jsonEncode([
          for (final subject in ConjugationLanguage.german.subjectIds)
            {
              'id': subject,
              'primary': 'form',
              'accepted': ['form'],
            },
        ]),
        'active': 1,
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
      await database.insert('metadata', {
        'key': 'vocabulary_version',
        'value': '6',
      });

      await SqliteTrainerStore.upgradeTables(database, 4, 5);
      final store = SqliteTrainerStore(database);
      await store.reconcile(
        VocabularyDataset(
          version: 7,
          entries: [
            VocabularyEntry(
              id: 'stable-entry',
              level: ProficiencyLevel.beginner,
              german: const LanguageForm(primary: 'Haus', accepted: ['Haus']),
              portuguese: const LanguageForm(
                primary: 'casa',
                accepted: ['casa'],
              ),
              germanExample: 'Das Haus ist groß.',
              portugueseExample: 'A casa é grande.',
            ),
          ],
          conjugations: [
            ConjugationEntry(
              id: 'stable-conjugation',
              language: ConjugationLanguage.german,
              level: ProficiencyLevel.beginner,
              topic: 'daily-life-and-home',
              infinitive: 'sein',
              translation: 'ser',
              tense: 'presentIndicative',
              subjects: [
                for (final subject in ConjugationLanguage.german.subjectIds)
                  ConjugationSubject(
                    id: subject,
                    primary: 'form',
                    accepted: const ['form'],
                  ),
              ],
            ),
          ],
        ),
      );

      expect((await store.activeConjugations()).single.translation, 'ser');
      expect(
        (await store.conjugationSelectionHistory())[const ConjugationPromptKey(
              'stable-conjugation',
              'ich',
            )]!
            .attemptCount,
        1,
      );
      expect(
        (await store.vocabularySelectionHistory())['stable-entry']!
            .attemptCount,
        1,
      );
      expect((await store.progress()).itemsPracticed, 1);
      await store.close();
    },
  );
}

Future<void> _createVersionFourSchema(Database database) async {
  await database.execute('''
    CREATE TABLE vocabulary_entries (
      id TEXT PRIMARY KEY, level TEXT NOT NULL, topic TEXT NOT NULL DEFAULT '',
      de_primary TEXT NOT NULL, de_accepted TEXT NOT NULL,
      pt_primary TEXT NOT NULL, pt_accepted TEXT NOT NULL,
      de_example TEXT NOT NULL, pt_example TEXT NOT NULL, active INTEGER NOT NULL
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
      topic TEXT NOT NULL DEFAULT '', infinitive TEXT NOT NULL,
      tense TEXT NOT NULL, subjects TEXT NOT NULL, active INTEGER NOT NULL
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
