import 'dart:convert';

import 'conjugation.dart';

const grammarReferenceAssetPath = 'assets/grammar_reference.json';

class GrammarForm {
  const GrammarForm({required this.subject, required this.form});

  final String subject;
  final String form;

  static GrammarForm fromJson(Object? value, String path) {
    final object = _expectObject(value, path);
    _expectKeys(object, const {'subject', 'form'}, path);
    return GrammarForm(
      subject: _expectString(object['subject'], '$path.subject'),
      form: _expectString(object['form'], '$path.form'),
    );
  }
}

class GrammarVerbExample {
  const GrammarVerbExample({
    required this.verb,
    required this.classLabel,
    required this.forms,
  });

  final String verb;
  final String classLabel;
  final List<GrammarForm> forms;

  static GrammarVerbExample fromJson(Object? value, String path) {
    final object = _expectObject(value, path);
    _expectKeys(object, const {'verb', 'classLabel', 'forms'}, path);
    final rawForms = object['forms'];
    if (rawForms is! List<Object?> || rawForms.isEmpty) {
      throw FormatException('$path.forms must be a non-empty array.');
    }
    final forms = <GrammarForm>[];
    final subjects = <String>{};
    for (var index = 0; index < rawForms.length; index++) {
      final form = GrammarForm.fromJson(rawForms[index], '$path.forms[$index]');
      if (!subjects.add(form.subject)) {
        throw FormatException(
          '$path.forms contains duplicate subject "${form.subject}".',
        );
      }
      forms.add(form);
    }
    return GrammarVerbExample(
      verb: _expectString(object['verb'], '$path.verb'),
      classLabel: _expectString(object['classLabel'], '$path.classLabel'),
      forms: List.unmodifiable(forms),
    );
  }
}

class LanguageGrammarReference {
  const LanguageGrammarReference({
    required this.language,
    required this.regularRule,
    required this.regularExamples,
    required this.irregularExamples,
  });

  final ConjugationLanguage language;
  final String regularRule;
  final List<GrammarVerbExample> regularExamples;
  final List<GrammarVerbExample> irregularExamples;

  static LanguageGrammarReference fromJson(Object? value, String path) {
    final object = _expectObject(value, path);
    _expectKeys(object, const {
      'language',
      'regularRule',
      'regularExamples',
      'irregularExamples',
    }, path);
    final languageId = _expectString(object['language'], '$path.language');
    final language = ConjugationLanguage.fromId(languageId, '$path.language');
    final regular = _parseExamples(
      object['regularExamples'],
      '$path.regularExamples',
    );
    final irregular = _parseExamples(
      object['irregularExamples'],
      '$path.irregularExamples',
    );
    if (irregular.length < 3) {
      throw FormatException(
        '$path must include at least three irregular verbs.',
      );
    }
    final irregularVerbs = irregular.map((example) => example.verb).toSet();
    final requiredIrregularVerbs = language == ConjugationLanguage.german
        ? const {'sein', 'haben', 'werden'}
        : const {'ser', 'estar', 'ir'};
    if (!irregularVerbs.containsAll(requiredIrregularVerbs)) {
      throw FormatException(
        '$path must include the required common irregular verbs.',
      );
    }
    for (final example in [...regular, ...irregular]) {
      final subjects = example.forms.map((form) => form.subject).toSet();
      if (subjects.length != language.subjectIds.length ||
          !subjects.containsAll(language.subjectIds)) {
        throw FormatException(
          '$path example "${example.verb}" must include every supported '
          '${language.displayName} subject form exactly once.',
        );
      }
    }
    if (language == ConjugationLanguage.portuguese) {
      final classes = regular.map((example) => example.classLabel).toSet();
      if (!classes.containsAll(const {'-ar verb', '-er verb', '-ir verb'})) {
        throw FormatException(
          '$path must include a regular -ar, -er, and -ir verb.',
        );
      }
    } else if (regular.isEmpty) {
      throw FormatException('$path must include a regular German verb.');
    }
    return LanguageGrammarReference(
      language: language,
      regularRule: _expectString(object['regularRule'], '$path.regularRule'),
      regularExamples: List.unmodifiable(regular),
      irregularExamples: List.unmodifiable(irregular),
    );
  }

  static List<GrammarVerbExample> _parseExamples(Object? value, String path) {
    if (value is! List<Object?> || value.isEmpty) {
      throw FormatException('$path must be a non-empty array.');
    }
    final examples = <GrammarVerbExample>[];
    final verbs = <String>{};
    for (var index = 0; index < value.length; index++) {
      final example = GrammarVerbExample.fromJson(
        value[index],
        '$path[$index]',
      );
      if (!verbs.add(example.verb)) {
        throw FormatException(
          '$path contains duplicate verb "${example.verb}".',
        );
      }
      examples.add(example);
    }
    return examples;
  }
}

class GrammarReferenceDataset {
  const GrammarReferenceDataset(this.languages);

  final Map<ConjugationLanguage, LanguageGrammarReference> languages;

  LanguageGrammarReference forLanguage(ConjugationLanguage language) {
    final reference = languages[language];
    if (reference == null) {
      throw StateError('No grammar reference is available for ${language.id}.');
    }
    return reference;
  }

  static GrammarReferenceDataset fromJsonString(String source) {
    final decoded = jsonDecode(source);
    final object = _expectObject(decoded, r'$');
    _expectKeys(object, const {'languages'}, r'$');
    final rawLanguages = object['languages'];
    if (rawLanguages is! List<Object?>) {
      throw const FormatException(r'$.languages must be an array.');
    }
    final languages = <ConjugationLanguage, LanguageGrammarReference>{};
    for (var index = 0; index < rawLanguages.length; index++) {
      final reference = LanguageGrammarReference.fromJson(
        rawLanguages[index],
        r'$.languages['
        '$index]',
      );
      if (languages.containsKey(reference.language)) {
        throw FormatException(
          'Duplicate grammar language "${reference.language.id}".',
        );
      }
      languages[reference.language] = reference;
    }
    if (languages.length != ConjugationLanguage.values.length) {
      throw const FormatException(
        r'$.languages must include German and European Portuguese.',
      );
    }
    return GrammarReferenceDataset(Map.unmodifiable(languages));
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

String _expectString(Object? value, String path) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$path must be a non-empty string.');
  }
  return value;
}
