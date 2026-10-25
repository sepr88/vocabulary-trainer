import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/domain/adaptive_selection.dart';
import 'package:vocabulary_trainer/domain/conjugation_session.dart';
import 'package:vocabulary_trainer/domain/practice_session.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

void main() {
  test('vocabulary defaults to all topics and filters before selection', () {
    final family = _entry(
      id: 'family',
      topic: 'family-and-people',
      german: 'die Familie',
      portuguese: 'a família',
    );
    final time = _entry(
      id: 'time',
      topic: 'numbers-dates-and-time',
      german: 'die Uhr',
      portuguese: 'o relógio',
    );

    final allTopics = PracticeSession.create([family, time], random: Random(4));
    final selectedTopic = PracticeSession.create(
      [family, time],
      topicId: 'family-and-people',
      random: Random(4),
    );

    expect(allTopics.items, hasLength(2));
    expect(selectedTopic.items.map((item) => item.entry.id), ['family']);
  });

  test(
    'conjugation topic limits eligible prompts before weighted selection',
    () {
      final home = _conjugation(
        id: 'home',
        topic: 'daily-life-and-home',
        infinitive: 'wohnen',
      );
      final movement = _conjugation(
        id: 'movement',
        topic: 'movement-and-travel',
        infinitive: 'reisen',
      );

      final allTopics = ConjugationSession.create(
        [home, movement],
        language: ConjugationLanguage.german,
        level: ProficiencyLevel.beginner,
        random: Random(2),
      );
      final selectedTopic = ConjugationSession.create(
        [home, movement],
        language: ConjugationLanguage.german,
        level: ProficiencyLevel.beginner,
        topicId: 'movement-and-travel',
        practiceHistory: {
          const ConjugationPromptKey('home', 'ich'): SelectionHistory.empty,
        },
        random: Random(2),
      );

      expect(allTopics.prompts, hasLength(2));
      expect(selectedTopic.prompts.map((prompt) => prompt.entry.id), [
        'movement',
      ]);
    },
  );
}

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
  subjects: const [
    ConjugationSubject(id: 'ich', primary: 'wohne', accepted: ['wohne']),
  ],
);
