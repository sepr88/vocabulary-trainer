import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vocabulary_trainer/models/vocabulary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled vocabulary satisfies the strict schema and minimum count',
    () async {
      final source = await rootBundle.loadString('assets/vocabulary.json');
      final dataset = VocabularyDataset.fromJsonString(source);

      expect(dataset.version, 3);
      expect(dataset.entries, hasLength(100));
      expect(dataset.entries.map((entry) => entry.id).toSet(), hasLength(100));
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
    const source = '{"version":0,"entries":[]}';

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
      () =>
          VocabularyDataset.fromJsonString('{"version":1,"entries":[$entry]}'),
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
        '{"version":1,"entries":[$validEntry,$validEntry]}',
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
        '{"version":1,"entries":[$missingExample]}',
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
        '{"version":1,"entries":[$longExample]}',
      ),
      throwsFormatException,
    );
  });
}
