import 'dart:math';

import 'package:flutter/material.dart';

import 'data/bootstrap.dart';
import 'data/trainer_store.dart';
import 'domain/practice_session.dart';
import 'models/vocabulary.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.storeLoader});

  final Future<TrainerStore> Function()? storeLoader;

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xff58a63c),
          surface: const Color(0xfffffdf6),
        ).copyWith(
          primary: const Color(0xff367a2c),
          onPrimary: Colors.white,
          primaryContainer: const Color(0xffe1f3d8),
          onPrimaryContainer: const Color(0xff173d19),
          secondary: const Color(0xffe9a92c),
          onSecondary: const Color(0xff332300),
          error: const Color(0xffb3261e),
          errorContainer: const Color(0xffffe6e2),
          onErrorContainer: const Color(0xff5f1610),
          surface: const Color(0xfffffdf6),
          onSurface: const Color(0xff263229),
          surfaceContainerHighest: const Color(0xfff0f2e9),
        );
    return MaterialApp(
      title: 'Vocabulary Trainer',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfffffdf6),
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          titleTextStyle: const TextStyle(
            color: Color(0xff263229),
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shadowColor: const Color(0xff263229).withValues(alpha: 0.08),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xffedf0e7)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 56),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 56),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            foregroundColor: colorScheme.primary,
            side: BorderSide(
              color: colorScheme.primary.withValues(alpha: 0.45),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xffd8dfd2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xffd8dfd2)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.primary, width: 2),
          ),
        ),
        textTheme: const TextTheme(
          headlineMedium: TextStyle(
            color: Color(0xff263229),
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
          titleLarge: TextStyle(
            color: Color(0xff263229),
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w800,
          ),
          titleMedium: TextStyle(
            color: Color(0xff263229),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          bodyLarge: TextStyle(
            color: Color(0xff3f4a40),
            fontSize: 16,
            height: 1.45,
          ),
          bodyMedium: TextStyle(
            color: Color(0xff586257),
            fontSize: 14,
            height: 1.4,
          ),
          bodySmall: TextStyle(
            color: Color(0xff697266),
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
      home: StartupGate(storeLoader: storeLoader ?? initializeTrainerStore),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.storeLoader});

  final Future<TrainerStore> Function() storeLoader;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late Future<TrainerStore> _storeFuture;

  @override
  void initState() {
    super.initState();
    _storeFuture = widget.storeLoader();
  }

  void _retry() {
    setState(() {
      _storeFuture = widget.storeLoader();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TrainerStore>(
      future: _storeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vocabulary Trainer')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vocabulary Trainer')),
            body: _ErrorPanel(
              icon: Icons.folder_off_rounded,
              title: 'We could not load your vocabulary',
              message: 'Practice is unavailable until storage is accessible.',
              details: '${snapshot.error}',
              actionLabel: 'Try again',
              onRetry: _retry,
            ),
          );
        }
        return HomeScreen(store: snapshot.requireData);
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});

  final TrainerStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<VocabularyEntry> _entries = const [];
  ProgressSnapshot? _progress;
  int? _vocabularyVersion;
  Object? _loadError;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final entries = await widget.store.activeEntries();
      final progress = await widget.store.progress();
      final vocabularyVersion = await widget.store.activeVocabularyVersion();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _progress = progress;
        _vocabularyVersion = vocabularyVersion;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loading = false;
      });
    }
  }

  Future<void> _startPractice() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            PracticeScreen(store: widget.store, entries: _entries),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(Icons.menu_book_rounded, color: colorScheme.primary),
        ),
        title: const Text('Vocabulary Trainer'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _ErrorPanel(
              icon: Icons.folder_off_rounded,
              title: 'Your progress is taking a break',
              message: 'We could not read your local learning data.',
              details: '${_loadError!}',
              actionLabel: 'Try again',
              onRetry: _load,
            )
          : Column(
              children: [
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        const _PracticeWelcome(),
                        const SizedBox(height: 24),
                        if (_entries.isEmpty)
                          const _EmptyVocabularyCard()
                        else
                          _PracticeCallout(onStart: _startPractice),
                        const SizedBox(height: 28),
                        Text(
                          'Your learning',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 14),
                        _ProgressOverview(progress: _progress!),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Text(
                    'Vocabulary version $_vocabularyVersion',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
    );
  }
}

class _PracticeWelcome extends StatelessWidget {
  const _PracticeWelcome();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ready for a little practice?', style: textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(
          'A few minutes today can grow your vocabulary.',
          style: textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _PracticeCallout extends StatelessWidget {
  const _PracticeCallout({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(26),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.bolt_rounded,
                  color: colorScheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your next streak starts here',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start practice'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyVocabularyCard extends StatelessWidget {
  const _EmptyVocabularyCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xffedf0e7)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories_rounded,
            color: colorScheme.primary,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(
            'No vocabulary entries are available. Practice is disabled.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'New words will appear here when vocabulary is available.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: null,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start practice'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressOverview extends StatelessWidget {
  const _ProgressOverview({required this.progress});

  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, int, IconData)>[
      ('Vocabulary entries', progress.activeVocabularyCount, Icons.menu_book),
      ('Items practiced', progress.itemsPracticed, Icons.repeat_rounded),
      ('Correct answers', progress.correctAnswers, Icons.check_circle_rounded),
      ('Incorrect answers', progress.incorrectAnswers, Icons.refresh_rounded),
      (
        'Entries answered correctly',
        progress.uniqueEntriesCorrect,
        Icons.verified_rounded,
      ),
      (
        'Entries answered incorrectly',
        progress.uniqueEntriesIncorrect,
        Icons.history_rounded,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 500 ? 3 : 2;
        return GridView.builder(
          itemCount: metrics.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 118,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final metric = metrics[index];
            return _ProgressTile(
              label: metric.$1,
              value: metric.$2,
              icon: metric.$3,
            );
          },
        );
      },
    );
  }
}

class _ProgressTile extends StatelessWidget {
  const _ProgressTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffedf0e7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colorScheme.primary),
          const Spacer(),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: colorScheme.primary, fontSize: 24),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class PracticeScreen extends StatefulWidget {
  PracticeScreen({
    super.key,
    required this.store,
    required List<VocabularyEntry> entries,
    Random? random,
  }) : session = PracticeSession.create(entries, random: random);

  final TrainerStore store;
  final PracticeSession session;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final TextEditingController _answerController = TextEditingController();
  int _index = 0;
  bool? _correct;
  bool _revealed = false;
  bool _saving = false;
  Object? _saveError;

  PracticeItem get _item => widget.session.items[_index];
  bool get _completed => _correct != null;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _complete(bool correct, {bool revealed = false}) async {
    if (_completed || _saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final recorded = await widget.store.recordAttempt(
        attemptId: _item.attemptId,
        entryId: _item.entry.id,
        correct: correct,
      );
      if (!recorded) {
        throw StateError('This practice item has already been recorded.');
      }
      widget.session.completeItem(_index, correct: correct);
      if (!mounted) return;
      setState(() {
        _correct = correct;
        _revealed = revealed;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saveError = error;
        _saving = false;
      });
    }
  }

  void _advance() {
    if (_index + 1 == widget.session.items.length) {
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (context) =>
              SessionSummaryScreen(summary: widget.session.summary),
        ),
      );
      return;
    }
    setState(() {
      _index++;
      _correct = null;
      _revealed = false;
      _saveError = null;
      _answerController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final questionNumber = _index + 1;
    final questionCount = widget.session.items.length;
    final directionLabel =
        _item.direction == TranslationDirection.germanToPortuguese
        ? 'German → European Portuguese'
        : 'European Portuguese → German';
    final feedbackColor = _correct == true
        ? colorScheme.primaryContainer
        : colorScheme.errorContainer;
    final feedbackIcon = _revealed
        ? Icons.lightbulb_rounded
        : _correct == true
        ? Icons.check_circle_rounded
        : Icons.replay_rounded;
    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question $questionNumber of $questionCount',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${((questionNumber / questionCount) * 100).round()}%',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Semantics(
              label: 'Session progress',
              value: 'Question $questionNumber of $questionCount',
              child: LinearProgressIndicator(
                value: questionNumber / questionCount,
                minHeight: 9,
                backgroundColor: colorScheme.primaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.swap_horiz_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    directionLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 110),
                  child: Center(
                    child: Text(
                      _item.prompt,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: 32,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            key: const ValueKey('practice-answer'),
            controller: _answerController,
            enabled: !_completed && !_saving,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (_answerController.text.trim().isNotEmpty) {
                _complete(_item.matches(_answerController.text));
              }
            },
            decoration: const InputDecoration(
              labelText: 'Your translation',
              hintText: 'Type your answer',
              prefixIcon: Icon(Icons.edit_rounded),
            ),
          ),
          const SizedBox(height: 16),
          if (!_completed) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving || _answerController.text.trim().isEmpty
                    ? null
                    : () => _complete(_item.matches(_answerController.text)),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(_saving ? 'Saving answer' : 'Check answer'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving
                    ? null
                    : () => _complete(false, revealed: true),
                icon: const Icon(Icons.lightbulb_outline_rounded),
                label: const Text('Reveal answer'),
              ),
            ),
          ] else ...[
            Card(
              color: feedbackColor,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      feedbackIcon,
                      size: 28,
                      color: _correct!
                          ? colorScheme.primary
                          : colorScheme.error,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _revealed
                                ? 'Marked incorrect'
                                : _correct!
                                ? 'Correct'
                                : 'Incorrect',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _item.primaryTranslation,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontSize: 20),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _advance,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(
                  questionNumber == questionCount ? 'Finish session' : 'Next',
                ),
              ),
            ),
          ],
          if (_saveError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Could not save this result: $_saveError',
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SessionSummaryScreen extends StatelessWidget {
  const SessionSummaryScreen({super.key, required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Session summary')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: colorScheme.secondary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                color: colorScheme.secondary,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Session complete',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Every word you practiced is a step forward.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text(
                  'Accuracy',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '${summary.accuracyPercent.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(color: colorScheme.primary, fontSize: 48),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'Entries practiced',
                  value: summary.practiced,
                  icon: Icons.menu_book_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMetric(
                  label: 'Correct',
                  value: summary.correct,
                  icon: Icons.check_circle_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryMetric(
                  label: 'Incorrect',
                  value: summary.incorrect,
                  icon: Icons.replay_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.done_rounded),
              label: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffedf0e7)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: colorScheme.primary),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.details,
    required this.actionLabel,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final String details;
  final String actionLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: colorScheme.error, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            Text(
              details,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
