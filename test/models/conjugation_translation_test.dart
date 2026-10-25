import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

void main() {
  test('requires an opposite-language translation in version 7 data', () {
    final validRecord = _conjugation();
    final dataset = _dataset([validRecord]);
    expect(dataset.conjugations.single.translation, 'ser');

    final missingTranslation = Map<String, Object?>.from(validRecord)
      ..remove('translation');
    expect(() => _dataset([missingTranslation]), throwsFormatException);

    expect(
      () => _dataset([
        {...validRecord, 'translation': '  '},
      ]),
      throwsFormatException,
    );
  });

  test('rejects unknown conjugation fields in version 7 data', () {
    expect(
      () => _dataset([
        {..._conjugation(), 'unexpected': true},
      ]),
      throwsFormatException,
    );
  });

  test('continues to parse legacy version 6 conjugations', () {
    final record = _conjugation()..remove('translation');
    final dataset = VocabularyDataset.fromJsonString(
      jsonEncode({
        'version': 6,
        'entries': [],
        'conjugations': [record],
      }),
    );

    expect(dataset.conjugations.single.translation, isEmpty);
  });
}

Map<String, Object?> _conjugation() => {
  'id': 'de-beginner-sein',
  'language': 'de',
  'level': 'beginner',
  'topic': 'daily-life-and-home',
  'infinitive': 'sein',
  'translation': 'ser',
  'tense': 'presentIndicative',
  'subjects': [
    for (final subject in ConjugationLanguage.german.subjectIds)
      {
        'id': subject,
        'primary': 'form',
        'accepted': ['form'],
      },
  ],
};

VocabularyDataset _dataset(List<Map<String, Object?>> conjugations) =>
    VocabularyDataset.fromJsonString(
      jsonEncode({'version': 7, 'entries': [], 'conjugations': conjugations}),
    );
