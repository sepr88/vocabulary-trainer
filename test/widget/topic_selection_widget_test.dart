import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/data/trainer_store.dart';
import 'package:vocabulary_trainer/domain/adaptive_selection.dart';
import 'package:vocabulary_trainer/domain/conjugation_session.dart';
import 'package:vocabulary_trainer/main.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

void main() {
  testWidgets('vocabulary topic selector defaults to all and applies a topic', (
    tester,
  ) async {
    final store = _storeWithTopics();
    await tester.pumpWidget(MyApp(storeLoader: () async => store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start practice'));
    await tester.pumpAndSettle();

    final allTopics = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'All topics'),
    );
    expect(allTopics.selected, isTrue);
    expect(find.text('Beginner'), findsOneWidget);
    expect(find.text('Advanced'), findsOneWidget);
    final familyTopic = find.byKey(
      const ValueKey('vocabulary-topic-family-and-people'),
    );
    await tester.ensureVisible(familyTopic);
    await tester.tap(familyTopic);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(familyTopic).selected, isTrue);
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Start session (1 entries)'), findsOneWidget);
    final startVocabulary = find.byKey(
      const ValueKey('start-vocabulary-session'),
    );
    await tester.ensureVisible(startVocabulary);
    await tester.tap(startVocabulary);
    await tester.pumpAndSettle();

    expect(
      find.text('die Familie').evaluate().isNotEmpty ||
          find.text('a família').evaluate().isNotEmpty,
      isTrue,
    );
    expect(find.text('die Uhr'), findsNothing);
    expect(find.text('o relógio'), findsNothing);
  });

  testWidgets('conjugation topic selector follows language and level', (
    tester,
  ) async {
    final store = _storeWithTopics();
    await tester.pumpWidget(MyApp(storeLoader: () async => store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Practice conjugation'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All topics'))
          .selected,
      isTrue,
    );
    expect(find.text('Daily life and home'), findsOneWidget);
    expect(find.text('Movement and travel'), findsOneWidget);
    await tester.tap(find.text('Advanced'));
    await tester.pumpAndSettle();
    expect(find.text('Daily life and home'), findsNothing);
    expect(find.text('Work and education'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All topics'))
          .selected,
      isTrue,
    );
    await tester.tap(find.text('Beginner'));
    await tester.pumpAndSettle();
    final movementTopic = find.byKey(
      const ValueKey('conjugation-topic-movement-and-travel'),
    );
    await tester.ensureVisible(movementTopic);
    await tester.tap(movementTopic);
    await tester.pumpAndSettle();
    expect(find.text('Start session (1 prompts)'), findsOneWidget);
    final startConjugation = find.text('Start session (1 prompts)');
    await tester.ensureVisible(startConjugation);
    await tester.tap(startConjugation);
    await tester.pumpAndSettle();

    expect(find.text('reisen'), findsOneWidget);
    expect(find.text('wohnen'), findsNothing);
  });
}

TrainerStore _storeWithTopics() => _WidgetStore(
  [
    _entry(
      id: 'family-entry',
      topic: 'family-and-people',
      german: 'die Familie',
      portuguese: 'a família',
    ),
    _entry(
      id: 'time-entry',
      topic: 'numbers-dates-and-time',
      german: 'die Uhr',
      portuguese: 'o relógio',
    ),
  ],
  [
    _conjugation(
      id: 'home-verb',
      topic: 'daily-life-and-home',
      infinitive: 'wohnen',
    ),
    _conjugation(
      id: 'movement-verb',
      topic: 'movement-and-travel',
      infinitive: 'reisen',
    ),
  ],
);

VocabularyEntry _entry({
  required String id,
  required String topic,
  required String german,
  required String portuguese,
}) => VocabularyEntry(
  id: id,
  level: ProficiencyLevel.beginner,
  topic: topic,
  german: LanguageForm(primary: german, accepted: [german]),
  portuguese: LanguageForm(primary: portuguese, accepted: [portuguese]),
  germanExample: 'Hier ist das Wort.',
  portugueseExample: 'Aqui está a palavra.',
);

ConjugationEntry _conjugation({
  required String id,
  required String topic,
  required String infinitive,
}) => ConjugationEntry(
  id: id,
  language: ConjugationLanguage.german,
  level: ProficiencyLevel.beginner,
  topic: topic,
  infinitive: infinitive,
  tense: 'presentIndicative',
  subjects: [
    ConjugationSubject(
      id: 'ich',
      primary: infinitive == 'wohnen' ? 'wohne' : 'reise',
      accepted: [infinitive == 'wohnen' ? 'wohne' : 'reise'],
    ),
  ],
);

class _WidgetStore implements TrainerStore {
  _WidgetStore(this.entries, this.conjugations);

  final List<VocabularyEntry> entries;
  final List<ConjugationEntry> conjugations;

  @override
  Future<List<VocabularyEntry>> activeEntries() async => entries;

  @override
  Future<List<ConjugationEntry>> activeConjugations() async => conjugations;

  @override
  Future<int> activeVocabularyVersion() async => 6;

  @override
  Future<Map<String, SelectionHistory>> vocabularySelectionHistory() async =>
      const {};

  @override
  Future<Map<ConjugationPromptKey, SelectionHistory>>
  conjugationSelectionHistory() async => const {};

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
  Future<Map<ConjugationProgressKey, ConjugationProgress>>
  conjugationProgress() async => {
    for (final language in ConjugationLanguage.values)
      for (final level in ProficiencyLevel.values)
        ConjugationProgressKey(language, level): const ConjugationProgress(
          promptsPracticed: 0,
          correctAnswers: 0,
          incorrectAnswers: 0,
          uniquePromptsCorrect: 0,
          uniquePromptsIncorrect: 0,
        ),
  };

  @override
  Future<void> reconcile(VocabularyDataset dataset) async {}

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
  Future<void> close() async {}
}
