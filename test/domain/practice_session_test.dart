import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/domain/adaptive_selection.dart';
import 'package:vocabulary_trainer/domain/practice_session.dart';

import '../support/fixtures.dart';

void main() {
  group('PracticeItem', () {
    test('selects paired example sentences for each translation direction', () {
      final entry = sampleEntry();
      final germanToPortuguese = PracticeItem(
        attemptId: 'session:0',
        entry: entry,
        direction: TranslationDirection.germanToPortuguese,
      );
      final portugueseToGerman = PracticeItem(
        attemptId: 'session:1',
        entry: entry,
        direction: TranslationDirection.portugueseToGerman,
      );

      expect(germanToPortuguese.exampleSentence, entry.germanExample);
      expect(
        germanToPortuguese.translatedExampleSentence,
        entry.portugueseExample,
      );
      expect(portugueseToGerman.exampleSentence, entry.portugueseExample);
      expect(portugueseToGerman.translatedExampleSentence, entry.germanExample);
    });

    test('matches case-insensitively and ignores outer whitespace', () {
      final session = PracticeSession.create([
        sampleEntry(),
      ], random: Random(5));
      final item = session.items.single;

      expect(
        item.matches('  ${item.acceptedTranslations.last.toUpperCase()} '),
        isTrue,
      );
    });

    test('does not ignore accents or diacritics', () {
      final session = PracticeSession.create([
        sampleEntry(portuguese: 'a maçã'),
      ], random: Random(5));
      final item = session.items.single;
      final incorrect =
          item.direction == TranslationDirection.germanToPortuguese
          ? 'a maca'
          : 'das Häus';

      expect(item.matches(incorrect), isFalse);
    });
  });

  test('selects at most 15 distinct entries and one result per item', () {
    final entries = List.generate(
      20,
      (index) => sampleEntry(id: 'entry-$index'),
    );
    final session = PracticeSession.create(entries, random: Random(10));

    expect(session.items, hasLength(15));
    expect(session.items.map((item) => item.entry.id).toSet(), hasLength(15));
    expect(session.completeItem(0, correct: true), isTrue);
    expect(session.completeItem(0, correct: false), isFalse);
    expect(session.completedCount, 1);
  });

  test('uses accuracy, recent mistakes, and elapsed days in the weight', () {
    final now = DateTime.utc(2026, 10, 25);
    expect(SelectionHistory.empty.selectionWeight(now: now), 5);
    expect(
      SelectionHistory.fromAttempts([
        SelectionAttempt(correct: false, completedAt: now),
        SelectionAttempt(
          correct: false,
          completedAt: now.subtract(const Duration(days: 1)),
        ),
        SelectionAttempt(
          correct: true,
          completedAt: now.subtract(const Duration(days: 2)),
        ),
        SelectionAttempt(
          correct: true,
          completedAt: now.subtract(const Duration(days: 3)),
        ),
        SelectionAttempt(
          correct: true,
          completedAt: now.subtract(const Duration(days: 4)),
        ),
        SelectionAttempt(
          correct: false,
          completedAt: now.subtract(const Duration(days: 5)),
        ),
        SelectionAttempt(
          correct: false,
          completedAt: now.subtract(const Duration(days: 6)),
        ),
        SelectionAttempt(
          correct: false,
          completedAt: now.subtract(const Duration(days: 7)),
        ),
      ]).selectionWeight(now: now),
      closeTo(1 + 4 * (1 - 3 / 8) + 4, 0.0001),
    );
    expect(
      SelectionHistory.fromAttempts([
        SelectionAttempt(
          correct: true,
          completedAt: now.subtract(const Duration(days: 2)),
        ),
      ]).selectionWeight(now: now),
      closeTo(1 + 2 / 7, 0.0001),
    );
  });

  test(
    'weighted draws favor missed entries and still select without repeats',
    () {
      final entries = [
        sampleEntry(id: 'well-practiced'),
        sampleEntry(id: 'often-missed'),
        ...List.generate(14, (index) => sampleEntry(id: 'other-$index')),
      ];
      final history = {
        'well-practiced': SelectionHistory.fromAttempts(
          List.filled(
            5,
            SelectionAttempt(
              correct: true,
              completedAt: DateTime.utc(2026, 10, 25),
            ),
          ),
        ),
        'often-missed': SelectionHistory.fromAttempts(
          List.filled(
            5,
            SelectionAttempt(
              correct: false,
              completedAt: DateTime.utc(2026, 10, 25),
            ),
          ),
        ),
        for (var index = 0; index < 14; index++)
          'other-$index': SelectionHistory.empty,
      };
      final session = PracticeSession.create(
        entries,
        practiceHistory: history,
        random: _ScriptedRandom([0.1]),
        now: DateTime.utc(2026, 10, 25),
      );

      final selectedIds = session.items.map((item) => item.entry.id).toList();
      expect(selectedIds, hasLength(15));
      expect(selectedIds.toSet(), hasLength(15));
      expect(selectedIds.first, 'often-missed');
    },
  );

  test('includes all entries when there are 15 or fewer', () {
    final entries = List.generate(
      15,
      (index) => sampleEntry(id: 'entry-$index'),
    );
    final session = PracticeSession.create(
      entries,
      practiceHistory: {
        for (final entry in entries)
          entry.id: SelectionHistory.fromAttempts([
            SelectionAttempt(
              correct: true,
              completedAt: DateTime.utc(2026, 10, 25),
            ),
          ]),
      },
      random: Random(19),
    );

    expect(session.items, hasLength(15));
    expect(session.items.map((item) => item.entry.id).toSet(), {
      for (final entry in entries) entry.id,
    });
  });

  test('does not repeat entries when input contains duplicate IDs', () {
    final first = sampleEntry(id: 'duplicate', german: 'das Haus');
    final duplicate = sampleEntry(id: 'duplicate', german: 'die Wohnung');
    final session = PracticeSession.create([
      first,
      duplicate,
    ], random: Random(12));

    expect(session.items, hasLength(1));
    expect(session.items.single.entry.german.primary, 'das Haus');
  });

  test('summarizes correct, incorrect and accuracy', () {
    final session = PracticeSession.create([
      sampleEntry(id: 'one'),
      sampleEntry(id: 'two'),
      sampleEntry(id: 'three'),
    ], random: Random(11));
    session.completeItem(0, correct: true);
    session.completeItem(1, correct: false);
    session.completeItem(2, correct: true);

    expect(session.summary.practiced, 3);
    expect(session.summary.correct, 2);
    expect(session.summary.incorrect, 1);
    expect(session.summary.accuracyPercent, closeTo(66.6667, 0.001));
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
