import 'dart:math';

import 'adaptive_selection.dart';
import '../models/conjugation.dart';
import '../models/vocabulary.dart';
import 'practice_session.dart';

class ConjugationPromptKey {
  const ConjugationPromptKey(this.conjugationId, this.subjectId);

  final String conjugationId;
  final String subjectId;

  @override
  bool operator ==(Object other) =>
      other is ConjugationPromptKey &&
      other.conjugationId == conjugationId &&
      other.subjectId == subjectId;

  @override
  int get hashCode => Object.hash(conjugationId, subjectId);
}

class ConjugationPrompt {
  const ConjugationPrompt({
    required this.attemptId,
    required this.entry,
    required this.subject,
  });

  final String attemptId;
  final ConjugationEntry entry;
  final ConjugationSubject subject;

  String get prompt => '${entry.infinitive} · ${subject.id}';

  bool matches(String answer) {
    final normalized = normalizeAnswer(answer);
    return subject.accepted.any((form) => normalizeAnswer(form) == normalized);
  }
}

class ConjugationSession {
  ConjugationSession._(this.language, this.level, this.prompts);

  final ConjugationLanguage language;
  final ProficiencyLevel level;
  final List<ConjugationPrompt> prompts;
  final Map<int, bool> _results = {};

  static ConjugationSession create(
    List<ConjugationEntry> entries, {
    required ConjugationLanguage language,
    required ProficiencyLevel level,
    String? topicId,
    Map<ConjugationPromptKey, SelectionHistory> practiceHistory = const {},
    Random? random,
    DateTime? now,
  }) {
    final randomizer = random ?? Random.secure();
    final selected = entries
        .where(
          (entry) =>
              entry.language == language &&
              entry.level == level &&
              (topicId == null || entry.topic == topicId),
        )
        .toList();
    if (selected.isEmpty) {
      throw StateError(
        'No ${language.displayName} ${level.name} conjugations are available.',
      );
    }
    final candidates = [
      for (final entry in selected)
        for (final subject in entry.subjects) (entry: entry, subject: subject),
    ];
    final prompts = weightedSelection(
      candidates: candidates,
      historyFor: (candidate) =>
          practiceHistory[ConjugationPromptKey(
            candidate.entry.id,
            candidate.subject.id,
          )] ??
          SelectionHistory.empty,
      random: randomizer,
      now: now ?? DateTime.now(),
    );
    final sessionId = List<int>.generate(
      16,
      (_) => randomizer.nextInt(256),
    ).map((part) => part.toRadixString(16).padLeft(2, '0')).join();
    return ConjugationSession._(
      language,
      level,
      List.unmodifiable([
        for (var index = 0; index < prompts.length; index++)
          ConjugationPrompt(
            attemptId: '$sessionId:$index',
            entry: prompts[index].entry,
            subject: prompts[index].subject,
          ),
      ]),
    );
  }

  bool completePrompt(int index, {required bool correct}) {
    if (index < 0 || index >= prompts.length) {
      throw RangeError.index(index, prompts, 'index');
    }
    if (_results.containsKey(index)) return false;
    _results[index] = correct;
    return true;
  }

  bool isCompleted(int index) => _results.containsKey(index);

  SessionSummary get summary => SessionSummary.fromResults(_results.values);
}
