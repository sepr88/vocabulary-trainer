# System Specification: Vocabulary Trainer

## Platform and implementation

- **SYS-001:** The primary target platform is Android, and the initial MVP runs locally on an Android device.
- **SYS-002:** The app is implemented using Flutter and Dart.

## System design guidance

Keep the implementation simple, maintainable, and easy to extend.

## Persistence and operation

- **SYS-003:** Learning progress is persisted locally on the device and is available across app launches.
- **SYS-004:** Core app functionality does not depend on network access.
- **SYS-005:** The data design allows for possible future backup or synchronization; cloud synchronization and accounts are not required for the MVP.
- **SYS-008:** On first launch, the app initializes its writable local vocabulary store from the bundled human-readable vocabulary file. The bundled file is read-only and is not modified during app use.
- **SYS-009:** The app reads vocabulary entries from writable local app storage and reads and writes per-entry learning progress there.
- **SYS-011:** When the bundled vocabulary changes in an app release, the app reconciles it with the local vocabulary store using stable entry IDs. It adds new entries with no practice history, updates changed entries while preserving their progress, and removes retired entries from the active vocabulary while retaining their progress records. The reconciliation is applied atomically so an interruption cannot leave a partially updated vocabulary store.
- **SYS-012:** The bundled vocabulary file is UTF-8 encoded JSON. Each vocabulary entry has a stable, unique ID and German and European Portuguese forms. Each language form contains one non-empty primary translation and a list of accepted translations that includes the primary translation. The file must contain all required fields with valid types, and entry IDs must be unique.
- **SYS-013:** The app validates bundled vocabulary before initializing or updating the local store. If validation, initialization, or local data access fails, it reports the failure to the user and does not start practice with incomplete or substituted data. A failed write is not reported as successful, and the app preserves existing valid data. Initialization and updates are atomic so interruption does not leave partially applied data.
- **SYS-015:** The bundled vocabulary file has a version identifier, and the local store records the last successfully applied version. On launch, the app skips reconciliation when the versions match. When they differ, the app validates and reconciles the bundled vocabulary atomically, recording the new version only after successful reconciliation.
- **SYS-016:** The bundled vocabulary JSON is a top-level object containing a positive integer `version`, an `entries` array, and a `conjugations` array as specified by SYS-020. Each entry contains a non-empty string `id`, a `level` whose value is `beginner` or `advanced`, `de` and `pt-PT` language objects, and an `examples` object. Each language object contains a non-empty string `primary` and a non-empty array `accepted` of non-empty strings; `accepted` includes `primary` and contains no duplicates. The `examples` object contains non-empty string fields `de` and `pt-PT`; each example contains no more than 12 whitespace-separated words. Entry IDs are unique. Validation rejects missing required fields, incorrect field types, empty strings, and unknown fields.
- **SYS-017:** If the local store is corrupt or unreadable, the app reports the failure, disables practice, and provides an action to retry access or initialization. The app does not automatically overwrite or reset the store. A retry may initialize or update the store only when the existing data can be read and preserved; otherwise, the app leaves the store unchanged and continues to report the failure.
- **SYS-020:** The bundled vocabulary JSON includes a `conjugations` array. Each conjugation record has a stable unique ID, a language (`de` or `pt-PT`), a proficiency level (`beginner` or `advanced`), an infinitive, the tense `presentIndicative`, and a list of subject forms. Each subject form has a subject identifier, a non-empty primary conjugation, and a non-empty list of accepted conjugations that includes the primary and contains no duplicates. Validation rejects missing or incorrectly typed fields, duplicate IDs or subject identifiers within a record, and unknown fields.
- **SYS-021:** The local store persists conjugation-practice attempts separately from vocabulary-practice attempts, including the conjugation record, subject form, language, proficiency level, and correct/incorrect result. Reconciliation of bundled conjugation data preserves recorded attempts for matching stable IDs. The database migration adds conjugation storage without deleting or changing existing vocabulary attempts.

## Verification

- **SYS-006:** `flutter analyze` completes without errors.
- **SYS-007:** All automated tests required by SYS-014 pass.
- **SYS-014:** Automated tests cover initialization from valid bundled vocabulary; validation of required example sentences and their 12-word limit; vocabulary additions, changes, and removals across app releases while preserving progress; persistence of practice results across app restarts; rejection of invalid bundled data; answer matching; session selection, including PRD-032 weight calculations, weighted draw behavior, selection without replacement, and inclusion of every entry when 15 or fewer are available; session-summary calculations; prevention of duplicate progress updates; practice-screen fit without scrolling or clipping at a 393 × 851 dp portrait viewport before and after answering, with example text at least 16sp; and scrolling home progress tiles fully into view at that viewport without nested scrollables. Tests verify that failed or interrupted initialization and updates do not leave partial data or corrupt existing valid data.
- **SYS-018:** The local vocabulary store persists, for each entry, the cumulative number of completed attempts and incorrect attempts needed by the session selector. Revealed answers count as incorrect attempts. The selector uses these counts when applying the PRD-032 weights.
- **SYS-019:** At default system text scaling, the practice screen renders in portrait within a 393 × 851 dp viewport with no vertical scrolling or clipped content, both before a response and after the answer or reveal, while keeping text at least 16sp.
- **SYS-022:** Automated tests validate conjugation data and at least 10 distinct verbs for each language and proficiency level, the required subject forms, accepted-form matching, sessions containing every verb-subject combination exactly once, session summaries, prevention of duplicate results, separate persistence of conjugation progress, and preservation of that progress when bundled data is reconciled.
- **SYS-023:** The system derives cumulative conjugation metrics from stored conjugation-practice attempts, grouped by language and proficiency level. Each attempt contributes to exactly one practiced, correct, or incorrect count; a revealed answer is incorrect. Accuracy is calculated from conjugation attempts only. Conjugation attempts and metrics are excluded from all vocabulary-practice metrics and selection calculations.
- **SYS-024:** Database upgrades create conjugation tables transactionally. Conjugation attempts have unique attempt IDs and record the stable conjugation ID and subject ID; duplicate attempts are rejected without changing progress.
- **SYS-025:** The app bundles validated, UTF-8 grammar-reference content for German and European Portuguese, separate from conjugation-practice records. The reference is available offline and displays only content for the language selected for the active conjugation exercise.
- **SYS-026:** Automated tests verify that the grammar help control is unavailable before a conjugation exercise starts, opens the selected language’s reference during an active exercise, shows the required regular and irregular paradigms, and preserves the current prompt and session progress when the user returns.

## Open system decisions
