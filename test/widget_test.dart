import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/data/trainer_store.dart';
import 'package:vocabulary_trainer/domain/adaptive_selection.dart';
import 'package:vocabulary_trainer/domain/conjugation_session.dart';
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
        .text('German → Portuguese')
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
    'home shows correct-answer progress and highlights completed groups',
    (tester) async {
      final entries = [
        _entryWithTopic('family-1', 'family-and-people'),
        _entryWithTopic('family-2', 'family-and-people'),
        _entryWithTopic('time-1', 'numbers-dates-and-time'),
      ];
      final conjugations = [
        _conjugationWithTopic('home-verb', 'daily-life-and-home'),
        _conjugationWithTopic('movement-verb', 'movement-and-travel'),
      ];
      final store = _MemoryStore(entries, conjugations: conjugations);
      await store.recordAttempt(
        attemptId: 'family-correct',
        entryId: 'family-1',
        correct: true,
      );
      await store.recordAttempt(
        attemptId: 'family-reveal',
        entryId: 'family-2',
        correct: false,
      );
      await store.recordAttempt(
        attemptId: 'time-correct',
        entryId: 'time-1',
        correct: true,
      );
      await store.recordConjugationAttempt(
        attemptId: 'home-correct',
        conjugationId: 'home-verb',
        subjectId: 'ich',
        correct: true,
      );
      await store.recordConjugationAttempt(
        attemptId: 'home-reveal',
        conjugationId: 'home-verb',
        subjectId: 'du',
        correct: false,
      );
      for (final subjectId in ['ich', 'du']) {
        await store.recordConjugationAttempt(
          attemptId: 'movement-$subjectId',
          conjugationId: 'movement-verb',
          subjectId: subjectId,
          correct: true,
        );
      }

      await tester.pumpWidget(MyApp(storeLoader: () async => store));
      await tester.pumpAndSettle();

      final familyBar = tester.widget<LinearProgressIndicator>(
        find.byKey(
          const ValueKey('learning-progress-vocabulary-family-and-people'),
        ),
      );
      expect(familyBar.value, 0.5);
      final familyGroup = tester.widget<Container>(
        find.byKey(
          const ValueKey('learning-group-vocabulary-family-and-people'),
        ),
      );
      expect(familyGroup.decoration, isA<BoxDecoration>());
      expect((familyGroup.decoration! as BoxDecoration).color, Colors.white);

      final timeGroup = tester.widget<Container>(
        find.byKey(
          const ValueKey('learning-group-vocabulary-numbers-dates-and-time'),
        ),
      );
      expect(
        (timeGroup.decoration! as BoxDecoration).color,
        Theme.of(tester.element(find.byType(HomeScreen)))
            .colorScheme
            .primaryContainer,
      );

      final conjugationBar = tester.widget<LinearProgressIndicator>(
        find.byKey(
          const ValueKey(
            'learning-progress-conjugation-de-beginner-daily-life-and-home',
          ),
        ),
      );
      expect(conjugationBar.value, 0.5);
      final completedConjugationGroup = tester.widget<Container>(
        find.byKey(
          const ValueKey(
            'learning-group-conjugation-de-beginner-movement-and-travel',
          ),
        ),
      );
      expect(
        (completedConjugationGroup.decoration! as BoxDecoration).color,
        Theme.of(tester.element(find.byType(HomeScreen)))
            .colorScheme
            .primaryContainer,
      );
    },
  );

  testWidgets('conjugation setup shows the capped session prompt count', (
    tester,
  ) async {
    final conjugations = [
      for (var index = 0; index < 8; index++)
        sampleConjugation(id: 'de-beginner-$index'),
    ];
    final store = _MemoryStore([sampleEntry()], conjugations: conjugations);
    await tester.pumpWidget(MyApp(storeLoader: () async => store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Practice conjugation'));
    await tester.pumpAndSettle();
    expect(find.text('Start session (15 prompts)'), findsOneWidget);
    expect(
      find.text('Each session includes up to 15 verb and subject prompts.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Start session (15 prompts)'));
    await tester.pumpAndSettle();
    expect(find.text('Prompt 1 of 15'), findsOneWidget);
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
      await tester.tap(find.text('Portuguese'));
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

      expect(find.text('Portuguese grammar'), findsOneWidget);
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

VocabularyEntry _entryWithTopic(String id, String topic) {
  final entry = sampleEntry(id: id);
  return VocabularyEntry(
    id: entry.id,
    level: entry.level,
    topic: topic,
    german: entry.german,
    portuguese: entry.portuguese,
    germanExample: entry.germanExample,
    portugueseExample: entry.portugueseExample,
  );
}

ConjugationEntry _conjugationWithTopic(String id, String topic) {
  final entry = sampleConjugation(id: id);
  return ConjugationEntry(
    id: entry.id,
    language: entry.language,
    level: entry.level,
    topic: topic,
    infinitive: entry.infinitive,
    translation: entry.translation,
    tense: entry.tense,
    subjects: entry.subjects,
  );
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
  final Map<String, ({String entryId, bool correct, DateTime completedAt})>
  _recorded = {};
  final Map<
    String,
    ({
      String conjugationId,
      String subjectId,
      bool correct,
      DateTime completedAt,
    })
  >
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
  Future<Map<String, SelectionHistory>> vocabularySelectionHistory() async {
    final grouped = <String, List<SelectionAttempt>>{};
    for (final attempt in _recorded.values) {
      grouped
          .putIfAbsent(attempt.entryId, () => [])
          .add(
            SelectionAttempt(
              correct: attempt.correct,
              completedAt: attempt.completedAt,
            ),
          );
    }
    return {
      for (final entry in grouped.entries)
        entry.key: SelectionHistory.fromAttempts(entry.value),
    };
  }

  @override
  Future<Map<ConjugationPromptKey, SelectionHistory>>
  conjugationSelectionHistory() async {
    final grouped = <ConjugationPromptKey, List<SelectionAttempt>>{};
    for (final attempt in _conjugationRecorded.values) {
      final key = ConjugationPromptKey(
        attempt.conjugationId,
        attempt.subjectId,
      );
      grouped
          .putIfAbsent(key, () => [])
          .add(
            SelectionAttempt(
              correct: attempt.correct,
              completedAt: attempt.completedAt,
            ),
          );
    }
    return {
      for (final entry in grouped.entries)
        entry.key: SelectionHistory.fromAttempts(entry.value),
    };
  }

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
    _recorded[attemptId] = (
      entryId: entryId,
      correct: correct,
      completedAt: DateTime.now(),
    );
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
      completedAt: DateTime.now(),
    );
    return true;
  }

  @override
  Future<void> reconcile(VocabularyDataset dataset) async {}
}
