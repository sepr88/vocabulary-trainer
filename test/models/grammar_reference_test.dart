import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
import 'package:vocabulary_trainer/models/grammar_reference.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled grammar reference covers required paradigms and forms',
    () async {
      final source = await rootBundle.loadString(grammarReferenceAssetPath);
      final dataset = GrammarReferenceDataset.fromJsonString(source);
      final german = dataset.forLanguage(ConjugationLanguage.german);
      final portuguese = dataset.forLanguage(ConjugationLanguage.portuguese);

      expect(german.regularExamples, hasLength(1));
      expect(
        german.regularExamples.single.forms.map((form) => form.subject),
        ConjugationLanguage.german.subjectIds,
      );
      expect(
        german.irregularExamples.map((example) => example.verb),
        containsAll(['sein', 'haben', 'werden']),
      );
      expect(
        portuguese.regularExamples.map((example) => example.classLabel),
        containsAll(['-ar verb', '-er verb', '-ir verb']),
      );
      expect(
        portuguese.irregularExamples.map((example) => example.verb),
        containsAll(['ser', 'estar', 'ir']),
      );
      for (final example in [
        ...german.regularExamples,
        ...german.irregularExamples,
        ...portuguese.regularExamples,
        ...portuguese.irregularExamples,
      ]) {
        expect(
          example.forms.map((form) => form.subject).toSet(),
          containsAll(
            example.verb == 'falar' ||
                    example.verb == 'comer' ||
                    example.verb == 'abrir' ||
                    ['ser', 'estar', 'ir'].contains(example.verb)
                ? ConjugationLanguage.portuguese.subjectIds
                : ConjugationLanguage.german.subjectIds,
          ),
        );
        expect(
          example.forms.length,
          example.verb == 'falar' ||
                  example.verb == 'comer' ||
                  example.verb == 'abrir' ||
                  ['ser', 'estar', 'ir'].contains(example.verb)
              ? 5
              : 6,
        );
      }
      expect(
        portuguese.irregularExamples
            .singleWhere((example) => example.verb == 'ser')
            .forms
            .singleWhere((form) => form.subject == 'tu')
            .form,
        'és',
      );
    },
  );

  test('rejects a grammar example with incomplete subject forms', () {
    const source = '''
      {
        "languages": [
          {
            "language": "de",
            "regularRule": "Rule",
            "regularExamples": [
              {
                "verb": "machen",
                "classLabel": "Regular",
                "forms": [{"subject":"ich","form":"mache"}]
              }
            ],
            "irregularExamples": [
              {"verb":"sein","classLabel":"To be","forms":[]},
              {"verb":"haben","classLabel":"To have","forms":[]},
              {"verb":"werden","classLabel":"To become","forms":[]}
            ]
          }
        ]
      }
    ''';
    expect(
      () => GrammarReferenceDataset.fromJsonString(source),
      throwsFormatException,
    );
  });
}
