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
    return MaterialApp(
      title: 'Vocabulary Trainer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b5b)),
        useMaterial3: true,
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vocabulary Trainer')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Vocabulary or local storage could not be loaded. '
                      'Practice is unavailable.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: const Text('Retry')),
                  ],
                ),
              ),
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
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _progress = progress;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Vocabulary Trainer')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _ErrorPanel(error: _loadError!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Your progress',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 16),
                  _ProgressOverview(progress: _progress!),
                  const SizedBox(height: 24),
                  if (_entries.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No vocabulary entries are available. '
                          'Practice is disabled.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  FilledButton.icon(
                    onPressed: _entries.isEmpty ? null : _startPractice,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start practice'),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ProgressOverview extends StatelessWidget {
  const _ProgressOverview({required this.progress});

  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final metrics = <(String, int)>[
      ('Vocabulary entries', progress.activeVocabularyCount),
      ('Items practiced', progress.itemsPracticed),
      ('Correct answers', progress.correctAnswers),
      ('Incorrect answers', progress.incorrectAnswers),
      ('Entries answered correctly', progress.uniqueEntriesCorrect),
      ('Entries answered incorrectly', progress.uniqueEntriesIncorrect),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final metric in metrics)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(metric.$1)),
                    Text(
                      '${metric.$2}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
          ],
        ),
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
    final directionLabel =
        _item.direction == TranslationDirection.germanToPortuguese
        ? 'German → European Portuguese'
        : 'European Portuguese → German';
    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Question ${_index + 1} of ${widget.session.items.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(directionLabel, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  _item.prompt,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
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
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (!_completed) ...[
            FilledButton(
              onPressed: _saving || _answerController.text.trim().isEmpty
                  ? null
                  : () => _complete(_item.matches(_answerController.text)),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Check answer'),
            ),
            OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => _complete(false, revealed: true),
              child: const Text('Reveal answer'),
            ),
          ] else ...[
            Card(
              color: _correct!
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
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
                    Text(_item.primaryTranslation),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _advance,
              child: Text(
                _index + 1 == widget.session.items.length
                    ? 'Finish session'
                    : 'Next',
              ),
            ),
          ],
          if (_saveError != null) ...[
            const SizedBox(height: 12),
            Text(
              'Could not save this result: $_saveError',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Session summary')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Session complete',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              _SummaryLine(
                label: 'Entries practiced',
                value: summary.practiced,
              ),
              _SummaryLine(label: 'Correct', value: summary.correct),
              _SummaryLine(label: 'Incorrect', value: summary.incorrect),
              _SummaryLine(
                label: 'Accuracy',
                value: '${summary.accuracyPercent.toStringAsFixed(0)}%',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final Object value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label), Text('$value')],
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Local progress could not be loaded. Practice is disabled.',
          ),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    ),
  );
}
