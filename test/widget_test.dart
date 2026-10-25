import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/data/trainer_store.dart';
import 'package:vocabulary_trainer/domain/practice_session.dart';
import 'package:vocabulary_trainer/main.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
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
    expect(
      find.text(
        germanToPortuguese ? 'Das Haus ist wichtig.' : 'A casa é importante.',
      ),
      findsOneWidget,
    );
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
    expect(
      find.text(
        germanToPortuguese ? 'A casa é importante.' : 'Das Haus ist wichtig.',
      ),
      findsOneWidget,
    );
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

  testWidgets('runs a separate conjugation session and updates its progress', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 851);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _MemoryStore(
      [sampleEntry()],
      conjugations: [sampleConjugation()],
    );
    await tester.pumpWidget(MyApp(storeLoader: () async => store));
    await tester.pumpAndSettle();

    expect(find.text('Practice conjugation'), findsOneWidget);
    await tester.tap(find.text('Practice conjugation'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your practice'), findsOneWidget);
    await tester.tap(find.text('Start session (2 prompts)'));
    await tester.pumpAndSettle();
    expect(find.text('Prompt 1 of 2'), findsOneWidget);
    expect(find.text('sein'), findsOneWidget);

    final subject = storeAnswerFor(tester);
    await tester.enterText(
      find.byKey(const ValueKey('conjugation-answer')),
      subject,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Correct'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reveal answer'));
    await tester.pumpAndSettle();
    expect(find.text('Marked incorrect'), findsOneWidget);
    await tester.tap(find.text('Finish session'));
    await tester.pumpAndSettle();

    expect(find.text('Conjugation session complete'), findsOneWidget);
    expect(find.text('Prompts practiced'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(store.conjugationAttempts, [true, false]);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Items practiced'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets(
    'opens only the selected language reference and returns to the active prompt',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 851);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final portugueseEntry = sampleConjugation(
        id: 'pt-PT-beginner-ser',
        language: ConjugationLanguage.portuguese,
        infinitive: 'ser',
        subjects: const [
          ConjugationSubject(id: 'eu', primary: 'sou', accepted: ['sou']),
          ConjugationSubject(id: 'tu', primary: 'és', accepted: ['és']),
        ],
      );
      final store = _MemoryStore(
        [sampleEntry()],
        conjugations: [portugueseEntry],
      );
      await tester.pumpWidget(MyApp(storeLoader: () async => store));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Practice conjugation'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Grammar reference'), findsNothing);
      await tester.tap(find.text('European Portuguese'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start session (2 prompts)'));
      await tester.pumpAndSettle();

      final promptFinder = find.byKey(
        const ValueKey('conjugation-prompt-infinitive'),
      );
      final promptBeforeHelp = tester.widget<Text>(promptFinder);
      expect(find.text('Prompt 1 of 2'), findsOneWidget);
      expect(find.byTooltip('Grammar reference'), findsOneWidget);
      await tester.tap(find.byTooltip('Grammar reference'));
      await tester.pumpAndSettle();

      expect(find.text('European Portuguese grammar'), findsOneWidget);
      expect(find.text('Regular conjugation'), findsOneWidget);
      expect(find.text('falar'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('ser'),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('grammar-reference-content')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('ser'), findsOneWidget);
      expect(find.text('German grammar'), findsNothing);
      expect(find.text('machen'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Prompt 1 of 2'), findsOneWidget);
      expect(tester.widget<Text>(promptFinder).data, promptBeforeHelp.data);
      expect(find.byTooltip('Grammar reference'), findsOneWidget);
      expect(find.byKey(const ValueKey('conjugation-answer')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

String storeAnswerFor(WidgetTester tester) {
  if (find.text('ich').evaluate().isNotEmpty) return 'bin';
  if (find.text('du').evaluate().isNotEmpty) return 'bist';
  throw StateError('No supported subject prompt was displayed.');
}

class _MemoryStore implements TrainerStore {
  _MemoryStore(
    this.entries, {
    this.vocabularyVersion = 1,
    this.conjugations = const [],
  });

  final List<VocabularyEntry> entries;
  final int vocabularyVersion;
  final List<ConjugationEntry> conjugations;
  final Map<String, ({String entryId, bool correct})> _recorded = {};
  final Map<String, ({String conjugationId, String subjectId, bool correct})>
  _conjugationRecorded = {};

  List<bool> get attempts =>
      _recorded.values.map((attempt) => attempt.correct).toList();
  List<bool> get conjugationAttempts =>
      _conjugationRecorded.values.map((attempt) => attempt.correct).toList();

  @override
  Future<List<VocabularyEntry>> activeEntries() async => entries;

  @override
  Future<int> activeVocabularyVersion() async => vocabularyVersion;

  @override
  Future<Map<String, PracticeHistory>> practiceHistory() async => {
    for (final entry in _recorded.values)
      entry.entryId: PracticeHistory(
        completedAttempts: _recorded.values
            .where((attempt) => attempt.entryId == entry.entryId)
            .length,
        incorrectAttempts: _recorded.values
            .where(
              (attempt) => attempt.entryId == entry.entryId && !attempt.correct,
            )
            .length,
      ),
  };

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
  Future<List<ConjugationEntry>> activeConjugations() async => conjugations;

  @override
  Future<Map<ConjugationProgressKey, ConjugationProgress>>
  conjugationProgress() async {
    final result = <ConjugationProgressKey, ConjugationProgress>{};
    for (final language in ConjugationLanguage.values) {
      for (final level in ProficiencyLevel.values) {
        final matching = _conjugationRecorded.values.where((attempt) {
          final entry = conjugations.firstWhere(
            (entry) => entry.id == attempt.conjugationId,
          );
          return entry.language == language && entry.level == level;
        }).toList();
        final unique = <String, Set<bool>>{};
        for (final attempt in matching) {
          unique
              .putIfAbsent(
                '${attempt.conjugationId}:${attempt.subjectId}',
                () => <bool>{},
              )
              .add(attempt.correct);
        }
        result[ConjugationProgressKey(language, level)] = ConjugationProgress(
          promptsPracticed: matching.length,
          correctAnswers: matching.where((attempt) => attempt.correct).length,
          incorrectAnswers: matching
              .where((attempt) => !attempt.correct)
              .length,
          uniquePromptsCorrect: unique.values
              .where((results) => results.contains(true))
              .length,
          uniquePromptsIncorrect: unique.values
              .where((results) => results.contains(false))
              .length,
        );
      }
    }
    return result;
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
  Future<bool> recordConjugationAttempt({
    required String attemptId,
    required String conjugationId,
    required String subjectId,
    required bool correct,
  }) async {
    if (_conjugationRecorded.containsKey(attemptId)) return false;
    _conjugationRecorded[attemptId] = (
      conjugationId: conjugationId,
      subjectId: subjectId,
      correct: correct,
    );
    return true;
  }

  @override
  Future<void> reconcile(VocabularyDataset dataset) async {}
}
