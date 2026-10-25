import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/data/bootstrap.dart';
import 'package:vocabulary_trainer/data/trainer_store.dart';
import 'package:vocabulary_trainer/domain/practice_session.dart';
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

      for (final source in [_bundle(1), '{"version":0,"entries":[]}']) {
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

String _bundle(int count) => jsonEncode({
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
  Future<Map<String, PracticeHistory>> practiceHistory() async => const {};

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
  Future<bool> recordAttempt({
    required String attemptId,
    required String entryId,
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
