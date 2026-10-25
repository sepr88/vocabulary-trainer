import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/domain/adaptive_selection.dart';
import 'package:vocabulary_trainer/domain/conjugation_session.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

import '../support/fixtures.dart';

void main() {
  test('includes every selected verb-subject combination exactly once', () {
    final sein = sampleConjugation();
    final haben = sampleConjugation(
      id: 'de-beginner-haben',
      infinitive: 'haben',
      subjects: const [
        ConjugationSubject(id: 'ich', primary: 'habe', accepted: ['habe']),
        ConjugationSubject(id: 'du', primary: 'hast', accepted: ['hast']),
      ],
    );
    final portuguese = sampleConjugation(
      id: 'pt-PT-beginner-ser',
      language: ConjugationLanguage.portuguese,
      infinitive: 'ser',
    );
    final advanced = sampleConjugation(
      id: 'de-advanced-sein',
      level: ProficiencyLevel.advanced,
    );

    final session = ConjugationSession.create(
      [sein, haben, portuguese, advanced],
      language: ConjugationLanguage.german,
      level: ProficiencyLevel.beginner,
      random: Random(7),
    );

    expect(session.prompts, hasLength(4));
    expect(
      session.prompts
          .map((prompt) => '${prompt.entry.id}:${prompt.subject.id}')
          .toSet(),
      {'${sein.id}:ich', '${sein.id}:du', '${haben.id}:ich', '${haben.id}:du'},
    );
    expect(session.prompts.map((prompt) => prompt.attemptId).toSet().length, 4);
  });

  test('weights matching prompts and caps sessions at 15 without repeats', () {
    final entries = [
      for (var index = 0; index < 8; index++)
        sampleConjugation(
          id: 'de-beginner-$index',
          subjects: const [
            ConjugationSubject(
              id: 'ich',
              primary: 'lerne',
              accepted: ['lerne'],
            ),
            ConjugationSubject(
              id: 'du',
              primary: 'lernst',
              accepted: ['lernst'],
            ),
          ],
        ),
      sampleConjugation(
        id: 'pt-PT-beginner',
        language: ConjugationLanguage.portuguese,
      ),
      sampleConjugation(id: 'de-advanced', level: ProficiencyLevel.advanced),
    ];
    final now = DateTime.utc(2026, 10, 25);
    final history = SelectionHistory.fromAttempts(
      List.generate(
        5,
        (index) => SelectionAttempt(
          correct: false,
          completedAt: now.subtract(Duration(minutes: index)),
        ),
      ),
    );
    final session = ConjugationSession.create(
      entries,
      language: ConjugationLanguage.german,
      level: ProficiencyLevel.beginner,
      practiceHistory: {
        const ConjugationPromptKey('de-beginner-0', 'ich'): history,
      },
      random: _ScriptedRandom([0.1]),
      now: now,
    );

    expect(session.prompts, hasLength(15));
    expect(
      session.prompts
          .map((prompt) => '${prompt.entry.id}:${prompt.subject.id}')
          .toSet(),
      hasLength(15),
    );
    expect(session.prompts.first.entry.id, 'de-beginner-0');
    expect(
      session.prompts.every(
        (prompt) =>
            prompt.entry.language == ConjugationLanguage.german &&
            prompt.entry.level == ProficiencyLevel.beginner,
      ),
      isTrue,
    );
  });

  test('matches whitespace and case but preserves diacritic distinctions', () {
    final portuguese = sampleConjugation(
      id: 'pt-PT-beginner-ser',
      language: ConjugationLanguage.portuguese,
      infinitive: 'ser',
      subjects: const [
        ConjugationSubject(id: 'tu', primary: 'és', accepted: ['és']),
      ],
    );
    final prompt = ConjugationSession.create(
      [portuguese],
      language: ConjugationLanguage.portuguese,
      level: ProficiencyLevel.beginner,
      random: Random(1),
    ).prompts.single;

    expect(prompt.matches('  ÉS '), isTrue);
    expect(prompt.matches('es'), isFalse);
  });

  test('records each prompt result only once', () {
    final session = ConjugationSession.create(
      [sampleConjugation()],
      language: ConjugationLanguage.german,
      level: ProficiencyLevel.beginner,
      random: Random(1),
    );

    expect(session.completePrompt(0, correct: true), isTrue);
    expect(session.completePrompt(0, correct: false), isFalse);
    expect(session.summary.practiced, 1);
    expect(session.summary.correct, 1);
    expect(session.summary.incorrect, 0);
  });
}

class _ScriptedRandom implements Random {
  _ScriptedRandom(this._draws);

  final List<double> _draws;
  var _drawIndex = 0;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() {
    if (_drawIndex < _draws.length) return _draws[_drawIndex++];
    return 0;
  }
}
