import 'dart:convert';

enum ProficiencyLevel { beginner, advanced }

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
    required this.german,
    required this.portuguese,
  });

  final String id;
  final ProficiencyLevel level;
  final LanguageForm german;
  final LanguageForm portuguese;

  static VocabularyEntry fromJson(Object? value, String path) {
    final object = _expectObject(value, path);
    _expectKeys(object, const {'id', 'level', 'de', 'pt-PT'}, path);
    final id = _expectNonEmptyString(object['id'], '$path.id');
    final levelValue = _expectNonEmptyString(object['level'], '$path.level');
    final level = switch (levelValue) {
      'beginner' => ProficiencyLevel.beginner,
      'advanced' => ProficiencyLevel.advanced,
      _ => throw FormatException('$path.level must be beginner or advanced.'),
    };
    return VocabularyEntry(
      id: id,
      level: level,
      german: LanguageForm.fromJson(object['de'], '$path.de'),
      portuguese: LanguageForm.fromJson(object['pt-PT'], '$path.pt-PT'),
    );
  }
}

class VocabularyDataset {
  const VocabularyDataset({required this.version, required this.entries});

  final int version;
  final List<VocabularyEntry> entries;

  static VocabularyDataset fromJsonString(String source) {
    final decoded = jsonDecode(source);
    final object = _expectObject(decoded, r'$');
    _expectKeys(object, const {'version', 'entries'}, r'$');
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
      final entry = VocabularyEntry.fromJson(
        rawEntries[index],
        r'$.entries['
        '$index]',
      );
      if (!ids.add(entry.id)) {
        throw FormatException('Duplicate vocabulary ID "${entry.id}".');
      }
      entries.add(entry);
    }
    return VocabularyDataset(
      version: version,
      entries: List.unmodifiable(entries),
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
