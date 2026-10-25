import 'package:vocabulary_trainer/models/vocabulary.dart';
import 'package:vocabulary_trainer/models/conjugation.dart';

VocabularyEntry sampleEntry({
  String id = 'sample-1',
  String german = 'das Haus',
  String portuguese = 'a casa',
  String germanExample = 'Das Haus ist wichtig.',
  String portugueseExample = 'A casa é importante.',
}) {
  return VocabularyEntry(
    id: id,
    level: ProficiencyLevel.beginner,
    germanExample: germanExample,
    portugueseExample: portugueseExample,
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
  List<ConjugationEntry> conjugations = const [],
}) {
  return VocabularyDataset(
    version: version,
    entries: entries ?? [sampleEntry()],
    conjugations: conjugations,
  );
}

ConjugationEntry sampleConjugation({
  String id = 'de-beginner-sein',
  ConjugationLanguage language = ConjugationLanguage.german,
  ProficiencyLevel level = ProficiencyLevel.beginner,
  String infinitive = 'sein',
  List<ConjugationSubject>? subjects,
}) {
  return ConjugationEntry(
    id: id,
    language: language,
    level: level,
    infinitive: infinitive,
    tense: 'presentIndicative',
    subjects:
        subjects ??
        const [
          ConjugationSubject(id: 'ich', primary: 'bin', accepted: ['bin']),
          ConjugationSubject(id: 'du', primary: 'bist', accepted: ['bist']),
        ],
  );
}
