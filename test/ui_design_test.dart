import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/data/trainer_store.dart';
import 'package:vocabulary_trainer/main.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

import 'support/fixtures.dart';

void main() {
  testWidgets('home uses the new palette and accessible practice action', (
    tester,
  ) async {
    final store = _DesignTestStore([sampleEntry()]);
    await tester.pumpWidget(MyApp(storeLoader: () async => store));
    await tester.pumpAndSettle();

    final theme = Theme.of(tester.element(find.byType(HomeScreen)));
    expect(theme.colorScheme.primary, const Color(0xff367a2c));
    expect(theme.scaffoldBackgroundColor, const Color(0xfffffdf6));
    expect(
      theme.filledButtonTheme.style!.minimumSize!.resolve({}),
      const Size(48, 56),
    );
    expect(find.text('Ready for a little practice?'), findsOneWidget);
    expect(find.text('Your learning'), findsOneWidget);
    expect(find.text('Vocabulary version 1'), findsOneWidget);
  });

  testWidgets('practice shows a direction chip and session progress', (
    tester,
  ) async {
    final store = _DesignTestStore([sampleEntry()]);
    await tester.pumpWidget(MyApp(storeLoader: () async => store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz_rounded), findsOneWidget);
    expect(find.text('Your translation'), findsOneWidget);
    expect(find.text('Reveal answer'), findsOneWidget);
  });
}

class _DesignTestStore implements TrainerStore {
  _DesignTestStore(this.entries);

  final List<VocabularyEntry> entries;

  @override
  Future<List<VocabularyEntry>> activeEntries() async => entries;

  @override
  Future<int> activeVocabularyVersion() async => 1;

  @override
  Future<void> close() async {}

  @override
  Future<ProgressSnapshot> progress() async => ProgressSnapshot(
    activeVocabularyCount: entries.length,
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
  Future<void> reconcile(VocabularyDataset dataset) async {}
}
