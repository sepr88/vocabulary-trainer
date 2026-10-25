import 'dart:math';

class SelectionAttempt {
  const SelectionAttempt({required this.correct, required this.completedAt});

  final bool correct;
  final DateTime completedAt;
}

class SelectionHistory {
  SelectionHistory({
    required this.attemptCount,
    required this.correctAttemptCount,
    required List<bool> mostRecentResults,
    required this.lastAttemptAt,
  }) : mostRecentResults = List.unmodifiable(mostRecentResults.take(5));

  factory SelectionHistory.fromAttempts(Iterable<SelectionAttempt> attempts) {
    final indexed = attempts.toList().asMap().entries.toList()
      ..sort((left, right) {
        final byTime = right.value.completedAt.compareTo(
          left.value.completedAt,
        );
        return byTime == 0 ? left.key.compareTo(right.key) : byTime;
      });
    final ordered = indexed.map((entry) => entry.value).toList();
    return SelectionHistory(
      attemptCount: ordered.length,
      correctAttemptCount: ordered.where((attempt) => attempt.correct).length,
      mostRecentResults: ordered
          .take(5)
          .map((attempt) => attempt.correct)
          .toList(),
      lastAttemptAt: ordered.isEmpty ? null : ordered.first.completedAt,
    );
  }

  static final empty = SelectionHistory(
    attemptCount: 0,
    correctAttemptCount: 0,
    mostRecentResults: const [],
    lastAttemptAt: null,
  );

  final int attemptCount;
  final int correctAttemptCount;
  final List<bool> mostRecentResults;
  final DateTime? lastAttemptAt;

  double selectionWeight({required DateTime now}) {
    final accuracy = attemptCount == 0
        ? 0.0
        : correctAttemptCount / attemptCount;
    final recentIncorrect = mostRecentResults
        .where((correct) => !correct)
        .length;
    final elapsedDays = lastAttemptAt == null
        ? 0.0
        : max(0, now.difference(lastAttemptAt!).inMicroseconds) /
              Duration.microsecondsPerDay;
    return 1 +
        4 * (1 - accuracy) +
        2 * min(recentIncorrect, 3) +
        min(elapsedDays / 7, 3);
  }
}

List<T> weightedSelection<T>({
  required List<T> candidates,
  required SelectionHistory Function(T candidate) historyFor,
  required Random random,
  required DateTime now,
  int limit = 15,
}) {
  final remaining = List<T>.of(candidates);
  if (remaining.length <= limit) {
    return remaining..shuffle(random);
  }

  final selected = <T>[];
  while (selected.length < limit) {
    final weights = remaining
        .map((candidate) => historyFor(candidate).selectionWeight(now: now))
        .toList();
    final totalWeight = weights.fold<double>(0, (sum, weight) => sum + weight);
    final draw = random.nextDouble() * totalWeight;
    var cumulativeWeight = 0.0;
    var selectedIndex = -1;
    for (var index = 0; index < weights.length; index++) {
      cumulativeWeight += weights[index];
      if (draw < cumulativeWeight) {
        selectedIndex = index;
        break;
      }
    }
    if (selectedIndex < 0) {
      throw StateError(
        'The weighted practice draw did not select a candidate.',
      );
    }
    selected.add(remaining.removeAt(selectedIndex));
  }
  return selected;
}
