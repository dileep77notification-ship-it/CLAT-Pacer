// ============================================================================
// DAILY ARTICLE SERVICE
// Spec §6: fetch today's headlines (RssService), have Sarvam pick the most
// CLAT-relevant stories and write an original CLAT-style passage + 5 MCQs +
// 5 flashcards for each. This is the live replacement for main.dart's old
// hardcoded `todaysSprint` constant, and the same output doubles as seed
// content for the GK/Current-Affairs quiz mode.
//
// Nov 2026: expanded from a single daily passage to 3-4, now that RSS
// sourcing covers five feeds (The Hindu National/Editorial, Bar & Bench,
// Indian Express Explained, LiveLaw Top Stories) instead of three. Each
// passage is still generated with its own Sarvam call, same shape and same
// ~3500 max_tokens budget as the original single-passage design — doing one
// giant call for 4 passages at once would multiply output tokens ~4x and
// risk tripping Sarvam's rate limit (Sarvam's limits are undocumented; tune if you see 429s) in a single
// request. Sequential calls paced 10s apart (matching SarvamService's
// batching convention elsewhere in this app) are slower but safe, and a
// failure on one slot doesn't cost the others — same "skip what fails"
// resilience RssService already uses for feeds.
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/daily_sprint_models.dart';
import 'rss_service.dart';

const String _kSarvamModel = 'sarvam-105b-conversations';
const String _kSarvamChatUrl =
    'https://api.sarvam.ai/v1/chat/completions';

const int _kMaxAttempts = 4;
const List<Duration> _kRetryDelays = [
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

/// How many passages a full Daily Sprint tries to produce. May return fewer
/// if the headline pool runs out of distinct CLAT-relevant stories or a
/// generation attempt fails outright after retries.
///
/// Dropped from 4 to 3 (Nov 2026) after real-world testing showed 4
/// sequential calls right before using another Sarvam-backed feature (e.g.
/// Legal Reasoning) was enough to trip the free-tier per-minute limit on
/// the next feature's own request. 3 leaves more headroom.
const int kDailySprintPassageCount = 3;

/// Pause between each passage's Sarvam call. Widened from 10s to 15s for the
/// same reason as the count drop above — more breathing room under the
/// free-tier rate limit, at the cost of a slightly longer total wait.
const Duration _kBetweenPassagesPause = Duration(seconds: 15);

/// Reports what's actually happening during generateTodaysSprints, so a
/// loading screen can show real status instead of a static guess — a slow
/// run (e.g. retrying after a 429) should look visibly different from a
/// frozen one.
typedef SprintProgress = void Function(String message);

class DailyArticleException implements Exception {
  final String message;
  DailyArticleException(this.message);
  @override
  String toString() => message;
}

String _systemPrompt(List<String> excludeHeadlines) {
  final excludeClause = excludeHeadlines.isEmpty
      ? ''
      : '\n\nDo NOT pick any of these stories — they are already covered by '
          'other passages today:\n' +
          excludeHeadlines.map((h) => '- $h').join('\n');

  return '''
You are a CLAT (Common Law Admission Test) content writer producing one
passage of the daily Current Affairs set. You will be given a list of
today's news headlines from Indian sources. Your job:

1. Pick the SINGLE most CLAT-relevant story from the list that is not
   already covered (see exclusion list below, if any) — prioritize law,
   judiciary, Parliament/legislation, constitutional matters, and major
   national or international events with civic/legal significance. Prefer
   the kind of story that would plausibly appear in a CLAT UG Current
   Affairs section.
2. Write an ORIGINAL ~450-500 word passage in CLAT comprehension-passage
   style about that story's topic, using your own general knowledge of the
   subject — this is an educational passage inspired by the headline, not a
   verbatim reproduction of any article or quote.
3. Write exactly 5 multiple-choice questions testing comprehension of the
   passage (4 options each, one correct).
4. Write exactly 5 short flashcard facts related to the passage's topic —
   each a short standalone fact a student should remember.
5. Report back the exact headline text (copied from the list you were
   given) that you based this passage on, via the source_headline field.

IMPORTANT RULES:
- Respond entirely in English. Do not include any non-English characters,
  words, or scripts anywhere in your output.
- Do not restate the options as text inside a question's own text — options
  belong only in the options array.
- Always provide exactly 4 options per question, and exactly 5 questions
  and 5 flashcards total.$excludeClause
''';
}

class DailyArticleService {
  /// Generates today's full set of Daily Sprint passages (3-4, see
  /// [kDailySprintPassageCount]). Fetches headlines once, then makes one
  /// Sarvam call per passage, each told which stories earlier calls already
  /// used so the set doesn't repeat a story.
  ///
  /// Throws only if every single attempt fails and nothing could be
  /// generated; otherwise returns whatever passages did succeed, even if
  /// that's fewer than [count].
  static Future<List<PassageModel>> generateTodaysSprints({
    required String apiKey,
    int count = kDailySprintPassageCount,
    SprintProgress? onProgress,
  }) async {
    onProgress?.call("Fetching today's headlines…");
    final headlines = await RssService.fetchAllHeadlines();

    // Wider pool than the old single-passage version (15) since we're now
    // picking several distinct stories out of it, across five feeds.
    final candidates = headlines.take(30).toList();
    String headlinesTextOf(List<RssHeadline> hs) => hs
        .map((h) =>
            '- [${h.source}] ${h.title}${h.description != null ? ' — ${h.description}' : ''}')
        .join('\n');

    final passages = <PassageModel>[];
    final usedHeadlines = <String>[];
    Object? lastError;

    for (var i = 0; i < count; i++) {
      onProgress?.call('Generating story ${i + 1} of $count…');
      try {
        final result = await _generateOnePassage(
          apiKey: apiKey,
          headlinesText: headlinesTextOf(candidates),
          excludeHeadlines: usedHeadlines,
          onRetry: (attempt, reason) => onProgress?.call(
              'Story ${i + 1} of $count — $reason, retrying (attempt ${attempt + 1} of $_kMaxAttempts)…'),
        );
        passages.add(result.passage);
        usedHeadlines.add(result.sourceHeadline);
        // The model sometimes ignores the "don't reuse these stories"
        // instruction, so also take the used story out of the list it sees.
        _removeBestMatch(candidates, result.sourceHeadline);
      } catch (e) {
        lastError = e;
        onProgress?.call('Story ${i + 1} of $count failed — skipping it.');
        // Skip this slot and keep going — one failed passage shouldn't
        // cost the rest of the day's set.
      }

      final isLast = i == count - 1;
      if (!isLast) {
        onProgress?.call('Pausing briefly before the next story '
            '(keeps Sarvam\'s rate limit happy)…');
        await Future.delayed(_kBetweenPassagesPause);
      }
    }

    if (passages.isEmpty) {
      throw DailyArticleException(
          lastError != null ? lastError.toString() : 'Failed to generate today\'s sprint.');
    }

    return passages;
  }

  static Future<_GeneratedPassage> _generateOnePassage({
    required String apiKey,
    required String headlinesText,
    required List<String> excludeHeadlines,
    void Function(int attempt, String reason)? onRetry,
  }) async {
    for (var attempt = 1; attempt <= _kMaxAttempts; attempt++) {
      http.Response response;
      try {
        response = await http
            .post(
              Uri.parse(_kSarvamChatUrl),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'api-subscription-key': apiKey,
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': _kSarvamModel,
                'messages': [
                  {
                    'role': 'system',
                    'content': _systemPrompt(excludeHeadlines),
                  },
                  {
                    'role': 'user',
                    'content':
                        "Today's headlines:\n$headlinesText\n\nPick the single most CLAT-relevant story not already covered and generate the passage, questions, and flashcards via the submit_daily_passage tool.",
                  },
                ],
                'tools': [_submitDailyPassageTool],
                'tool_choice': {
                  'type': 'function',
                  'function': {'name': 'submit_daily_passage'},
                },
                'max_tokens': 3500,
              }),
            )
            .timeout(const Duration(seconds: 60));
      } catch (e) {
        if (attempt < _kMaxAttempts) {
          onRetry?.call(attempt, 'network error');
          await Future.delayed(_kRetryDelays[attempt - 1]);
          continue;
        }
        throw DailyArticleException('Network error — $e');
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw DailyArticleException(
            'API key was rejected. Check it in Settings.');
      }

      if (response.statusCode == 429 || response.statusCode == 503) {
        if (attempt < _kMaxAttempts) {
          onRetry?.call(attempt, 'Sarvam is rate-limiting requests');
          await Future.delayed(_kRetryDelays[attempt - 1]);
          continue;
        }
        throw DailyArticleException(
            'Sarvam is rate-limiting requests right now. Try again in a minute.');
      }

      if (response.statusCode != 200) {
        throw DailyArticleException('Sarvam returned HTTP ${response.statusCode}.');
      }

      final parsed = _parsePassage(response.body);

      // Observed in testing: the model sometimes returns a ~290-word passage
      // despite the 450-500 target. Retry rather than ship a short one,
      // unless this was the last attempt.
      final words = parsed.passage.body.trim().split(RegExp(r'\s+')).length;
      if (words < _kMinPassageWords && attempt < _kMaxAttempts) {
        onRetry?.call(attempt, 'passage was too short');
        continue;
      }
      return parsed;
    }

    throw DailyArticleException('Failed after $_kMaxAttempts attempts.');
  }

  static const int _kMinPassageWords = 380;

  static Set<String> _words(String s) => s
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.length > 2)
      .toSet();

  /// Removes the headline in [pool] that best matches [reported] (the model
  /// may add a "Source - " prefix or lightly reword it, so match by word
  /// overlap, not equality). Does nothing if no headline overlaps enough.
  static void _removeBestMatch(List<RssHeadline> pool, String reported) {
    final target = _words(reported);
    if (target.isEmpty) return;
    var bestIdx = -1;
    var bestScore = 0.0;
    for (var i = 0; i < pool.length; i++) {
      final w = _words(pool[i].title);
      if (w.isEmpty) continue;
      final score = w.intersection(target).length / w.length;
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }
    if (bestIdx >= 0 && bestScore >= 0.6) pool.removeAt(bestIdx);
  }

  static final Map<String, dynamic> _submitDailyPassageTool = {
    'type': 'function',
    'function': {
      'name': 'submit_daily_passage',
      'description':
          'Submit the generated CLAT daily Current Affairs passage with its questions and flashcards.',
      'parameters': {
        'type': 'object',
        'properties': {
          'source_headline': {
            'type': 'string',
            'description':
                'The exact headline text, copied from the provided list, that this passage is based on.',
          },
          'title': {'type': 'string'},
          'body': {
            'type': 'string',
            'description': 'The ~450-500 word CLAT-style passage.'
          },
          'questions': {
            'type': 'array',
            'minItems': 5,
            'maxItems': 5,
            'items': {
              'type': 'object',
              'properties': {
                'question': {'type': 'string'},
                'options': {
                  'type': 'array',
                  'items': {'type': 'string'},
                  'minItems': 4,
                  'maxItems': 4,
                },
                'correct_index': {'type': 'integer'},
              },
              'required': ['question', 'options', 'correct_index'],
            },
          },
          'flashcards': {
            'type': 'array',
            'minItems': 5,
            'maxItems': 5,
            'items': {
              'type': 'object',
              'properties': {
                'title': {'type': 'string'},
                'fact': {'type': 'string'},
              },
              'required': ['title', 'fact'],
            },
          },
        },
        'required': ['source_headline', 'title', 'body', 'questions', 'flashcards'],
      },
    },
  };

  static _GeneratedPassage _parsePassage(String responseBody) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (_) {
      throw DailyArticleException('Could not parse Sarvam\'s response.');
    }

    List<dynamic> toolCalls;
    try {
      toolCalls = body['choices'][0]['message']['tool_calls'] as List<dynamic>;
    } catch (_) {
      throw DailyArticleException('Sarvam did not call the expected tool.');
    }
    if (toolCalls.isEmpty) {
      throw DailyArticleException('Sarvam\'s response had no tool call in it.');
    }

    Map<String, dynamic> args;
    try {
      final rawArgs = toolCalls[0]['function']['arguments'] as String;
      args = jsonDecode(rawArgs) as Map<String, dynamic>;
    } catch (_) {
      throw DailyArticleException('Could not parse Sarvam\'s tool arguments.');
    }

    try {
      final questions = (args['questions'] as List).map((q) {
        final options = List<String>.from(q['options'] as List);
        final correctIndex = (q['correct_index'] as num).toInt();
        if (options.length != 4) {
          throw FormatException('Expected 4 options, got ${options.length}');
        }
        return QuestionModel(
          prompt: q['question'] as String,
          options: options,
          correctIndex: correctIndex,
        );
      }).toList();

      final flashcards = (args['flashcards'] as List)
          .map((f) => FlashcardModel(
                title: f['title'] as String,
                fact: f['fact'] as String,
              ))
          .toList();

      if (questions.isEmpty || flashcards.isEmpty) {
        throw DailyArticleException('Sarvam\'s response was missing questions or flashcards.');
      }

      final sourceHeadline = args['source_headline'] as String? ?? '';

      return _GeneratedPassage(
        passage: PassageModel(
          title: args['title'] as String,
          body: args['body'] as String,
          questions: questions,
          flashcards: flashcards,
        ),
        sourceHeadline: sourceHeadline,
      );
    } catch (e) {
      throw DailyArticleException(
          'Passage format from Sarvam didn\'t match what was expected ($e).');
    }
  }
}

class _GeneratedPassage {
  final PassageModel passage;
  final String sourceHeadline;
  const _GeneratedPassage({required this.passage, required this.sourceHeadline});
}
