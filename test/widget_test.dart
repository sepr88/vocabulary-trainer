import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/data/trainer_store.dart';
import 'package:vocabulary_trainer/main.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

import 'support/fixtures.dart';

void main() {
  testWidgets('checks an answer, summarizes it, and refreshes home progress', (
    tester,
  ) async {
    final store = _MemoryStore([sampleEntry()], vocabularyVersion: 7);
    await tester.pumpWidget(MyApp(storeLoader: () async => store));
    await tester.pumpAndSettle();
    expect(find.text('Vocabulary version 7'), findsOneWidget);

    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();
    final germanToPortuguese = find
        .text('German → European Portuguese')
        .evaluate()
        .isNotEmpty;
    final answer = germanToPortuguese ? 'a casa' : 'das Haus';
    await tester.enterText(
      find.byKey(const ValueKey('practice-answer')),
      answer,
    );
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('practice-answer')))
          .controller!
          .text,
      answer,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Check answer'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.text('Check answer'));
    await tester.pumpAndSettle();

    expect(find.text('Correct'), findsOneWidget);
    expect(find.text(germanToPortuguese ? 'a casa' : 'das Haus'), findsWidgets);
    expect(store.attempts, [true]);

    await tester.tap(find.text('Finish session'));
    await tester.pumpAndSettle();
    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('Entries practiced'), findsOneWidget);
    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Items practiced'), findsOneWidget);
    expect(find.text('Correct answers'), findsOneWidget);
  });

  testWidgets('revealing marks the item incorrect before advancing', (
    tester,
  ) async {
    final store = _MemoryStore([sampleEntry()]);
    await tester.pumpWidget(MyApp(storeLoader: () async => store));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reveal answer'));
    await tester.pumpAndSettle();

    expect(find.text('Marked incorrect'), findsOneWidget);
    expect(store.attempts, [false]);
    expect(find.text('Reveal answer'), findsNothing);
    expect(find.text('Check answer'), findsNothing);
    expect(find.text('Finish session'), findsOneWidget);
  });

  testWidgets('disables practice when there are no active entries', (
    tester,
  ) async {
    await tester.pumpWidget(MyApp(storeLoader: () async => _MemoryStore([])));
    await tester.pumpAndSettle();

    expect(
      find.text('No vocabulary entries are available. Practice is disabled.'),
      findsOneWidget,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start practice'),
    );
    expect(button.onPressed, isNull);
  });
}

class _MemoryStore implements TrainerStore {
  _MemoryStore(this.entries, {this.vocabularyVersion = 1});

  final List<VocabularyEntry> entries;
  final int vocabularyVersion;
  final Map<String, ({String entryId, bool correct})> _recorded = {};

  List<bool> get attempts =>
      _recorded.values.map((attempt) => attempt.correct).toList();

  @override
  Future<List<VocabularyEntry>> activeEntries() async => entries;

  @override
  Future<int> activeVocabularyVersion() async => vocabularyVersion;

  @override
  Future<void> close() async {}

  @override
  Future<ProgressSnapshot> progress() async {
    final activeIds = entries.map((entry) => entry.id).toSet();
    final results = _recorded.values.toList();
    return ProgressSnapshot(
      activeVocabularyCount: entries.length,
      itemsPracticed: results.length,
      correctAnswers: results.where((attempt) => attempt.correct).length,
      incorrectAnswers: results.where((attempt) => !attempt.correct).length,
      uniqueEntriesCorrect: results
          .where(
            (attempt) => attempt.correct && activeIds.contains(attempt.entryId),
          )
          .map((attempt) => attempt.entryId)
          .toSet()
          .length,
      uniqueEntriesIncorrect: results
          .where(
            (attempt) =>
                !attempt.correct && activeIds.contains(attempt.entryId),
          )
          .map((attempt) => attempt.entryId)
          .toSet()
          .length,
    );
  }

  @override
  Future<bool> recordAttempt({
    required String attemptId,
    required String entryId,
    required bool correct,
  }) async {
    if (_recorded.containsKey(attemptId)) return false;
    _recorded[attemptId] = (entryId: entryId, correct: correct);
    return true;
  }

  @override
  Future<void> reconcile(VocabularyDataset dataset) async {}
}
