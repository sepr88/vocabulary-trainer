import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/domain/adaptive_selection.dart';
import 'package:vocabulary_trainer/domain/conjugation_session.dart';
import 'package:vocabulary_trainer/domain/learning_progress.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

import '../support/fixtures.dart';

void main() {
  test(
    'vocabulary group progress counts distinct candidates with correct answers',
    () {
      final entries = [
        _vocabularyEntry('family-1', 'family-and-people'),
        _vocabularyEntry('family-2', 'family-and-people'),
        _vocabularyEntry('time-1', 'numbers-dates-and-time'),
        _vocabularyEntry('unknown-topic', ''),
      ];
      final progress = LearningProgress.vocabulary(
        entries: entries,
        history: {
          'family-1': _history(correct: true),
          'family-2': _history(correct: false),
          'time-1': _history(correct: true),
        },
      );

      final family = progress.singleWhere(
        (group) => group.topic.id == 'family-and-people',
      );
      expect(family.successfulCandidates, 1);
      expect(family.totalCandidates, 2);
      expect(family.fraction, 0.5);
      expect(family.isComplete, isFalse);

      final time = progress.singleWhere(
        (group) => group.topic.id == 'numbers-dates-and-time',
      );
      expect(time.fraction, 1);
      expect(time.isComplete, isTrue);
    },
  );

  test('conjugation group progress counts correct subject prompts only', () {
    final entries = [
      _conjugationEntry(
        'home-verb',
        'daily-life-and-home',
        ConjugationLanguage.german,
        ProficiencyLevel.beginner,
        const ['ich', 'du'],
      ),
      _conjugationEntry(
        'other-language',
        'daily-life-and-home',
        ConjugationLanguage.portuguese,
        ProficiencyLevel.beginner,
        const ['eu'],
      ),
      _conjugationEntry(
        'other-level',
        'daily-life-and-home',
        ConjugationLanguage.german,
        ProficiencyLevel.advanced,
        const ['ich'],
      ),
    ];
    final progress = LearningProgress.conjugation(
      entries: entries,
      language: ConjugationLanguage.german,
      level: ProficiencyLevel.beginner,
      history: {
        const ConjugationPromptKey('home-verb', 'ich'): _history(correct: true),
        const ConjugationPromptKey('home-verb', 'du'): _history(correct: false),
      },
    );

    expect(progress, hasLength(3));
    final home = progress.singleWhere(
      (group) => group.topic.id == 'daily-life-and-home',
    );
    expect(home.successfulCandidates, 1);
    expect(home.totalCandidates, 2);
    expect(home.fraction, 0.5);
    expect(home.isComplete, isFalse);
  });

  test('empty groups have zero progress and are not highlighted complete', () {
    final group = LearningProgress.vocabulary(
      entries: const [],
      history: const {},
    ).first;

    expect(group.fraction, 0);
    expect(group.isComplete, isFalse);
  });
}

VocabularyEntry _vocabularyEntry(String id, String topic) {
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

ConjugationEntry _conjugationEntry(
  String id,
  String topic,
  ConjugationLanguage language,
  ProficiencyLevel level,
  List<String> subjectIds,
) => ConjugationEntry(
  id: id,
  language: language,
  level: level,
  topic: topic,
  infinitive: 'verb',
  tense: 'presentIndicative',
  subjects: [
    for (final subjectId in subjectIds)
      ConjugationSubject(
        id: subjectId,
        primary: 'form',
        accepted: const ['form'],
      ),
  ],
);

SelectionHistory _history({required bool correct}) =>
    SelectionHistory.fromAttempts([
      SelectionAttempt(correct: correct, completedAt: DateTime.utc(2026)),
    ]);
