import '../models/conjugation.dart';
import '../models/vocabulary.dart';
import 'adaptive_selection.dart';
import 'conjugation_session.dart';

class TopicLearningProgress {
  const TopicLearningProgress({
    required this.topic,
    required this.successfulCandidates,
    required this.totalCandidates,
  });

  final TrainingTopic topic;
  final int successfulCandidates;
  final int totalCandidates;

  double get fraction =>
      totalCandidates == 0 ? 0 : successfulCandidates / totalCandidates;

  bool get isComplete =>
      totalCandidates > 0 && successfulCandidates == totalCandidates;
}

abstract final class LearningProgress {
  static List<TopicLearningProgress> vocabulary({
    required List<VocabularyEntry> entries,
    required Map<String, SelectionHistory> history,
  }) => List.unmodifiable([
    for (final topic in TrainingTopics.vocabulary)
      _vocabularyTopicProgress(topic, entries, history),
  ]);

  static List<TopicLearningProgress> conjugation({
    required List<ConjugationEntry> entries,
    required Map<ConjugationPromptKey, SelectionHistory> history,
    required ConjugationLanguage language,
    required ProficiencyLevel level,
  }) => List.unmodifiable([
    for (final topic in TrainingTopics.conjugation.where(
      (topic) => topic.level == level,
    ))
      _conjugationTopicProgress(topic, entries, history, language, level),
  ]);

  static TopicLearningProgress _vocabularyTopicProgress(
    TrainingTopic topic,
    List<VocabularyEntry> entries,
    Map<String, SelectionHistory> history,
  ) {
    final candidates = {
      for (final entry in entries)
        if (entry.topic == topic.id && entry.level == topic.level) entry.id,
    };
    final successful = candidates
        .where((id) => (history[id]?.correctAttemptCount ?? 0) > 0)
        .length;
    return TopicLearningProgress(
      topic: topic,
      successfulCandidates: successful,
      totalCandidates: candidates.length,
    );
  }

  static TopicLearningProgress _conjugationTopicProgress(
    TrainingTopic topic,
    List<ConjugationEntry> entries,
    Map<ConjugationPromptKey, SelectionHistory> history,
    ConjugationLanguage language,
    ProficiencyLevel level,
  ) {
    final candidates = <ConjugationPromptKey>{};
    for (final entry in entries) {
      if (entry.topic != topic.id ||
          entry.language != language ||
          entry.level != level) {
        continue;
      }
      for (final subject in entry.subjects) {
        candidates.add(ConjugationPromptKey(entry.id, subject.id));
      }
    }
    final successful = candidates
        .where(
          (candidate) => (history[candidate]?.correctAttemptCount ?? 0) > 0,
        )
        .length;
    return TopicLearningProgress(
      topic: topic,
      successfulCandidates: successful,
      totalCandidates: candidates.length,
    );
  }
}
