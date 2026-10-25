import 'package:flutter/services.dart';

import '../models/vocabulary.dart';
import '../models/conjugation.dart';
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

  final store = await (openStore ?? SqliteTrainerStore.open)();
  try {
    await store.reconcile(dataset);
    return store;
  } catch (_) {
    await store.close();
    rethrow;
  }
}
