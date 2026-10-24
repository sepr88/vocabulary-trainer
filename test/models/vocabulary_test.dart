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

      expect(dataset.version, 1);
      expect(dataset.entries, hasLength(100));
      expect(dataset.entries.map((entry) => entry.id).toSet(), hasLength(100));
      expect(
        dataset.entries.map((entry) => entry.level).toSet(),
        containsAll(ProficiencyLevel.values),
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
        "pt-PT":{"primary":"casa","accepted":["casa"]}
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
        "pt-PT":{"primary":"casa","accepted":["casa"]}
      }
    ''';
    expect(
      () => VocabularyDataset.fromJsonString(
        '{"version":1,"entries":[$validEntry,$validEntry]}',
      ),
      throwsFormatException,
    );
  });
}
