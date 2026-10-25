import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/data/bootstrap.dart';
import 'package:vocabulary_trainer/data/trainer_store.dart';
import 'package:vocabulary_trainer/domain/adaptive_selection.dart';
import 'package:vocabulary_trainer/domain/conjugation_session.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

void main() {
  test('validates the bundle before reconciling the local store', () async {
    final store = _RecordingStore();
    var requestedAsset = '';

    final initialized = await initializeTrainerStore(
      loadAsset: (key) async {
        requestedAsset = key;
        return _bundle(100);
      },
      openStore: () async => store,
    );

    expect(requestedAsset, bundledVocabularyPath);
    expect(identical(initialized, store), isTrue);
    expect(store.reconciledDataset?.version, 1);
    expect(store.reconciledDataset?.entries, hasLength(100));
    expect(store.closed, isFalse);
  });

  test(
    'does not open storage for invalid or too-small bundled vocabulary',
    () async {
      var opened = false;

      for (final source in [
        _bundle(1),
        '{"version":0,"entries":[],"conjugations":[]}',
      ]) {
        await expectLater(
          initializeTrainerStore(
            loadAsset: (_) async => source,
            openStore: () async {
              opened = true;
              return _RecordingStore();
            },
          ),
          throwsFormatException,
        );
      }

      expect(opened, isFalse);
    },
  );

  test(
    'rejects insufficient conjugation coverage before opening storage',
    () async {
      var opened = false;
      await expectLater(
        initializeTrainerStore(
          loadAsset: (_) async => _bundle(100, conjugationsPerGroup: 9),
          openStore: () async {
            opened = true;
            return _RecordingStore();
          },
        ),
        throwsFormatException,
      );
      expect(opened, isFalse);
    },
  );

  test('rejects duplicate verbs in conjugation coverage', () async {
    var opened = false;
    await expectLater(
      initializeTrainerStore(
        loadAsset: (_) async => _bundle(100, duplicateVerbNames: true),
        openStore: () async {
          opened = true;
          return _RecordingStore();
        },
      ),
      throwsFormatException,
    );
    expect(opened, isFalse);
  });

  test('closes the store and preserves the reconciliation failure', () async {
    final failure = StateError('reconciliation failed');
    final store = _RecordingStore(reconciliationFailure: failure);

    await expectLater(
      initializeTrainerStore(
        loadAsset: (_) async => _bundle(100),
        openStore: () async => store,
      ),
      throwsA(same(failure)),
    );

    expect(store.closed, isTrue);
  });
}

String _bundle(
  int count, {
  int conjugationsPerGroup = 10,
  bool duplicateVerbNames = false,
}) => jsonEncode({
  'version': 1,
  'entries': [
    for (var index = 0; index < count; index++)
      {
        'id': 'entry-$index',
        'level': 'beginner',
        'de': {
          'primary': 'Haus $index',
          'accepted': ['Haus $index'],
        },
        'pt-PT': {
          'primary': 'casa $index',
          'accepted': ['casa $index'],
        },
        'examples': {
          'de': 'Das Haus ist wichtig.',
          'pt-PT': 'A casa é importante.',
        },
      },
  ],
  'conjugations': [
    for (final language in ConjugationLanguage.values)
      for (final level in ProficiencyLevel.values)
        for (var index = 0; index < conjugationsPerGroup; index++)
          {
            'id': '${language.id}-${level.name}-$index',
            'language': language.id,
            'level': level.name,
            'infinitive': 'verb-${duplicateVerbNames ? 0 : index}',
            'tense': 'presentIndicative',
            'subjects': [
              for (final subject in language.subjectIds)
                {
                  'id': subject,
                  'primary': 'form',
                  'accepted': ['form'],
                },
            ],
          },
  ],
});

class _RecordingStore implements TrainerStore {
  _RecordingStore({this.reconciliationFailure});

  final Object? reconciliationFailure;
  VocabularyDataset? reconciledDataset;
  bool closed = false;

  @override
  Future<List<VocabularyEntry>> activeEntries() async => const [];

  @override
  Future<int> activeVocabularyVersion() async => 1;

  @override
  Future<Map<String, SelectionHistory>> vocabularySelectionHistory() async =>
      const {};

  @override
  Future<Map<ConjugationPromptKey, SelectionHistory>>
  conjugationSelectionHistory() async => const {};

  @override
  Future<void> close() async {
    closed = true;
  }

  @override
  Future<ProgressSnapshot> progress() async => const ProgressSnapshot(
    activeVocabularyCount: 0,
    itemsPracticed: 0,
    correctAnswers: 0,
    incorrectAnswers: 0,
    uniqueEntriesCorrect: 0,
    uniqueEntriesIncorrect: 0,
  );

  @override
  Future<List<ConjugationEntry>> activeConjugations() async => const [];

  @override
  Future<Map<ConjugationProgressKey, ConjugationProgress>>
  conjugationProgress() async => const {};

  @override
  Future<bool> recordAttempt({
    required String attemptId,
    required String entryId,
    required bool correct,
  }) async => true;

  @override
  Future<bool> recordConjugationAttempt({
    required String attemptId,
    required String conjugationId,
    required String subjectId,
    required bool correct,
  }) async => true;

  @override
  Future<void> reconcile(VocabularyDataset dataset) async {
    if (reconciliationFailure case final failure?) {
      throw failure;
    }
    reconciledDataset = dataset;
  }
}
