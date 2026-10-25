import 'package:vocabulary_trainer/models/vocabulary.dart';

VocabularyEntry sampleEntry({
  String id = 'sample-1',
  String german = 'das Haus',
  String portuguese = 'a casa',
}) {
  return VocabularyEntry(
    id: id,
    level: ProficiencyLevel.beginner,
    germanExample: 'Das Haus ist wichtig.',
    portugueseExample: 'A casa é importante.',
    german: LanguageForm(
      primary: german,
      accepted: [german, german.replaceAll(RegExp(r'^(der|die|das) '), '')],
    ),
    portuguese: LanguageForm(
      primary: portuguese,
      accepted: [portuguese, portuguese.replaceAll(RegExp(r'^(o|a) '), '')],
    ),
  );
}

VocabularyDataset sampleDataset({
  int version = 1,
  List<VocabularyEntry>? entries,
}) {
  return VocabularyDataset(
    version: version,
    entries: entries ?? [sampleEntry()],
  );
}
