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
- **SYS-016:** The bundled vocabulary JSON is a top-level object containing a positive integer `version` and an `entries` array. Each entry contains a non-empty string `id`, a `level` whose value is `beginner` or `advanced`, and `de` and `pt-PT` language objects. Each language object contains a non-empty string `primary` and a non-empty array `accepted` of non-empty strings; `accepted` includes `primary` and contains no duplicates. Entry IDs are unique. Validation rejects missing required fields, incorrect field types, and unknown fields.
- **SYS-017:** If the local store is corrupt or unreadable, the app reports the failure, disables practice, and provides an action to retry access or initialization. The app does not automatically overwrite or reset the store. A retry may initialize or update the store only when the existing data can be read and preserved; otherwise, the app leaves the store unchanged and continues to report the failure.

## Verification

- **SYS-006:** `flutter analyze` completes without errors.
- **SYS-007:** All automated tests required by SYS-014 pass.
- **SYS-014:** Automated tests cover initialization from valid bundled vocabulary; vocabulary additions, changes, and removals across app releases while preserving progress; persistence of practice results across app restarts; rejection of invalid bundled data; answer matching; session selection; session-summary calculations; and prevention of duplicate progress updates. Tests verify that failed or interrupted initialization and updates do not leave partial data or corrupt existing valid data.

## Open system decisions
