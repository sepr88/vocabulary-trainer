import 'package:flutter/services.dart';

import '../models/conjugation.dart';
import '../models/vocabulary.dart';
import 'trainer_store.dart';

const bundledVocabularyPath = 'assets/vocabulary.json';

Future<TrainerStore> initializeTrainerStore({
  Future<String> Function(String key)? loadAsset,
  Future<TrainerStore> Function()? openStore,
}) async {
  final source = await (loadAsset ?? rootBundle.loadString)(
    bundledVocabularyPath,
  );
  final dataset = VocabularyDataset.fromJsonString(source);
  if (dataset.version >= 6) {
    validateCompleteDataset(dataset);
  } else {
    _validateLegacyBundle(dataset);
  }

  final store = await (openStore ?? SqliteTrainerStore.open)();
  try {
    await store.reconcile(dataset);
    return store;
  } catch (_) {
    await store.close();
    rethrow;
  }
}

void _validateLegacyBundle(VocabularyDataset dataset) {
  if (dataset.entries.length < 100) {
    throw const FormatException(
      'The bundled vocabulary must contain at least 100 entries.',
    );
  }
  for (final language in ConjugationLanguage.values) {
    for (final level in ProficiencyLevel.values) {
      final entries = dataset.conjugations
          .where((entry) => entry.language == language && entry.level == level)
          .toList();
      final distinctVerbs = entries
          .map((entry) => entry.infinitive.trim().toLowerCase())
          .toSet()
          .length;
      if (distinctVerbs < 10) {
        throw FormatException(
          'The bundled dataset must contain at least 10 '
          '${language.id} ${level.name} conjugations.',
        );
      }
    }
  }
}

void validateCompleteDataset(VocabularyDataset dataset) {
  final distinctVocabulary = dataset.entries
      .map(
        (entry) =>
            '${entry.german.primary.trim().toLowerCase()}\u0000'
            '${entry.portuguese.primary.trim().toLowerCase()}',
      )
      .toSet()
      .length;
  if (distinctVocabulary < 200) {
    throw const FormatException(
      'The bundled vocabulary must contain at least 200 distinct entries.',
    );
  }
  for (final topic in TrainingTopics.vocabulary) {
    final count = dataset.entries
        .where((entry) => entry.topic == topic.id && entry.level == topic.level)
        .length;
    if (count < 10) {
      throw FormatException(
        'Vocabulary topic "${topic.id}" must contain at least 10 entries.',
      );
    }
  }

  for (final language in ConjugationLanguage.values) {
    for (final level in ProficiencyLevel.values) {
      final entries = dataset.conjugations
          .where((entry) => entry.language == language && entry.level == level)
          .toList();
      final distinctVerbs = entries
          .map((entry) => entry.infinitive.trim().toLowerCase())
          .toSet()
          .length;
      if (distinctVerbs < 30) {
        throw FormatException(
          'The bundled dataset must contain at least 30 distinct '
          '${language.id} ${level.name} verbs.',
        );
      }
      for (final topic in TrainingTopics.conjugation.where(
        (topic) => topic.level == level,
      )) {
        final topicCount = entries
            .where((entry) => entry.topic == topic.id)
            .map((entry) => entry.infinitive.trim().toLowerCase())
            .toSet()
            .length;
        if (topicCount < 10) {
          throw FormatException(
            'Conjugation topic "${topic.id}" must contain at least 10 '
            '${language.id} ${level.name} verbs.',
          );
        }
      }
    }
  }
}
