import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/data/trainer_store.dart';
import 'package:vocabulary_trainer/domain/conjugation_session.dart';
import 'package:vocabulary_trainer/main.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

void main() {
  testWidgets(
    'hides the infinitive translation until a checked response is recorded',
    (tester) async {
      final session = _session();
      await tester.pumpWidget(
        MaterialApp(
          home: ConjugationPracticeScreen(
            store: _AttemptStore(),
            session: session,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('conjugation-infinitive-translation')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('conjugation-answer')),
        session.prompts.first.subject.primary,
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('Correct'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('conjugation-expected-form')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('conjugation-infinitive-translation')),
        findsOneWidget,
      );
      expect(find.text('Infinitive translation (Portuguese)'), findsOneWidget);
      expect(find.text('ser'), findsOneWidget);
    },
  );

  testWidgets(
    'shows the translation alongside the expected form after reveal',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ConjugationPracticeScreen(
            store: _AttemptStore(),
            session: _session(),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('conjugation-infinitive-translation')),
        findsNothing,
      );

      await tester.tap(find.text('Reveal answer'));
      await tester.pumpAndSettle();

      expect(find.text('Marked incorrect'), findsOneWidget);
      expect(find.text('Expected conjugation'), findsOneWidget);
      expect(find.text('Infinitive translation (Portuguese)'), findsOneWidget);
      expect(find.text('ser'), findsOneWidget);
    },
  );
}

ConjugationSession _session() => ConjugationSession.create(
  [
    ConjugationEntry(
      id: 'de-beginner-sein',
      language: ConjugationLanguage.german,
      level: ProficiencyLevel.beginner,
      topic: 'daily-life-and-home',
      infinitive: 'sein',
      translation: 'ser',
      tense: 'presentIndicative',
      subjects: [
        for (final subject in ConjugationLanguage.german.subjectIds)
          ConjugationSubject(
            id: subject,
            primary: 'form',
            accepted: const ['form'],
          ),
      ],
    ),
  ],
  language: ConjugationLanguage.german,
  level: ProficiencyLevel.beginner,
);

class _AttemptStore implements TrainerStore {
  @override
  Future<bool> recordConjugationAttempt({
    required String attemptId,
    required String conjugationId,
    required String subjectId,
    required bool correct,
  }) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
