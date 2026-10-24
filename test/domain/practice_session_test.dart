import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/domain/practice_session.dart';

import '../support/fixtures.dart';

void main() {
  group('PracticeItem', () {
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
