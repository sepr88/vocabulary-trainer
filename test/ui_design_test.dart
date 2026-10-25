import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/data/trainer_store.dart';
import 'package:vocabulary_trainer/domain/practice_session.dart';
import 'package:vocabulary_trainer/main.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
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

  testWidgets('home progress tiles scroll fully into view on Pixel 5 size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 851);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _DesignTestStore([sampleEntry()]);
    await tester.pumpWidget(MyApp(storeLoader: () async => store));
    await tester.pumpAndSettle();

    expect(find.byType(Scrollable), findsOneWidget);
    final lastTile = find.text('Entries answered incorrectly');
    final homeScrollView = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(lastTile, 200, scrollable: homeScrollView);
    await tester.pumpAndSettle();

    final tileRect = tester.getRect(lastTile);
    final scrollRect = tester.getRect(find.byType(Scrollable).first);
    expect(tileRect.top, greaterThanOrEqualTo(scrollRect.top));
    expect(tileRect.bottom, lessThanOrEqualTo(scrollRect.bottom));
    expect(tester.takeException(), isNull);
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

  testWidgets(
    'practice content and actions fit a Pixel 5-sized portrait screen',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 851);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = _DesignTestStore([sampleEntry()]);
      await tester.pumpWidget(MyApp(storeLoader: () async => store));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Start practice'));
      await tester.pumpAndSettle();

      final germanToPortuguese = find
          .text('German → European Portuguese')
          .evaluate()
          .isNotEmpty;
      final sourceSentence = tester.widget<Text>(
        find.text(
          germanToPortuguese ? 'Das Haus ist wichtig.' : 'A casa é importante.',
        ),
      );
      expect(sourceSentence.style?.fontSize, greaterThanOrEqualTo(16));
      expect(find.text('Check answer'), findsOneWidget);
      expect(find.text('Reveal answer'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position
            .maxScrollExtent,
        0,
      );

      await tester.tap(find.text('Reveal answer'));
      await tester.pumpAndSettle();
      final translatedSentence = tester.widget<Text>(
        find.text(
          germanToPortuguese ? 'A casa é importante.' : 'Das Haus ist wichtig.',
        ),
      );
      expect(translatedSentence.style?.fontSize, greaterThanOrEqualTo(16));
      expect(find.text('Marked incorrect'), findsOneWidget);
      expect(find.text('Finish session'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).last)
            .position
            .maxScrollExtent,
        0,
      );
    },
  );
}

class _DesignTestStore implements TrainerStore {
  _DesignTestStore(this.entries);

  final List<VocabularyEntry> entries;

  @override
  Future<List<VocabularyEntry>> activeEntries() async => entries;

  @override
  Future<int> activeVocabularyVersion() async => 1;

  @override
  Future<Map<String, PracticeHistory>> practiceHistory() async => const {};

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
  Future<void> reconcile(VocabularyDataset dataset) async {}
}
