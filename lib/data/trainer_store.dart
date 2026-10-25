import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/adaptive_selection.dart';
import '../domain/conjugation_session.dart';
import '../models/conjugation.dart';
import '../models/vocabulary.dart';

class ConjugationProgressKey {
  const ConjugationProgressKey(this.language, this.level);

  final ConjugationLanguage language;
  final ProficiencyLevel level;

  @override
  bool operator ==(Object other) =>
      other is ConjugationProgressKey &&
      other.language == language &&
      other.level == level;

  @override
  int get hashCode => Object.hash(language, level);
}

class ConjugationProgress {
  const ConjugationProgress({
    required this.promptsPracticed,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.uniquePromptsCorrect,
    required this.uniquePromptsIncorrect,
  });

  final int promptsPracticed;
  final int correctAnswers;
  final int incorrectAnswers;
  final int uniquePromptsCorrect;
  final int uniquePromptsIncorrect;

  double get accuracyPercent =>
      promptsPracticed == 0 ? 0 : correctAnswers * 100 / promptsPracticed;
}

class ProgressSnapshot {
  const ProgressSnapshot({
    required this.activeVocabularyCount,
    required this.itemsPracticed,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.uniqueEntriesCorrect,
    required this.uniqueEntriesIncorrect,
  });

  final int activeVocabularyCount;
  final int itemsPracticed;
  final int correctAnswers;
  final int incorrectAnswers;
  final int uniqueEntriesCorrect;
  final int uniqueEntriesIncorrect;
}

abstract interface class TrainerStore {
  Future<void> reconcile(VocabularyDataset dataset);
  Future<int> activeVocabularyVersion();
  Future<List<VocabularyEntry>> activeEntries();
  Future<Map<String, SelectionHistory>> vocabularySelectionHistory();
  Future<Map<ConjugationPromptKey, SelectionHistory>>
  conjugationSelectionHistory();
  Future<ProgressSnapshot> progress();
  Future<List<ConjugationEntry>> activeConjugations();
  Future<Map<ConjugationProgressKey, ConjugationProgress>>
  conjugationProgress();
  Future<bool> recordAttempt({
    required String attemptId,
    required String entryId,
    required bool correct,
  });
  Future<bool> recordConjugationAttempt({
    required String attemptId,
    required String conjugationId,
    required String subjectId,
    required bool correct,
  });
  Future<void> close();
}

class SqliteTrainerStore implements TrainerStore {
  SqliteTrainerStore(this._database);

  final Database _database;

  static Future<SqliteTrainerStore> open() async {
    final directory = await getDatabasesPath();
    final database = await openDatabase(
      p.join(directory, 'vocabulary_trainer.db'),
      version: 4,
      onCreate: (db, version) => createTables(db),
      onUpgrade: (db, oldVersion, newVersion) =>
          upgradeTables(db, oldVersion, newVersion),
    );
    return SqliteTrainerStore(database);
  }

  static Future<void> createTables(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE vocabulary_entries (
        id TEXT PRIMARY KEY,
        level TEXT NOT NULL,
        topic TEXT NOT NULL DEFAULT '',
        de_primary TEXT NOT NULL,
        de_accepted TEXT NOT NULL,
        pt_primary TEXT NOT NULL,
        pt_accepted TEXT NOT NULL,
        de_example TEXT NOT NULL,
        pt_example TEXT NOT NULL,
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
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await _createConjugationTables(database);
  }

  static Future<void> upgradeTables(
    DatabaseExecutor database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2 && newVersion >= 2) {
      await database.execute(
        "ALTER TABLE vocabulary_entries ADD COLUMN de_example TEXT NOT NULL DEFAULT ''",
      );
      await database.execute(
        "ALTER TABLE vocabulary_entries ADD COLUMN pt_example TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 3 && newVersion >= 3) {
      await _createConjugationTables(database);
    }
    if (oldVersion < 4 && newVersion >= 4) {
      await database.execute(
        "ALTER TABLE vocabulary_entries ADD COLUMN topic TEXT NOT NULL DEFAULT ''",
      );
      await database.execute(
        "ALTER TABLE conjugations ADD COLUMN topic TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  static Future<void> _createConjugationTables(
    DatabaseExecutor database,
  ) async {
    await database.execute('''
      CREATE TABLE conjugations (
        id TEXT PRIMARY KEY,
        language TEXT NOT NULL,
        level TEXT NOT NULL,
        topic TEXT NOT NULL DEFAULT '',
        infinitive TEXT NOT NULL,
        tense TEXT NOT NULL,
        subjects TEXT NOT NULL,
        active INTEGER NOT NULL
      )
    ''');
    await database.execute('''
      CREATE TABLE conjugation_attempts (
        attempt_id TEXT PRIMARY KEY,
        conjugation_id TEXT NOT NULL,
        subject_id TEXT NOT NULL,
        language TEXT NOT NULL,
        level TEXT NOT NULL,
        correct INTEGER NOT NULL,
        completed_at INTEGER NOT NULL
      )
    ''');
  }

  @override
  Future<void> reconcile(VocabularyDataset dataset) async {
    await _database.transaction((transaction) async {
      final installedVersion = await transaction.query(
        'metadata',
        columns: const ['value'],
        where: 'key = ?',
        whereArgs: const ['vocabulary_version'],
        limit: 1,
      );
      if (installedVersion.isNotEmpty &&
          int.parse(installedVersion.single['value']! as String) ==
              dataset.version) {
        return;
      }

      final vocabularyColumns = await transaction.rawQuery(
        'PRAGMA table_info(vocabulary_entries)',
      );
      final hasVocabularyTopics = vocabularyColumns.any(
        (column) => column['name'] == 'topic',
      );
      final conjugationColumns = await transaction.rawQuery(
        'PRAGMA table_info(conjugations)',
      );
      final hasConjugationTopics = conjugationColumns.any(
        (column) => column['name'] == 'topic',
      );

      await transaction.update('vocabulary_entries', {'active': 0});
      for (final entry in dataset.entries) {
        final values = _entryValues(entry)..['active'] = 1;
        if (!hasVocabularyTopics) values.remove('topic');
        await transaction.insert(
          'vocabulary_entries',
          values,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await transaction.update(
          'vocabulary_entries',
          values,
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      }
      await transaction.update('conjugations', {'active': 0});
      for (final entry in dataset.conjugations) {
        final values = _conjugationValues(entry)..['active'] = 1;
        if (!hasConjugationTopics) values.remove('topic');
        await transaction.insert(
          'conjugations',
          values,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await transaction.update(
          'conjugations',
          values,
          where: 'id = ?',
          whereArgs: [entry.id],
        );
      }
      await transaction.insert('metadata', {
        'key': 'vocabulary_version',
        'value': '${dataset.version}',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  @override
  Future<int> activeVocabularyVersion() async {
    final rows = await _database.query(
      'metadata',
      columns: const ['value'],
      where: 'key = ?',
      whereArgs: const ['vocabulary_version'],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError(
        'The active vocabulary version has not been initialized.',
      );
    }
    final value = rows.single['value'];
    final version = value is String ? int.tryParse(value) : null;
    if (version == null || version <= 0) {
      throw StateError('The active vocabulary version is invalid.');
    }
    return version;
  }

  @override
  Future<List<VocabularyEntry>> activeEntries() async {
    final rows = await _database.query(
      'vocabulary_entries',
      where: 'active = 1',
      orderBy: 'id',
    );
    return List.unmodifiable(rows.map(_entryFromRow));
  }

  @override
  Future<Map<String, SelectionHistory>> vocabularySelectionHistory() async {
    final rows = await _database.query(
      'practice_attempts',
      columns: const ['entry_id', 'correct', 'completed_at'],
      orderBy: 'completed_at DESC, rowid DESC',
    );
    final attemptsByEntry = <String, List<SelectionAttempt>>{};
    for (final row in rows) {
      attemptsByEntry
          .putIfAbsent(row['entry_id']! as String, () => [])
          .add(
            SelectionAttempt(
              correct: row['correct']! as int == 1,
              completedAt: DateTime.fromMillisecondsSinceEpoch(
                row['completed_at']! as int,
              ),
            ),
          );
    }
    return Map.unmodifiable({
      for (final entry in attemptsByEntry.entries)
        entry.key: SelectionHistory.fromAttempts(entry.value),
    });
  }

  @override
  Future<Map<ConjugationPromptKey, SelectionHistory>>
  conjugationSelectionHistory() async {
    final rows = await _database.query(
      'conjugation_attempts',
      columns: const [
        'conjugation_id',
        'subject_id',
        'correct',
        'completed_at',
      ],
      orderBy: 'completed_at DESC, rowid DESC',
    );
    final attemptsByPrompt = <ConjugationPromptKey, List<SelectionAttempt>>{};
    for (final row in rows) {
      final key = ConjugationPromptKey(
        row['conjugation_id']! as String,
        row['subject_id']! as String,
      );
      attemptsByPrompt
          .putIfAbsent(key, () => [])
          .add(
            SelectionAttempt(
              correct: row['correct']! as int == 1,
              completedAt: DateTime.fromMillisecondsSinceEpoch(
                row['completed_at']! as int,
              ),
            ),
          );
    }
    return Map.unmodifiable({
      for (final entry in attemptsByPrompt.entries)
        entry.key: SelectionHistory.fromAttempts(entry.value),
    });
  }

  @override
  Future<ProgressSnapshot> progress() async {
    final activeCount =
        Sqflite.firstIntValue(
          await _database.rawQuery(
            'SELECT COUNT(*) FROM vocabulary_entries WHERE active = 1',
          ),
        ) ??
        0;
    final totals = (await _database.rawQuery('''
      SELECT
        COUNT(*) AS items,
        COALESCE(SUM(correct), 0) AS correct,
        COALESCE(SUM(1 - correct), 0) AS incorrect
      FROM practice_attempts
    ''')).single;
    final unique = (await _database.rawQuery('''
      SELECT
        COUNT(DISTINCT CASE WHEN a.correct = 1 THEN a.entry_id END) AS correct,
        COUNT(DISTINCT CASE WHEN a.correct = 0 THEN a.entry_id END) AS incorrect
      FROM practice_attempts a
      INNER JOIN vocabulary_entries v ON v.id = a.entry_id
      WHERE v.active = 1
    ''')).single;
    return ProgressSnapshot(
      activeVocabularyCount: activeCount,
      itemsPracticed: totals['items']! as int,
      correctAnswers: totals['correct']! as int,
      incorrectAnswers: totals['incorrect']! as int,
      uniqueEntriesCorrect: unique['correct']! as int,
      uniqueEntriesIncorrect: unique['incorrect']! as int,
    );
  }

  @override
  Future<List<ConjugationEntry>> activeConjugations() async {
    final rows = await _database.query(
      'conjugations',
      where: 'active = 1',
      orderBy: 'id',
    );
    return List.unmodifiable(rows.map(_conjugationFromRow));
  }

  @override
  Future<Map<ConjugationProgressKey, ConjugationProgress>>
  conjugationProgress() async {
    final values = <ConjugationProgressKey, _MutableConjugationProgress>{
      for (final language in ConjugationLanguage.values)
        for (final level in ProficiencyLevel.values)
          ConjugationProgressKey(language, level):
              _MutableConjugationProgress(),
    };
    final uniquePrompts =
        <ConjugationProgressKey, Map<(String, String), Set<bool>>>{};
    final rows = await _database.query(
      'conjugation_attempts',
      columns: const [
        'conjugation_id',
        'subject_id',
        'language',
        'level',
        'correct',
      ],
    );
    for (final row in rows) {
      final key = ConjugationProgressKey(
        ConjugationLanguage.fromId(row['language']! as String, 'language'),
        ProficiencyLevel.values.byName(row['level']! as String),
      );
      final progress = values[key];
      if (progress == null) {
        throw StateError('Stored conjugation progress has an invalid group.');
      }
      final correct = row['correct']! as int == 1;
      progress.promptsPracticed++;
      if (correct) {
        progress.correctAnswers++;
      } else {
        progress.incorrectAnswers++;
      }
      final promptId = (
        row['conjugation_id']! as String,
        row['subject_id']! as String,
      );
      uniquePrompts
          .putIfAbsent(key, () => {})
          .putIfAbsent(promptId, () => <bool>{})
          .add(correct);
    }
    return Map.unmodifiable({
      for (final entry in values.entries)
        entry.key: ConjugationProgress(
          promptsPracticed: entry.value.promptsPracticed,
          correctAnswers: entry.value.correctAnswers,
          incorrectAnswers: entry.value.incorrectAnswers,
          uniquePromptsCorrect:
              uniquePrompts[entry.key]?.values
                  .where((results) => results.contains(true))
                  .length ??
              0,
          uniquePromptsIncorrect:
              uniquePrompts[entry.key]?.values
                  .where((results) => results.contains(false))
                  .length ??
              0,
        ),
    });
  }

  @override
  Future<bool> recordAttempt({
    required String attemptId,
    required String entryId,
    required bool correct,
  }) async {
    return _database.transaction((transaction) async {
      final existing = await transaction.query(
        'practice_attempts',
        columns: const ['attempt_id'],
        where: 'attempt_id = ?',
        whereArgs: [attemptId],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;
      final entry = await transaction.query(
        'vocabulary_entries',
        columns: const ['id'],
        where: 'id = ? AND active = 1',
        whereArgs: [entryId],
        limit: 1,
      );
      if (entry.isEmpty) {
        throw StateError(
          'Cannot record an attempt for inactive entry $entryId.',
        );
      }
      await transaction.insert('practice_attempts', {
        'attempt_id': attemptId,
        'entry_id': entryId,
        'correct': correct ? 1 : 0,
        'completed_at': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    });
  }

  @override
  Future<bool> recordConjugationAttempt({
    required String attemptId,
    required String conjugationId,
    required String subjectId,
    required bool correct,
  }) async {
    return _database.transaction((transaction) async {
      final existing = await transaction.query(
        'conjugation_attempts',
        columns: const ['attempt_id'],
        where: 'attempt_id = ?',
        whereArgs: [attemptId],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;
      final conjugations = await transaction.query(
        'conjugations',
        columns: const ['language', 'level', 'subjects'],
        where: 'id = ? AND active = 1',
        whereArgs: [conjugationId],
        limit: 1,
      );
      if (conjugations.isEmpty) {
        throw StateError(
          'Cannot record an attempt for inactive conjugation $conjugationId.',
        );
      }
      final subjects = decodeConjugationSubjects(
        conjugations.single['subjects']! as String,
      );
      if (!subjects.any((subject) => subject.id == subjectId)) {
        throw StateError(
          'Cannot record an attempt for unknown subject $subjectId.',
        );
      }
      await transaction.insert('conjugation_attempts', {
        'attempt_id': attemptId,
        'conjugation_id': conjugationId,
        'subject_id': subjectId,
        'language': conjugations.single['language']! as String,
        'level': conjugations.single['level']! as String,
        'correct': correct ? 1 : 0,
        'completed_at': DateTime.now().millisecondsSinceEpoch,
      });
      return true;
    });
  }

  @override
  Future<void> close() => _database.close();

  static Map<String, Object?> _entryValues(VocabularyEntry entry) => {
    'id': entry.id,
    'level': entry.level.name,
    'topic': entry.topic,
    'de_primary': entry.german.primary,
    'de_accepted': jsonEncode(entry.german.accepted),
    'pt_primary': entry.portuguese.primary,
    'pt_accepted': jsonEncode(entry.portuguese.accepted),
    'de_example': entry.germanExample,
    'pt_example': entry.portugueseExample,
    'active': 1,
  };

  static Map<String, Object?> _conjugationValues(ConjugationEntry entry) => {
    'id': entry.id,
    'language': entry.language.id,
    'level': entry.level.name,
    'topic': entry.topic,
    'infinitive': entry.infinitive,
    'tense': entry.tense,
    'subjects': encodeConjugationSubjects(entry.subjects),
    'active': 1,
  };

  static ConjugationEntry _conjugationFromRow(Map<String, Object?> row) =>
      ConjugationEntry(
        id: row['id']! as String,
        language: ConjugationLanguage.fromId(
          row['language']! as String,
          'language',
        ),
        level: ProficiencyLevel.values.byName(row['level']! as String),
        topic: row['topic'] as String? ?? '',
        infinitive: row['infinitive']! as String,
        tense: row['tense']! as String,
        subjects: decodeConjugationSubjects(row['subjects']! as String),
      );

  static VocabularyEntry _entryFromRow(Map<String, Object?> row) {
    return VocabularyEntry(
      id: row['id']! as String,
      level: ProficiencyLevel.values.byName(row['level']! as String),
      topic: row['topic'] as String? ?? '',
      german: LanguageForm(
        primary: row['de_primary']! as String,
        accepted: List.unmodifiable(
          (jsonDecode(row['de_accepted']! as String) as List<Object?>)
              .cast<String>(),
        ),
      ),
      portuguese: LanguageForm(
        primary: row['pt_primary']! as String,
        accepted: List.unmodifiable(
          (jsonDecode(row['pt_accepted']! as String) as List<Object?>)
              .cast<String>(),
        ),
      ),
      germanExample: row['de_example']! as String,
      portugueseExample: row['pt_example']! as String,
    );
  }
}

class _MutableConjugationProgress {
  int promptsPracticed = 0;
  int correctAnswers = 0;
  int incorrectAnswers = 0;
}
