import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled vocabulary satisfies the strict schema and minimum count',
    () async {
      final source = await rootBundle.loadString('assets/vocabulary.json');
      final dataset = VocabularyDataset.fromJsonString(source);

      expect(dataset.version, 7);
      expect(dataset.entries.length, greaterThanOrEqualTo(200));
      expect(
        dataset.entries.map((entry) => entry.id).toSet(),
        hasLength(dataset.entries.length),
      );
      expect(dataset.conjugations.length, greaterThanOrEqualTo(120));
      for (final language in ConjugationLanguage.values) {
        for (final level in ProficiencyLevel.values) {
          expect(
            dataset.conjugations
                .where(
                  (entry) => entry.language == language && entry.level == level,
                )
                .map((entry) => entry.infinitive.toLowerCase())
                .toSet()
                .length,
            greaterThanOrEqualTo(30),
          );
          for (final topic in TrainingTopics.conjugation.where(
            (topic) => topic.level == level,
          )) {
            expect(
              dataset.conjugations
                  .where(
                    (entry) =>
                        entry.language == language &&
                        entry.level == level &&
                        entry.topic == topic.id,
                  )
                  .map((entry) => entry.infinitive.toLowerCase())
                  .toSet()
                  .length,
              greaterThanOrEqualTo(10),
            );
          }
        }
      }
      for (final topic in TrainingTopics.vocabulary) {
        expect(
          dataset.entries
              .where(
                (entry) =>
                    entry.topic == topic.id && entry.level == topic.level,
              )
              .length,
          greaterThanOrEqualTo(10),
        );
      }
      final portugueseSer = dataset.conjugations.singleWhere(
        (entry) => entry.id == 'pt-PT-beginner-ser',
      );
      expect(portugueseSer.subjects.map((subject) => subject.id), [
        'eu',
        'tu',
        'ele/ela/você',
        'nós',
        'vocês/eles/elas',
      ]);
      expect(
        portugueseSer.subjects
            .singleWhere((subject) => subject.id == 'tu')
            .primary,
        'és',
      );
      expect(
        dataset.conjugations
            .singleWhere((entry) => entry.id == 'de-beginner-sein')
            .subjects
            .map((subject) => subject.id),
        ['ich', 'du', 'er/sie/es', 'wir', 'ihr', 'sie/Sie'],
      );
      final door = dataset.entries.singleWhere((entry) => entry.id == 'de-004');
      expect(door.germanExample, 'Die Tür ist offen.');
      expect(door.portugueseExample, 'A porta está aberta.');
      expect(door.germanExample.codeUnits, contains(0x00fc));
      expect(door.portugueseExample.codeUnits, contains(0x00e1));
      expect(
        dataset.entries.map((entry) => entry.level).toSet(),
        containsAll(ProficiencyLevel.values),
      );
      expect(
        dataset.entries.every(
          (entry) =>
              entry.germanExample.isNotEmpty &&
              entry.portugueseExample.isNotEmpty &&
              entry.germanExample.trim().split(RegExp(r'\s+')).length <= 12 &&
              entry.portugueseExample.trim().split(RegExp(r'\s+')).length <= 12,
        ),
        isTrue,
      );
    },
  );

  test('rejects unknown fields', () {
    const source = '''
      {
        "version": 1,
        "entries": [],
        "unexpected": true
      }
    ''';

    expect(
      () => VocabularyDataset.fromJsonString(source),
      throwsFormatException,
    );
  });

  test('rejects a non-positive version', () {
    const source = '{"version":0,"entries":[],"conjugations":[]}';

    expect(
      () => VocabularyDataset.fromJsonString(source),
      throwsFormatException,
    );
  });

  test('rejects duplicate IDs and duplicate accepted translations', () {
    const entry = '''
      {
        "id":"same",
        "level":"beginner",
        "de":{"primary":"Haus","accepted":["Haus","Haus"]},
        "pt-PT":{"primary":"casa","accepted":["casa"]},
        "examples":{"de":"Das Haus ist wichtig.","pt-PT":"A casa é importante."}
      }
    ''';
    expect(
      () => VocabularyDataset.fromJsonString(
        '{"version":1,"entries":[$entry],"conjugations":[]}',
      ),
      throwsFormatException,
    );

    const validEntry = '''
      {
        "id":"same",
        "level":"beginner",
        "de":{"primary":"Haus","accepted":["Haus"]},
        "pt-PT":{"primary":"casa","accepted":["casa"]},
        "examples":{"de":"Das Haus ist wichtig.","pt-PT":"A casa é importante."}
      }
    ''';
    expect(
      () => VocabularyDataset.fromJsonString(
        '{"version":1,"entries":[$validEntry,$validEntry],"conjugations":[]}',
      ),
      throwsFormatException,
    );
  });

  test('requires valid short examples in both languages', () {
    const missingExample =
        '{"id":"one","level":"beginner","de":{"primary":"Haus","accepted":["Haus"]},'
        '"pt-PT":{"primary":"casa","accepted":["casa"]}}';
    expect(
      () => VocabularyDataset.fromJsonString(
        '{"version":1,"entries":[$missingExample],"conjugations":[]}',
      ),
      throwsFormatException,
    );

    const longExample = '''
      {
        "id":"one",
        "level":"beginner",
        "de":{"primary":"Haus","accepted":["Haus"]},
        "pt-PT":{"primary":"casa","accepted":["casa"]},
        "examples":{
          "de":"Das Haus ist sehr wichtig für alle Menschen in der ganzen Stadt jeden Tag.",
          "pt-PT":"A casa é muito importante."
        }
      }
    ''';
    expect(
      () => VocabularyDataset.fromJsonString(
        '{"version":1,"entries":[$longExample],"conjugations":[]}',
      ),
      throwsFormatException,
    );
  });

  test('validates conjugation subject IDs and tense', () {
    const duplicateSubjects = '''
      {
        "id":"de-beginner-test",
        "language":"de",
        "level":"beginner",
        "infinitive":"sein",
        "tense":"presentIndicative",
        "subjects":[
          {"id":"ich","primary":"bin","accepted":["bin"]},
          {"id":"ich","primary":"bin","accepted":["bin"]}
        ]
      }
    ''';
    expect(
      () => VocabularyDataset.fromJsonString(
        '{"version":1,"entries":[],"conjugations":[$duplicateSubjects]}',
      ),
      throwsFormatException,
    );

    const invalidTense = '''
      {
        "id":"de-beginner-test",
        "language":"de",
        "level":"beginner",
        "infinitive":"sein",
        "tense":"past",
        "subjects":[{"id":"ich","primary":"bin","accepted":["bin"]}]
      }
    ''';
    expect(
      () => VocabularyDataset.fromJsonString(
        '{"version":1,"entries":[],"conjugations":[$invalidTense]}',
      ),
      throwsFormatException,
    );
  });
}
