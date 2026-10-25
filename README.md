# Vocabulary Trainer

An offline-first Flutter app for German speakers learning European Portuguese
and Portuguese speakers learning German.

## Features

- Practice sessions use up to 15 distinct items, selected adaptively based on
  past practice.
- Choose **All topics** or a topic for the current session. Vocabulary topics
  are grouped by beginner and advanced level; conjugation topics are available
  for the selected level.
- Practice German–European Portuguese vocabulary or German/Portuguese
  present-indicative conjugations.
- Translation direction is chosen independently for each question.
- Answers ignore leading/trailing whitespace and letter case, but preserve
  accents and diacritics.
- Reveal the primary translation when you need help; revealed answers count as
  incorrect.
- In conjugation practice, the infinitive's translation remains hidden until
  you check an answer or reveal the conjugated form. It then appears alongside
  the expected conjugation.
- Review session results and cumulative learning progress.
- Progress is stored locally and remains available after the app is closed.
- The bundled vocabulary is installed and updated in local storage on launch.

Core features do not require an internet connection. Vocabulary entries are
and conjugation records are bundled with the app; adding, editing, and deleting
them in the app are not supported.

## Requirements

- Flutter SDK (Dart version specified in `pubspec.yaml`)
- Android SDK and an Android device or emulator

## Get started

From the project directory, install dependencies and launch on a connected
Android device or running emulator:

```bash
flutter pub get
flutter run
```

To build a release APK:

```bash
flutter build apk --release
```

## Verify

Run static analysis and the automated tests:

```bash
flutter analyze
flutter test
```

## Project layout

```text
assets/       Bundled vocabulary data
docs/         Product and system specifications
lib/data/     Local storage and initialization
lib/domain/   Practice-session logic
lib/models/   Vocabulary data models and validation
test/         Unit, storage, and widget tests
```

The vocabulary file at `assets/vocabulary.json` is UTF-8 JSON. It has a
positive version number, an `entries` array, and a `conjugations` array.
Vocabulary entries have stable unique IDs, a `beginner` or `advanced` level, a
topic, German (`de`) and European Portuguese (`pt-PT`) forms, and example
sentences. Each language form defines a primary translation and a list of
accepted translations that includes the primary form. Conjugation records
include a stable ID, language, level, topic, infinitive, translation in the
other language, present-indicative subject forms, and their accepted answers.
The bundle contains at least 200 vocabulary entries, with at least 10 in each
of 20 topics. It contains at least 30 conjugation verbs for each language and
level, with at least 10 per applicable topic.

See [`docs/product_spec.md`](docs/product_spec.md) for product behavior and
[`docs/system_spec.md`](docs/system_spec.md) for implementation requirements.
