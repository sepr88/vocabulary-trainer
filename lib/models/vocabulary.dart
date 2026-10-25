import 'dart:convert';

import 'conjugation.dart';
import 'proficiency_level.dart';
import 'training_topic.dart';

export 'proficiency_level.dart';
export 'training_topic.dart';

class LanguageForm {
  const LanguageForm({required this.primary, required this.accepted});

  final String primary;
  final List<String> accepted;

  static LanguageForm fromJson(Object? value, String path) {
    final object = _expectObject(value, path);
    _expectKeys(object, const {'primary', 'accepted'}, path);
    final primary = _expectNonEmptyString(object['primary'], '$path.primary');
    final rawAccepted = object['accepted'];
    if (rawAccepted is! List<Object?> || rawAccepted.isEmpty) {
      throw FormatException('$path.accepted must be a non-empty array.');
    }
    final accepted = <String>[];
    for (var index = 0; index < rawAccepted.length; index++) {
      final translation = _expectNonEmptyString(
        rawAccepted[index],
        '$path.accepted[$index]',
      );
      if (accepted.contains(translation)) {
        throw FormatException(
          '$path.accepted contains duplicate translation "$translation".',
        );
      }
      accepted.add(translation);
    }
    if (!accepted.contains(primary)) {
      throw FormatException('$path.accepted must contain the primary value.');
    }
    return LanguageForm(
      primary: primary,
      accepted: List.unmodifiable(accepted),
    );
  }
}

class VocabularyEntry {
  const VocabularyEntry({
    required this.id,
    required this.level,
    this.topic = '',
    required this.german,
    required this.portuguese,
    required this.germanExample,
    required this.portugueseExample,
  });

  final String id;
  final ProficiencyLevel level;
  final String topic;
  final LanguageForm german;
  final LanguageForm portuguese;
  final String germanExample;
  final String portugueseExample;

  static VocabularyEntry fromJson(
    Object? value,
    String path, {
    bool requireTopic = false,
  }) {
    final object = _expectObject(value, path);
    final expectedKeys = {'id', 'level', 'de', 'pt-PT', 'examples'};
    if (requireTopic) expectedKeys.add('topic');
    _expectKeys(object, expectedKeys, path);
    final id = _expectNonEmptyString(object['id'], '$path.id');
    final levelValue = _expectNonEmptyString(object['level'], '$path.level');
    final level = switch (levelValue) {
      'beginner' => ProficiencyLevel.beginner,
      'advanced' => ProficiencyLevel.advanced,
      _ => throw FormatException('$path.level must be beginner or advanced.'),
    };
    final topic = object.containsKey('topic')
        ? _expectNonEmptyString(object['topic'], '$path.topic')
        : '';
    if (topic.isNotEmpty) {
      final topicDefinition = TrainingTopics.vocabularyById(topic);
      if (topicDefinition == null || topicDefinition.level != level) {
        throw FormatException(
          '$path.topic must be a known topic applicable to its level.',
        );
      }
    }
    final examples = _expectObject(object['examples'], '$path.examples');
    _expectKeys(examples, const {'de', 'pt-PT'}, '$path.examples');
    final germanExample = _expectExample(examples['de'], '$path.examples.de');
    final portugueseExample = _expectExample(
      examples['pt-PT'],
      '$path.examples.pt-PT',
    );
    return VocabularyEntry(
      id: id,
      level: level,
      topic: topic,
      german: LanguageForm.fromJson(object['de'], '$path.de'),
      portuguese: LanguageForm.fromJson(object['pt-PT'], '$path.pt-PT'),
      germanExample: germanExample,
      portugueseExample: portugueseExample,
    );
  }
}

class VocabularyDataset {
  const VocabularyDataset({
    required this.version,
    required this.entries,
    this.conjugations = const [],
  });

  final int version;
  final List<VocabularyEntry> entries;
  final List<ConjugationEntry> conjugations;

  static VocabularyDataset fromJsonString(String source) {
    final decoded = jsonDecode(source);
    final object = _expectObject(decoded, r'$');
    _expectKeys(object, const {'version', 'entries', 'conjugations'}, r'$');
    final version = object['version'];
    if (version is! int || version <= 0) {
      throw const FormatException(r'$.version must be a positive integer.');
    }
    final rawEntries = object['entries'];
    if (rawEntries is! List<Object?>) {
      throw const FormatException(r'$.entries must be an array.');
    }
    final entries = <VocabularyEntry>[];
    final ids = <String>{};
    for (var index = 0; index < rawEntries.length; index++) {
      final requireTopics = version >= 6;
      final entry = VocabularyEntry.fromJson(
        rawEntries[index],
        r'$.entries['
        '$index]',
        requireTopic: requireTopics,
      );
      if (!ids.add(entry.id)) {
        throw FormatException('Duplicate vocabulary ID "${entry.id}".');
      }
      entries.add(entry);
    }
    final rawConjugations = object['conjugations'];
    if (rawConjugations is! List<Object?>) {
      throw const FormatException(r'$.conjugations must be an array.');
    }
    final conjugations = <ConjugationEntry>[];
    final conjugationIds = <String>{};
    for (var index = 0; index < rawConjugations.length; index++) {
      final conjugation = ConjugationEntry.fromJson(
        rawConjugations[index],
        r'$.conjugations['
        '$index]',
        requireTopic: version >= 6,
        requireTranslation: version >= 7,
      );
      if (!conjugationIds.add(conjugation.id)) {
        throw FormatException('Duplicate conjugation ID "${conjugation.id}".');
      }
      conjugations.add(conjugation);
    }
    return VocabularyDataset(
      version: version,
      entries: List.unmodifiable(entries),
      conjugations: List.unmodifiable(conjugations),
    );
  }
}

Map<String, Object?> _expectObject(Object? value, String path) {
  if (value is! Map<String, Object?>) {
    throw FormatException('$path must be an object.');
  }
  return value;
}

void _expectKeys(
  Map<String, Object?> object,
  Set<String> expected,
  String path,
) {
  final missing = expected.difference(object.keys.toSet());
  final unknown = object.keys.toSet().difference(expected);
  if (missing.isNotEmpty || unknown.isNotEmpty) {
    throw FormatException(
      '$path has invalid fields; missing: ${missing.join(', ')}, '
      'unknown: ${unknown.join(', ')}.',
    );
  }
}

String _expectNonEmptyString(Object? value, String path) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$path must be a non-empty string.');
  }
  return value;
}

String _expectExample(Object? value, String path) {
  final example = _expectNonEmptyString(value, path);
  if (example.trim().split(RegExp(r'\s+')).length > 12) {
    throw FormatException('$path must contain no more than 12 words.');
  }
  return example;
}
