import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const ToeicApp());
}

class ToeicApp extends StatelessWidget {
  const ToeicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TOEIC Vocabulary Pro',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class VocabWord {
  final int id;
  final String topic;
  final String english;
  final String vietnamese;

  const VocabWord({
    required this.id,
    required this.topic,
    required this.english,
    required this.vietnamese,
  });

  factory VocabWord.fromJson(Map<String, dynamic> json) {
    return VocabWord(
      id: json['id'] as int? ?? 0,
      topic: (json['topic'] ?? 'General').toString(),
      english: (json['english'] ?? '').toString(),
      vietnamese: (json['vietnamese'] ?? '').toString(),
    );
  }
}

class GrammarQuestion {
  final String question;
  final List<String> options;
  final String correct;
  final String explanation;

  const GrammarQuestion({
    required this.question,
    required this.options,
    required this.correct,
    required this.explanation,
  });

  factory GrammarQuestion.fromJson(Map<String, dynamic> json) {
    return GrammarQuestion(
      question: (json['question'] ?? '').toString(),
      options: List<String>.from(json['options'] ?? const []),
      correct: (json['correct'] ?? '').toString(),
      explanation: (json['exp'] ?? json['explanation'] ?? '').toString(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterTts _tts = FlutterTts();
  final Random _random = Random();

  List<VocabWord> _allWords = [];
  List<GrammarQuestion> _grammarQuestions = [];
  Map<String, int> _correctCounts = {};
  int _score = 100;
  int _tabIndex = 0;
  String _topic = 'Tất cả';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  final FlutterTts flutterTts = FlutterTts();

Future<void> setupTts() async {
  await flutterTts.setLanguage("en-US");
  await flutterTts.setSpeechRate(0.42);
  await flutterTts.setVolume(1.0);
  await flutterTts.setPitch(1.0);
  await flutterTts.awaitSpeakCompletion(false);
}

Future<void> speak(String text) async {
  final word = text.trim();

  if (word.isEmpty) return;

  try {
    await flutterTts.stop();

    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.42);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    await flutterTts.speak(word);
  } catch (e) {
    debugPrint("TTS error: $e");
  }
}
  List<String> get _topics {
    final set = _allWords.map((w) => w.topic).toSet().toList()..sort();
    return ['Tất cả', ...set];
  }

  List<VocabWord> get _activeWords {
    if (_topic == 'Tất cả') return _allWords;
    return _allWords.where((w) => w.topic == _topic).toList();
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('score', _score);
    await prefs.setString('correctCounts', jsonEncode(_correctCounts));
  }

  Future<void> _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  void _addScore(int delta) {
    setState(() {
      _score += delta;
      if (_score < 0) _score = 0;
    });
    _saveProgress();
  }

  void _markCorrect(String english) {
    final key = english.trim();
    setState(() {
      _correctCounts[key] = (_correctCounts[key] ?? 0) + 1;
    });
    _saveProgress();
  }

  Future<void> _resetProgress() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tiến độ?'),
        content: const Text('Điểm số và số lần đúng của các từ sẽ trở về ban đầu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    setState(() {
      _score = 100;
      _correctCounts = {};
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [
      LearnScreen(
        words: _activeWords,
        topic: _topic,
        correctCounts: _correctCounts,
        onSpeak: _speak,
      ),
      QuizScreen(
        key: ValueKey('quiz-$_topic-${_activeWords.length}'),
        words: _activeWords,
        topic: _topic,
        random: _random,
        onSpeak: _speak,
        onCorrect: (word) {
          _markCorrect(word.english);
          _addScore(1);
        },
        onWrong: () => _addScore(-5),
      ),
      MatchingScreen(
        key: ValueKey('matching-$_topic-${_activeWords.length}'),
        words: _activeWords,
        topic: _topic,
        random: _random,
        onSpeak: _speak,
        onCorrect: (word) {
          _markCorrect(word.english);
          _addScore(1);
        },
        onWrong: () => _addScore(-5),
      ),
      GrammarScreen(
        questions: _grammarQuestions,
        random: _random,
        onCorrect: () => _addScore(2),
        onWrong: () => _addScore(-3),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('TOEIC Vocabulary Pro'),
        centerTitle: false,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('⭐ $_score', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          IconButton(
            tooltip: 'Xóa tiến độ',
            onPressed: _resetProgress,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: TopicPicker(
                topic: _topic,
                topics: _topics,
                count: _activeWords.length,
                onChanged: (value) => setState(() => _topic = value ?? 'Tất cả'),
              ),
            ),
            Expanded(child: pages[_tabIndex]),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'Học'),
          NavigationDestination(icon: Icon(Icons.quiz_rounded), label: 'Kiểm tra'),
          NavigationDestination(icon: Icon(Icons.extension_rounded), label: 'Nối từ'),
          NavigationDestination(icon: Icon(Icons.school_rounded), label: 'Part 5'),
        ],
      ),
    );
  }
}

class TopicPicker extends StatelessWidget {
  final String topic;
  final List<String> topics;
  final int count;
  final ValueChanged<String?> onChanged;

  const TopicPicker({
    super.key,
    required this.topic,
    required this.topics,
    required this.count,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.topic_rounded),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: topic,
                  isExpanded: true,
                  items: topics.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('$count từ', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class LearnScreen extends StatelessWidget {
  final List<VocabWord> words;
  final String topic;
  final Map<String, int> correctCounts;
  final Future<void> Function(String text) onSpeak;

  const LearnScreen({
    super.key,
    required this.words,
    required this.topic,
    required this.correctCounts,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) return const EmptyState(message: 'Topic này chưa có từ vựng.');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: words.length,
      itemBuilder: (context, index) {
        final w = words[index];
        final count = correctCounts[w.english] ?? 0;
        final learned = count >= 5;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            title: Text(w.english, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(w.vietnamese, style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    learned ? '✅ Đã thuộc ($count lần đúng)' : '⏳ Đang học ($count/5)',
                    style: TextStyle(color: learned ? Colors.green : Colors.orange.shade700),
                  ),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.volume_up_rounded),
              onPressed: () => onSpeak(w.english),
            ),
          ),
        );
      },
    );
  }
}

class QuizScreen extends StatefulWidget {
  final List<VocabWord> words;
  final String topic;
  final Random random;
  final Future<void> Function(String text) onSpeak;
  final void Function(VocabWord word) onCorrect;
  final VoidCallback onWrong;

  const QuizScreen({
    super.key,
    required this.words,
    required this.topic,
    required this.random,
    required this.onSpeak,
    required this.onCorrect,
    required this.onWrong,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final TextEditingController _controller = TextEditingController();
  VocabWord? _current;
  String _message = '';
  Color _messageColor = Colors.black54;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    if (widget.words.isEmpty) return;
    setState(() {
      _current = widget.words[widget.random.nextInt(widget.words.length)];
      _controller.clear();
      _message = '';
      _messageColor = Colors.black54;
    });
  }

  void _hint() {
    final ans = _current?.english.trim() ?? '';
    final current = _controller.text;
    if (current.length < ans.length) {
      _controller.text = current + ans[current.length];
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
      setState(() {
        _message = '💡 Đã gợi ý thêm 1 chữ cái';
        _messageColor = Colors.blueGrey;
      });
    }
  }

  void _check() {
    final word = _current;
    if (word == null) return;
    final user = _controller.text.trim().toLowerCase();
    final ans = word.english.trim().toLowerCase();

    if (user == ans) {
      widget.onCorrect(word);
      widget.onSpeak(word.english);
      setState(() {
        _message = '🎉 Chính xác! +1 điểm';
        _messageColor = Colors.green;
      });
      Future.delayed(const Duration(milliseconds: 900), _next);
    } else {
      widget.onWrong();
      setState(() {
        _message = "❌ Sai rồi! Đáp án: ${word.english}";
        _messageColor = Colors.red;
      });
      Future.delayed(const Duration(milliseconds: 1400), _next);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) return const EmptyState(message: 'Topic này chưa có từ vựng.');
    final word = _current!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Topic: ${widget.topic}', style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 18),
              const Text('Dịch sang tiếng Anh:', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 14),
              Text(
                word.vietnamese,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _check(),
                decoration: InputDecoration(
                  hintText: 'Nhập từ tiếng Anh',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: _hint, icon: const Icon(Icons.lightbulb), label: const Text('Gợi ý'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton.icon(onPressed: _check, icon: const Icon(Icons.check), label: const Text('Kiểm tra'))),
                ],
              ),
              const SizedBox(height: 14),
              Text(_message, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: _messageColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class MatchingScreen extends StatefulWidget {
  final List<VocabWord> words;
  final String topic;
  final Random random;
  final Future<void> Function(String text) onSpeak;
  final void Function(VocabWord word) onCorrect;
  final VoidCallback onWrong;

  const MatchingScreen({
    super.key,
    required this.words,
    required this.topic,
    required this.random,
    required this.onSpeak,
    required this.onCorrect,
    required this.onWrong,
  });

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  List<VocabWord> _round = [];
  List<String> _english = [];
  List<String> _vietnamese = [];
  String? _selectedEnglish;
  String? _selectedVietnamese;
  final Set<String> _doneEnglish = {};
  final Set<String> _doneVietnamese = {};
  String _status = '';

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    if (widget.words.length < 6) {
      setState(() {
        _round = [];
        _status = "Topic '${widget.topic}' cần ít nhất 6 từ để chơi nối từ.";
      });
      return;
    }
    final copy = [...widget.words]..shuffle(widget.random);
    final picked = copy.take(6).toList();
    setState(() {
      _round = picked;
      _english = picked.map((w) => w.english).toList()..shuffle(widget.random);
      _vietnamese = picked.map((w) => w.vietnamese).toList()..shuffle(widget.random);
      _selectedEnglish = null;
      _selectedVietnamese = null;
      _doneEnglish.clear();
      _doneVietnamese.clear();
      _status = 'Chọn 1 từ tiếng Anh và 1 nghĩa tiếng Việt tương ứng.';
    });
  }

  void _pickEnglish(String value) {
    if (_doneEnglish.contains(value)) return;
    widget.onSpeak(value);
    setState(() => _selectedEnglish = value);
    _tryCheck(value, _selectedVietnamese);
  }

  void _pickVietnamese(String value) {
    if (_doneVietnamese.contains(value)) return;
    setState(() => _selectedVietnamese = value);
    _tryCheck(_selectedEnglish, value);
  }

  void _tryCheck(String? english, String? vietnamese) {
    if (english == null || vietnamese == null) return;
    final match = _round.firstWhere((w) => w.english == english);
    if (match.vietnamese == vietnamese) {
      widget.onCorrect(match);
      setState(() {
        _doneEnglish.add(english);
        _doneVietnamese.add(vietnamese);
        _selectedEnglish = null;
        _selectedVietnamese = null;
        _status = '✅ Chính xác!';
      });
      if (_doneEnglish.length == _round.length) {
        Future.delayed(const Duration(milliseconds: 900), _newRound);
      }
    } else {
      widget.onWrong();
      setState(() {
        _selectedEnglish = null;
        _selectedVietnamese = null;
        _status = '❌ Chưa đúng, thử lại nhé.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.length < 6) return EmptyState(message: _status);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(child: Text(_status, style: const TextStyle(fontWeight: FontWeight.w600))),
                  IconButton(onPressed: _newRound, icon: const Icon(Icons.shuffle_rounded)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildColumn(_english, true)),
                const SizedBox(width: 10),
                Expanded(child: _buildColumn(_vietnamese, false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColumn(List<String> values, bool isEnglish) {
    return ListView.builder(
      itemCount: values.length,
      itemBuilder: (context, i) {
        final value = values[i];
        final done = isEnglish ? _doneEnglish.contains(value) : _doneVietnamese.contains(value);
        final selected = isEnglish ? _selectedEnglish == value : _selectedVietnamese == value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            onPressed: done ? null : () => isEnglish ? _pickEnglish(value) : _pickVietnamese(value),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
              backgroundColor: done
                  ? Colors.green.shade50
                  : selected
                      ? Colors.blue.shade50
                      : Colors.white,
              side: BorderSide(color: done ? Colors.green : selected ? Colors.blue : Colors.black12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(value, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }
}

class GrammarScreen extends StatefulWidget {
  final List<GrammarQuestion> questions;
  final Random random;
  final VoidCallback onCorrect;
  final VoidCallback onWrong;

  const GrammarScreen({
    super.key,
    required this.questions,
    required this.random,
    required this.onCorrect,
    required this.onWrong,
  });

  @override
  State<GrammarScreen> createState() => _GrammarScreenState();
}

class _GrammarScreenState extends State<GrammarScreen> {
  List<GrammarQuestion> _round = [];
  int _index = 0;
  int _correct = 0;
  int _wrong = 0;
  String? _selected;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _newSession();
  }

  void _newSession() {
    final copy = [...widget.questions]..shuffle(widget.random);
    setState(() {
      _round = copy.take(min(10, copy.length)).toList();
      _index = 0;
      _correct = 0;
      _wrong = 0;
      _selected = null;
      _answered = false;
    });
  }

  void _answer(String option) {
    if (_answered) return;
    final q = _round[_index];
    final ok = option == q.correct;
    if (ok) {
      widget.onCorrect();
      _correct++;
    } else {
      widget.onWrong();
      _wrong++;
    }
    setState(() {
      _selected = option;
      _answered = true;
    });
  }

  void _next() {
    if (_index + 1 >= _round.length) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Hoàn thành'),
          content: Text('Kết quả: Đúng $_correct - Sai $_wrong'),
          actions: [FilledButton(onPressed: () { Navigator.pop(context); _newSession(); }, child: const Text('Làm lượt mới'))],
        ),
      );
    } else {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_round.isEmpty) return const EmptyState(message: 'Chưa có câu hỏi Part 5.');

    final q = _round[_index];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: LinearProgressIndicator(value: (_index + 1) / _round.length)),
                  const SizedBox(width: 12),
                  Text('${_index + 1}/${_round.length}'),
                ],
              ),
              const SizedBox(height: 12),
              Text('✓ $_correct    ✕ $_wrong', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text(q.question, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              for (final option in q.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FilledButton.tonal(
                    onPressed: _answered ? null : () => _answer(option),
                    style: FilledButton.styleFrom(
                      backgroundColor: _optionColor(q, option),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Align(alignment: Alignment.centerLeft, child: Text(option)),
                  ),
                ),
              if (_answered) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.blueGrey.shade50, borderRadius: BorderRadius.circular(16)),
                  child: Text(q.explanation),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(onPressed: _next, icon: const Icon(Icons.arrow_forward), label: const Text('Tiếp theo')),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color? _optionColor(GrammarQuestion q, String option) {
    if (!_answered) return null;
    if (option == q.correct) return Colors.green.shade100;
    if (option == _selected) return Colors.red.shade100;
    return null;
  }
}

class EmptyState extends StatelessWidget {
  final String message;

  const EmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded, size: 48, color: Colors.blueGrey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
