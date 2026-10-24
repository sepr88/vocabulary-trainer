import 'package:flutter/services.dart';

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
  if (dataset.entries.length < 100) {
    throw const FormatException(
      'The bundled vocabulary must contain at least 100 entries.',
    );
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
