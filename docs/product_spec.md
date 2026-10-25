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
- **PRD-032:** A practice session contains up to 15 distinct active vocabulary entries. If 15 or fewer entries are available, every entry is included exactly once in a uniformly random order. If more than 15 entries are available, entries are selected sequentially without replacement. At each draw, an entry's selection probability is its weight divided by the sum of the weights of all not-yet-selected entries. For an entry with **A** completed attempts and **I** incorrect attempts, its weight is `1 + max(0, 3 - A) + min(I, 3)`. Revealed answers count as incorrect attempts. This gives less-practiced entries and entries with more incorrect attempts greater selection weight; every active entry has positive weight.
- **PRD-023:** When revealing a practice item's translation, the app displays the designated primary translation for the selected translation direction. Alternate accepted translations are accepted when checking an answer but are not displayed in the reveal.
- **PRD-024:** The app records each completed practice item's result in cumulative progress immediately. If the app closes before a session ends, the app does not resume that session, discards its remaining items, and displays no session summary for it. The next session starts as a new session.
- **PRD-025:** When a user reveals the translation instead of submitting an answer, the app displays clear feedback that the item was marked incorrect alongside the revealed primary translation.
- **PRD-026:** Users cannot choose or restrict the translation direction in the MVP. For each practice item, the app selects the direction randomly, regardless of the user's native language.
- **PRD-027:** A practice item is completed when the user checks an answer or reveals its translation. The app records exactly one result for the item and prevents further answer checks or reveals for it. The user advances to the next item using an explicit action; on the final item, this action ends the session and displays its summary.
- **PRD-029:** The bundled MVP vocabulary contains at least 100 distinct entries. Each entry provides German and European Portuguese forms and is identified as suitable for beginner or advanced learners.
- **PRD-030:** After a user reveals a translation, the app displays the revealed primary translation together with the text “Marked incorrect” until the user advances to the next practice item.
- **PRD-033:** Each active vocabulary entry includes one example sentence in German and one equivalent example sentence in European Portuguese. Each sentence contains no more than 12 whitespace-separated words and demonstrates the entry’s use in context.
- **PRD-034:** During a practice item, the app displays the example sentence in the source language before the user responds. After the user checks an answer or reveals the translation, the app displays the paired example sentence in the target language alongside the translation. The target-language sentence is not displayed before the response.
- **PRD-035:** In portrait orientation, with the keyboard hidden and at default text scaling, the practice screen displays all item content and its primary action without vertical scrolling or clipping. Before the user responds, this includes the source prompt, source-language example, and response controls. After the user responds, it includes the revealed translation, target-language example, feedback, and advance action. Text is at least 16sp.

## Conjugation practice

- **PRD-036:** The app offers conjugation practice as a mode separate from vocabulary translation practice. Before starting, users choose German or European Portuguese and a proficiency level: beginner or advanced. This choice does not change the translation direction rules for vocabulary practice.
- **PRD-037:** The initial conjugation practice covers the present indicative. Each practice prompt displays a verb in its infinitive form and a subject prompt appropriate to the selected language, and asks the user to provide the conjugated form.
- **PRD-038:** For each combination of language and proficiency level, the bundled conjugation content includes at least 10 distinct verbs and their present-indicative forms for the subject prompts supported for that language.
- **PRD-039:** Users can submit a conjugated form or reveal the expected form. When checking, the app ignores leading and trailing whitespace and letter-case differences; all other characters, including accents and diacritics, must match a stored accepted form. The reveal displays the designated form and negative feedback. Each prompt can be completed only once, and the user advances using an explicit action.
- **PRD-040:** A completed conjugation session displays the number of prompts practiced, correct and incorrect counts, and the percentage correct. Conjugation results are recorded cumulatively and remain separate from the vocabulary-practice metrics in PRD-010.

## Learning progress

- **PRD-010:** The progress overview shows the total number of vocabulary entries, the number of items practiced, the number of correct answers, the number of incorrect answers, the number of unique entries answered correctly, and the number of unique entries answered incorrectly.
- **PRD-011:** Progress reflects actual practice activity and remains available after the app is closed and reopened.
- **PRD-028:** The total vocabulary count and unique-entry counts include only active vocabulary entries. Cumulative counts of items practiced, correct answers, and incorrect answers include all recorded attempts, including attempts for entries later retired from the active vocabulary.
- **PRD-041:** The progress overview displays conjugation prompts practiced, correct answers, incorrect answers, and accuracy as separate metrics for each language and proficiency level. These are cumulative across conjugation sessions. Accuracy is the number of correct answers divided by the number of prompts practiced, expressed as a percentage; it is 0% when no prompts have been practiced. A revealed answer counts as incorrect, as specified in PRD-039.
- **PRD-042:** A unique conjugation prompt is the combination of a conjugation record and one of its subject forms. A prompt counts as answered correctly if it has at least one correct attempt, and as answered incorrectly if it has at least one incorrect attempt. It may count toward both totals.
- **PRD-043:** Conjugation results do not contribute to vocabulary practice totals or unique-entry metrics in PRD-010 and PRD-021, and do not affect vocabulary session selection under PRD-032. The app displays conjugation progress separately from vocabulary progress.
- **PRD-044:** German conjugation prompts use the subject forms `ich`, `du`, `er/sie/es`, `wir`, `ihr`, and `sie/Sie`. European Portuguese prompts use `eu`, `tu`, `ele/ela/você`, `nós`, and `vocês/eles/elas`.
- **PRD-045:** A conjugation session includes every verb-subject combination for the selected language and proficiency level exactly once. The session order may be randomized.
- **PRD-046:** After a conjugation exercise starts, the exercise screen provides a tappable help control. Activating it opens a separate grammar-reference screen for the language selected for that exercise. The reference screen does not offer content for the other language. Returning to the exercise preserves the current prompt and session progress.
- **PRD-047:** The grammar-reference screen explains present-indicative regular conjugation for the selected language and shows complete conjugation forms using that language’s supported subject forms. It includes an example regular German verb, or one regular European Portuguese verb from each `-ar`, `-er`, and `-ir` class. It also shows complete present-indicative forms for at least three common irregular verbs in the selected language: German `sein`, `haben`, and `werden`; or European Portuguese `ser`, `estar`, and `ir`.

## Availability and empty state

- **PRD-012:** If there are no vocabulary entries, the app displays a normal empty state that explains no entries are available and disables practice.
- **PRD-013:** Core app features work without an internet connection.
- **PRD-014:** Data remains available when navigating between screens and after closing and reopening the app.

## Product design guidance (not acceptance criteria)

Keep the experience simple, intuitive, fast to start, focused, consistent, accessible, and visually aligned with modern Android/Material conventions. Prefer readable text, sufficient contrast, appropriately sized touch targets, and minimal distractions.

## MVP exclusions

- **PRD-015:** Cloud synchronization and user accounts are not part of the MVP.

## Open product decisions

- **OPD-001:** What vocabulary expansion scope, content targets, and release timeline should the product use?
- **OPD-003:** Should users be able to reset their training history and progress? If so, what confirmation or recovery safeguards should apply?
- **OPD-005:** Should users be able to review words they answered incorrectly? If so, how should that review relate to regular practice sessions?
- **OPD-006:** Should vocabulary entries be grouped into topics such as food, travel, and hotels, and should users be able to choose a topic for a practice session?
- **OPD-007:** Should the app include learning goals, achievements, or both?
- **OPD-008:** Should the app send reminders to encourage users to practice? If so, when and how often?
- **OPD-009:** Should users be able to record their pronunciation and compare it with a prerecorded reference?
- **OPD-010:** Should the app identify potential false friends—words that look or sound similar but differ in meaning—and when should it show that information?
- **OPD-011:** Should the app include fill-in-the-blank practice?
- **OPD-012:** Should the app include an adaptive vocabulary coach that tracks recall accuracy and repeated mistakes, adjusts review intervals for each word, and prioritizes words predicted to be nearly forgotten? If so, which exercises should it schedule, and when?
