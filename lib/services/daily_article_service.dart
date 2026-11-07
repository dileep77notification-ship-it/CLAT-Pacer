// ============================================================================
// DAILY ARTICLE SERVICE
// Spec §6: fetch today's headlines (RssService), have Groq pick the single
// most CLAT-relevant story and write an original CLAT-style passage + 5
// MCQs + 5 flashcards from it, in one call. This is the live replacement
// for main.dart's old hardcoded `todaysSprint` constant, and the same
// output doubles as seed content for the GK/Current-Affairs quiz mode
// (built as a follow-up step reusing this service).
//
// This is a single Groq call (not batched like GroqService's Legal
// Reasoning generator) — total output here (~450-500 word passage + 5
// questions + 5 short flashcards) runs well under the model's 8,000
// tokens/minute free-tier cap on its own.
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/daily_sprint_models.dart';
import 'rss_service.dart';

const String _kGroqModel = 'qwen/qwen3.8-27b';
const String _kGroqChatUrl =
    'https://api.groq.com/openai/v1/chat/completions';

const int _kMaxAttempts = 4;
const List<Duration> _kRetryDelays = [
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

class DailyArticleException implements Exception {
  final String message;
  DailyArticleException(this.message);
  @override
  String toString() => message;
}

const String _systemPrompt = '''
You are a CLAT (Common Law Admission Test) content writer producing the
daily Current Affairs passage. You will be given a list of today's news
headlines from Indian sources. Your job:

1. Pick the SINGLE most CLAT-relevant story — prioritize law, judiciary,
   Parliament/legislation, constitutional matters, and major national or
   international events with civic/legal significance. Prefer the kind of
   story that would plausibly appear in a CLAT UG Current Affairs section.
2. Write an ORIGINAL ~450-500 word passage in CLAT comprehension-passage
   style about that story's topic, using your own general knowledge of the
   subject — this is an educational passage inspired by the headline, not a
   verbatim reproduction of any article or quote.
3. Write exactly 5 multiple-choice questions testing comprehension of the
   passage (4 options each, one correct).
4. Write exactly 5 short flashcard facts related to the passage's topic —
   each a short standalone fact a student should remember.

IMPORTANT RULES:
- Respond entirely in English. Do not include any non-English characters,
  words, or scripts anywhere in your output.
- Do not restate the options as text inside a question's own text — options
  belong only in the options array.
- Always provide exactly 4 options per question, and exactly 5 questions
  and 5 flashcards total.
''';

class DailyArticleService {
  static Future<PassageModel> generateTodaysSprint({
    required String apiKey,
  }) async {
    final headlines = await RssService.fetchAllHeadlines();

    // Keep the prompt compact: the most recent ~15 headlines across all
    // feeds is plenty of choice without ballooning input tokens.
    final candidates = headlines.take(15).toList();
    final headlinesText = candidates
        .map((h) =>
            '- [${h.source}] ${h.title}${h.description != null ? ' — ${h.description}' : ''}')
        .join('\n');

    for (var attempt = 1; attempt <= _kMaxAttempts; attempt++) {
      http.Response response;
      try {
        response = await http
            .post(
              Uri.parse(_kGroqChatUrl),
              headers: {
                'Authorization': 'Bearer $apiKey',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'model': _kGroqModel,
                'messages': [
                  {'role': 'system', 'content': _systemPrompt},
                  {
                    'role': 'user',
                    'content':
                        "Today's headlines:\n$headlinesText\n\nPick the single most CLAT-relevant story and generate the passage, questions, and flashcards via the submit_daily_passage tool.",
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
          await Future.delayed(_kRetryDelays[attempt - 1]);
          continue;
        }
        throw DailyArticleException(
            'Groq is rate-limiting requests right now. Try again in a minute.');
      }

      if (response.statusCode != 200) {
        throw DailyArticleException('Groq returned HTTP ${response.statusCode}.');
      }

      return _parsePassage(response.body);
    }

    throw DailyArticleException('Failed after $_kMaxAttempts attempts.');
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
        'required': ['title', 'body', 'questions', 'flashcards'],
      },
    },
  };

  static PassageModel _parsePassage(String responseBody) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (_) {
      throw DailyArticleException('Could not parse Groq\'s response.');
    }

    List<dynamic> toolCalls;
    try {
      toolCalls = body['choices'][0]['message']['tool_calls'] as List<dynamic>;
    } catch (_) {
      throw DailyArticleException('Groq did not call the expected tool.');
    }
    if (toolCalls.isEmpty) {
      throw DailyArticleException('Groq\'s response had no tool call in it.');
    }

    Map<String, dynamic> args;
    try {
      final rawArgs = toolCalls[0]['function']['arguments'] as String;
      args = jsonDecode(rawArgs) as Map<String, dynamic>;
    } catch (_) {
      throw DailyArticleException('Could not parse Groq\'s tool arguments.');
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
        throw DailyArticleException('Groq\'s response was missing questions or flashcards.');
      }

      return PassageModel(
        title: args['title'] as String,
        body: args['body'] as String,
        questions: questions,
        flashcards: flashcards,
      );
    } catch (e) {
      throw DailyArticleException(
          'Passage format from Groq didn\'t match what was expected ($e).');
    }
  }
}
