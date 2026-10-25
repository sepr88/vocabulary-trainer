import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/data/bootstrap.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled dataset satisfies topic and per-level completeness', () async {
    final source = await rootBundle.loadString('assets/vocabulary.json');
    final dataset = VocabularyDataset.fromJsonString(source);

    expect(dataset.version, 6);
    expect(dataset.entries.length, greaterThanOrEqualTo(200));
    expect(
      dataset.entries
          .map((entry) => entry.german.primary.toLowerCase())
          .toSet(),
      hasLength(dataset.entries.length),
    );
    expect(
      dataset.entries
          .map((entry) => entry.portuguese.primary.toLowerCase())
          .toSet(),
      hasLength(dataset.entries.length),
    );
    expect(() => validateCompleteDataset(dataset), returnsNormally);
    for (final topic in TrainingTopics.vocabulary) {
      expect(
        dataset.entries.where(
          (entry) => entry.topic == topic.id && entry.level == topic.level,
        ),
        hasLength(greaterThanOrEqualTo(10)),
      );
    }
    for (final language in ConjugationLanguage.values) {
      for (final level in ProficiencyLevel.values) {
        final verbs = dataset.conjugations
            .where(
              (entry) => entry.language == language && entry.level == level,
            )
            .toList();
        expect(
          verbs.map((entry) => entry.infinitive).toSet(),
          hasLength(greaterThanOrEqualTo(30)),
        );
        for (final topic in TrainingTopics.conjugation.where(
          (topic) => topic.level == level,
        )) {
          expect(
            verbs
                .where((entry) => entry.topic == topic.id)
                .map((entry) => entry.infinitive)
                .toSet(),
            hasLength(greaterThanOrEqualTo(10)),
          );
        }
      }
    }
    expect(
      dataset.entries.every(
        (entry) =>
            entry.germanExample.trim().split(RegExp(r'\s+')).length <= 12 &&
            entry.portugueseExample.trim().split(RegExp(r'\s+')).length <= 12,
      ),
      isTrue,
    );
  });

  test('strict current-version parsing requires known topic fields', () async {
    final source = await rootBundle.loadString('assets/vocabulary.json');
    final dataset = VocabularyDataset.fromJsonString(source);
    const entry = {
      'id': 'one',
      'level': 'beginner',
      'de': {
        'primary': 'das Haus',
        'accepted': ['das Haus'],
      },
      'pt-PT': {
        'primary': 'a casa',
        'accepted': ['a casa'],
      },
      'examples': {'de': 'Hier ist das Haus.', 'pt-PT': 'Aqui está a casa.'},
    };

    expect(
      () => VocabularyDataset.fromJsonString(
        jsonEncode({
          'version': 6,
          'entries': [entry],
          'conjugations': [],
        }),
      ),
      throwsFormatException,
    );
    expect(
      () => VocabularyDataset.fromJsonString(
        jsonEncode({
          'version': 6,
          'entries': [
            {...entry, 'topic': 'not-a-topic'},
          ],
          'conjugations': [],
        }),
      ),
      throwsFormatException,
    );

    final decoded = jsonDecode(source) as Map<String, Object?>;
    final conjugations = decoded['conjugations']! as List<Object?>;
    final firstConjugation = Map<String, Object?>.from(
      conjugations.first! as Map,
    )..remove('topic');
    expect(
      () => VocabularyDataset.fromJsonString(
        jsonEncode({
          ...decoded,
          'conjugations': [firstConjugation, ...conjugations.skip(1)],
        }),
      ),
      throwsFormatException,
    );

    final germanDeparture = dataset.conjugations.singleWhere(
      (entry) => entry.id == 'de-beginner-abfahren',
    );
    expect(
      germanDeparture.subjects
          .singleWhere((subject) => subject.id == 'du')
          .primary,
      'fährst ab',
    );
    final portugueseGrowth = dataset.conjugations.singleWhere(
      (entry) => entry.id == 'pt-PT-advanced-crescer',
    );
    expect(
      portugueseGrowth.subjects
          .singleWhere((subject) => subject.id == 'vocês/eles/elas')
          .primary,
      'crescem',
    );
    final portugueseProduction = dataset.conjugations.singleWhere(
      (entry) => entry.id == 'pt-PT-advanced-produzir',
    );
    expect(
      portugueseProduction.subjects
          .singleWhere((subject) => subject.id == 'ele/ela/você')
          .primary,
      'produz',
    );
    final separableVerb = dataset.conjugations.singleWhere(
      (entry) => entry.id == 'de-beginner-ankommen',
    );
    expect(
      separableVerb.subjects
          .singleWhere((subject) => subject.id == 'ich')
          .primary,
      'komme an',
    );
  });

  test('complete validator rejects insufficient topic coverage', () async {
    final source = await rootBundle.loadString('assets/vocabulary.json');
    final dataset = VocabularyDataset.fromJsonString(source);
    final incomplete = VocabularyDataset(
      version: dataset.version,
      entries: dataset.entries
          .where((entry) => entry.topic != 'family-and-people')
          .toList(),
      conjugations: dataset.conjugations,
    );

    expect(() => validateCompleteDataset(incomplete), throwsFormatException);
  });
}
