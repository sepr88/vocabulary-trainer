# Product Specification: Vocabulary Trainer

## Product goals and audience

- **PRD-001:** The app helps users learn, practice, and retain vocabulary.
- **PRD-002:** The app supports German native speakers learning European Portuguese and Portuguese native speakers learning German.
- **PRD-003:** The app is suitable for beginner and advanced learners.

## Home screen

- **PRD-004:** The home screen provides an action to start a vocabulary practice session, a summary of learning progress, and an uncluttered layout.
- **PRD-031:** The home screen displays, at its bottom, the version number of the vocabulary dataset currently active in the local vocabulary store.

## Vocabulary practice

- **PRD-005:** Users can start a practice session using saved vocabulary entries.
- **PRD-006:** For each practice item, the app displays a word or phrase in the source language.
- **PRD-007:** The user can either enter a translation and check it, or reveal the correct translation without entering an answer.
- **PRD-008:** After a checked answer, the app reveals the stored translation and indicates whether the user's input is correct. After the user reveals the answer, the app reveals the stored translation and provides negative feedback.
- **PRD-009:** The app presents the next item after each practice item. A session contains up to 15 distinct vocabulary entries; if fewer than 15 entries are available, each available entry is presented once and the session ends when all available entries have been practiced. The app displays a session summary when the session ends.
- **PRD-019:** When a practice session ends, its summary displays the number of entries practiced, the number answered correctly, the number answered incorrectly, and the percentage of practiced entries answered correctly. These values are calculated from that session only. A revealed answer counts as incorrect, as specified in PRD-018.
- **PRD-016:** For each practice item, the app randomly selects either German-to-European-Portuguese or European-Portuguese-to-German as the translation direction. The direction is selected separately for each item and may differ from the preceding item.
- **PRD-017:** When checking an answer, the app ignores leading and trailing whitespace and differences in letter case. All other characters, including accents and diacritics, must match one of the stored accepted translations. An alternate translation is accepted only when it is stored as an accepted translation for the vocabulary entry.
- **PRD-018:** Revealing the translation without submitting an answer counts as an incorrect practice attempt for learning-progress metrics.
- **PRD-020:** The app does not provide users with functionality to add, edit, or delete vocabulary entries.
- **PRD-021:** Each completed practice item counts as one attempt toward the cumulative “items practiced” total and is classified as correct or incorrect; revealing the answer counts as incorrect. A vocabulary entry counts toward “unique entries answered correctly” if it has at least one correct attempt and toward “unique entries answered incorrectly” if it has at least one incorrect attempt. An entry may count toward both unique-entry totals.
- **PRD-022:** Each practice session randomly selects and orders up to 15 distinct vocabulary entries. If 15 or fewer entries are available, every entry is included exactly once in a random order. If more than 15 entries are available, 15 are selected without replacement, so no entry appears more than once in the session.
- **PRD-023:** When revealing a practice item's translation, the app displays the designated primary translation for the selected translation direction. Alternate accepted translations are accepted when checking an answer but are not displayed in the reveal.
- **PRD-024:** The app records each completed practice item's result in cumulative progress immediately. If the app closes before a session ends, the app does not resume that session, discards its remaining items, and displays no session summary for it. The next session starts as a new session.
- **PRD-025:** When a user reveals the translation instead of submitting an answer, the app displays clear feedback that the item was marked incorrect alongside the revealed primary translation.
- **PRD-026:** Users cannot choose or restrict the translation direction in the MVP. For each practice item, the app selects the direction randomly, regardless of the user's native language.
- **PRD-027:** A practice item is completed when the user checks an answer or reveals its translation. The app records exactly one result for the item and prevents further answer checks or reveals for it. The user advances to the next item using an explicit action; on the final item, this action ends the session and displays its summary.
- **PRD-029:** The bundled MVP vocabulary contains at least 100 distinct entries. Each entry provides German and European Portuguese forms and is identified as suitable for beginner or advanced learners.
- **PRD-030:** After a user reveals a translation, the app displays the revealed primary translation together with the text “Marked incorrect” until the user advances to the next practice item.

## Learning progress

- **PRD-010:** The progress overview shows the total number of vocabulary entries, the number of items practiced, the number of correct answers, the number of incorrect answers, the number of unique entries answered correctly, and the number of unique entries answered incorrectly.
- **PRD-011:** Progress reflects actual practice activity and remains available after the app is closed and reopened.
- **PRD-028:** The total vocabulary count and unique-entry counts include only active vocabulary entries. Cumulative counts of items practiced, correct answers, and incorrect answers include all recorded attempts, including attempts for entries later retired from the active vocabulary.

## Availability and empty state

- **PRD-012:** If there are no vocabulary entries, the app displays a normal empty state that explains no entries are available and disables practice.
- **PRD-013:** Core app features work without an internet connection.
- **PRD-014:** Data remains available when navigating between screens and after closing and reopening the app.

## Product design guidance (not acceptance criteria)

Keep the experience simple, intuitive, fast to start, focused, consistent, accessible, and visually aligned with modern Android/Material conventions. Prefer readable text, sufficient contrast, appropriately sized touch targets, and minimal distractions.

## MVP exclusions

- **PRD-015:** Cloud synchronization and user accounts are not part of the MVP.

## Open product decisions
