import 'dart:math';

import '../models/vocabulary.dart';

enum TranslationDirection { germanToPortuguese, portugueseToGerman }

class PracticeItem {
  const PracticeItem({
    required this.attemptId,
    required this.entry,
    required this.direction,
  });

  final String attemptId;
  final VocabularyEntry entry;
  final TranslationDirection direction;

  String get prompt => switch (direction) {
    TranslationDirection.germanToPortuguese => entry.german.primary,
    TranslationDirection.portugueseToGerman => entry.portuguese.primary,
  };

  String get primaryTranslation => switch (direction) {
    TranslationDirection.germanToPortuguese => entry.portuguese.primary,
    TranslationDirection.portugueseToGerman => entry.german.primary,
  };

  List<String> get acceptedTranslations => switch (direction) {
    TranslationDirection.germanToPortuguese => entry.portuguese.accepted,
    TranslationDirection.portugueseToGerman => entry.german.accepted,
  };

  bool matches(String answer) {
    final normalized = normalizeAnswer(answer);
    return acceptedTranslations.any(
      (translation) => normalizeAnswer(translation) == normalized,
    );
  }
}

class PracticeSession {
  PracticeSession._(this.items);

  final List<PracticeItem> items;
  final Map<int, bool> _results = {};

  static PracticeSession create(
    List<VocabularyEntry> entries, {
    Random? random,
  }) {
    final randomizer = random ?? Random.secure();
    final distinctEntries = <String, VocabularyEntry>{};
    for (final entry in entries) {
      distinctEntries.putIfAbsent(entry.id, () => entry);
    }
    final shuffled = distinctEntries.values.toList()..shuffle(randomizer);
    final selected = shuffled.take(15).toList(growable: false);
    final sessionId = List<int>.generate(
      16,
      (_) => randomizer.nextInt(256),
    ).map((part) => part.toRadixString(16).padLeft(2, '0')).join();
    final items = List<PracticeItem>.generate(selected.length, (index) {
      return PracticeItem(
        attemptId: '$sessionId:$index',
        entry: selected[index],
        direction: randomizer.nextBool()
            ? TranslationDirection.germanToPortuguese
            : TranslationDirection.portugueseToGerman,
      );
    }, growable: false);
    return PracticeSession._(items);
  }

  bool completeItem(int index, {required bool correct}) {
    if (index < 0 || index >= items.length) {
      throw RangeError.index(index, items, 'index');
    }
    if (_results.containsKey(index)) return false;
    _results[index] = correct;
    return true;
  }

  bool isCompleted(int index) => _results.containsKey(index);

  int get completedCount => _results.length;

  SessionSummary get summary => SessionSummary.fromResults(_results.values);
}

class SessionSummary {
  const SessionSummary({
    required this.practiced,
    required this.correct,
    required this.incorrect,
  });

  final int practiced;
  final int correct;
  final int incorrect;

  double get accuracyPercent => practiced == 0 ? 0 : correct * 100 / practiced;

  factory SessionSummary.fromResults(Iterable<bool> results) {
    var correct = 0;
    var incorrect = 0;
    for (final result in results) {
      if (result) {
        correct++;
      } else {
        incorrect++;
      }
    }
    return SessionSummary(
      practiced: correct + incorrect,
      correct: correct,
      incorrect: incorrect,
    );
  }
}

String normalizeAnswer(String answer) => answer.trim().toLowerCase();
