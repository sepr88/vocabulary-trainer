import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/practice_session.dart';
import '../models/vocabulary.dart';

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
  Future<Map<String, PracticeHistory>> practiceHistory();
  Future<ProgressSnapshot> progress();
  Future<bool> recordAttempt({
    required String attemptId,
    required String entryId,
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
      version: 2,
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

      await transaction.update('vocabulary_entries', {'active': 0});
      for (final entry in dataset.entries) {
        final values = _entryValues(entry)..['active'] = 1;
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
  Future<Map<String, PracticeHistory>> practiceHistory() async {
    final rows = await _database.rawQuery('''
      SELECT
        entry_id,
        COUNT(*) AS attempts,
        SUM(1 - correct) AS incorrect
      FROM practice_attempts
      GROUP BY entry_id
    ''');
    return Map.unmodifiable({
      for (final row in rows)
        row['entry_id']! as String: PracticeHistory(
          completedAttempts: row['attempts']! as int,
          incorrectAttempts: row['incorrect']! as int,
        ),
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
  Future<void> close() => _database.close();

  static Map<String, Object?> _entryValues(VocabularyEntry entry) => {
    'id': entry.id,
    'level': entry.level.name,
    'de_primary': entry.german.primary,
    'de_accepted': jsonEncode(entry.german.accepted),
    'pt_primary': entry.portuguese.primary,
    'pt_accepted': jsonEncode(entry.portuguese.accepted),
    'de_example': entry.germanExample,
    'pt_example': entry.portugueseExample,
    'active': 1,
  };

  static VocabularyEntry _entryFromRow(Map<String, Object?> row) {
    return VocabularyEntry(
      id: row['id']! as String,
      level: ProficiencyLevel.values.byName(row['level']! as String),
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
