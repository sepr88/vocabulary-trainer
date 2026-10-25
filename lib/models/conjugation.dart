import 'dart:convert';

import 'proficiency_level.dart';
import 'training_topic.dart';

enum ConjugationLanguage {
  german('de', 'German'),
  portuguese('pt-PT', 'Portuguese');

  const ConjugationLanguage(this.id, this.displayName);

  final String id;
  final String displayName;

  List<String> get subjectIds => switch (this) {
    ConjugationLanguage.german => const [
      'ich',
      'du',
      'er/sie/es',
      'wir',
      'ihr',
      'sie/Sie',
    ],
    ConjugationLanguage.portuguese => const [
      'eu',
      'tu',
      'ele/ela/você',
      'nós',
      'vocês/eles/elas',
    ],
  };

  static ConjugationLanguage fromId(String id, String path) => switch (id) {
    'de' => ConjugationLanguage.german,
    'pt-PT' => ConjugationLanguage.portuguese,
    _ => throw FormatException('$path must be de or pt-PT.'),
  };
}

class ConjugationSubject {
  const ConjugationSubject({
    required this.id,
    required this.primary,
    required this.accepted,
  });

  final String id;
  final String primary;
  final List<String> accepted;

  static ConjugationSubject fromJson(Object? value, String path) {
    final object = _expectObject(value, path);
    _expectKeys(object, const {'id', 'primary', 'accepted'}, path);
    final id = _expectNonEmptyString(object['id'], '$path.id');
    final primary = _expectNonEmptyString(object['primary'], '$path.primary');
    final rawAccepted = object['accepted'];
    if (rawAccepted is! List<Object?> || rawAccepted.isEmpty) {
      throw FormatException('$path.accepted must be a non-empty array.');
    }
    final accepted = <String>[];
    for (var index = 0; index < rawAccepted.length; index++) {
      final form = _expectNonEmptyString(
        rawAccepted[index],
        '$path.accepted[$index]',
      );
      if (accepted.contains(form)) {
        throw FormatException(
          '$path.accepted contains duplicate form "$form".',
        );
      }
      accepted.add(form);
    }
    if (!accepted.contains(primary)) {
      throw FormatException('$path.accepted must contain the primary form.');
    }
    return ConjugationSubject(
      id: id,
      primary: primary,
      accepted: List.unmodifiable(accepted),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'primary': primary,
    'accepted': accepted,
  };
}

class ConjugationEntry {
  const ConjugationEntry({
    required this.id,
    required this.language,
    required this.level,
    this.topic = '',
    required this.infinitive,
    this.translation = '',
    required this.tense,
    required this.subjects,
  });

  final String id;
  final ConjugationLanguage language;
  final ProficiencyLevel level;
  final String topic;
  final String infinitive;
  final String translation;
  final String tense;
  final List<ConjugationSubject> subjects;

  static ConjugationEntry fromJson(
    Object? value,
    String path, {
    bool requireTopic = false,
    bool requireTranslation = false,
  }) {
    final object = _expectObject(value, path);
    final expectedKeys = <String>{
      'id',
      'language',
      'level',
      'infinitive',
      'tense',
      'subjects',
    };
    if (requireTopic) expectedKeys.add('topic');
    if (requireTranslation) expectedKeys.add('translation');
    _expectKeys(object, expectedKeys, path);
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
      final topicDefinition = TrainingTopics.conjugationById(topic);
      if (topicDefinition == null || topicDefinition.level != level) {
        throw FormatException(
          '$path.topic must be a known topic applicable to its level.',
        );
      }
    }
    final tense = _expectNonEmptyString(object['tense'], '$path.tense');
    if (tense != 'presentIndicative') {
      throw FormatException('$path.tense must be presentIndicative.');
    }
    final rawSubjects = object['subjects'];
    if (rawSubjects is! List<Object?> || rawSubjects.isEmpty) {
      throw FormatException('$path.subjects must be a non-empty array.');
    }
    final subjects = <ConjugationSubject>[];
    final subjectIds = <String>{};
    for (var index = 0; index < rawSubjects.length; index++) {
      final subject = ConjugationSubject.fromJson(
        rawSubjects[index],
        '$path.subjects[$index]',
      );
      if (!subjectIds.add(subject.id)) {
        throw FormatException(
          '$path contains duplicate subject ID "${subject.id}".',
        );
      }
      subjects.add(subject);
    }
    final language = ConjugationLanguage.fromId(
      _expectNonEmptyString(object['language'], '$path.language'),
      '$path.language',
    );
    final translation = requireTranslation || object.containsKey('translation')
        ? _expectNonEmptyString(object['translation'], '$path.translation')
        : '';
    if (!subjectIds.containsAll(language.subjectIds) ||
        subjectIds.length != language.subjectIds.length) {
      throw FormatException(
        '$path.subjects must contain the supported '
        '${language.displayName} subject forms.',
      );
    }
    return ConjugationEntry(
      id: _expectNonEmptyString(object['id'], '$path.id'),
      language: language,
      level: level,
      topic: topic,
      infinitive: _expectNonEmptyString(
        object['infinitive'],
        '$path.infinitive',
      ),
      translation: translation,
      tense: tense,
      subjects: List.unmodifiable(subjects),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'language': language.id,
    'level': level.name,
    'topic': topic,
    'infinitive': infinitive,
    'translation': translation,
    'tense': tense,
    'subjects': subjects.map((subject) => subject.toJson()).toList(),
  };
}

String encodeConjugationSubjects(List<ConjugationSubject> subjects) =>
    jsonEncode(subjects.map((subject) => subject.toJson()).toList());

List<ConjugationSubject> decodeConjugationSubjects(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List<Object?>) {
    throw const FormatException(
      'Stored conjugation subjects must be an array.',
    );
  }
  return List.unmodifiable([
    for (var index = 0; index < decoded.length; index++)
      ConjugationSubject.fromJson(decoded[index], 'subjects[$index]'),
  ]);
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
