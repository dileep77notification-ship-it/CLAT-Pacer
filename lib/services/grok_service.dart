// ============================================================================
// GROQ SERVICE
// (File kept at its original path/history — grok_service.dart — to avoid
// import churn. The class below is GroqService, not GrokService: Groq
// (api.groq.com, this file) and Grok (xAI, the original provider) are two
// different companies with near-identical names. Rename this file to
// groq_service.dart at the next convenient refactor to remove the mismatch.)
//
// OpenAI-compatible REST client against Groq's API, used for all CLAT
// question generation. Groq's free tier has no billing, but is tightly
// capped at 8,000 tokens/minute for this model (confirmed at
// console.groq.com/settings/limits — see CLAT App spec §6.1). So every
// generator here splits into small batches with a pause between them,
// rather than one request per question or one giant request for N
// questions — which is also what lets this scale to a future 120-question
// mock (§8) without a rewrite.
//
// Covers three sections so far:
//   - generateQuestions()               -> Legal Reasoning (principle + facts)
//   - generateGkQuestions()             -> GK / Current Affairs
//                                          (headline-grounded + a minority
//                                          of static GK)
//   - generateLogicalReasoningQuestions() -> Logical Reasoning (short
//                                          argument/passage + assumption /
//                                          inference / strengthen / weaken /
//                                          conclusion questions)
//   - generateQuantQuestions()          -> Quantitative Techniques (short
//                                          data-driven passage + basic-maths
//                                          question; no charts/images — the
//                                          data is spelled out in the text
//                                          itself, since this app only
//                                          renders text)
//   - generateEnglishQuestions()        -> English / Reading Comprehension
//                                          (one ~450-500 word original
//                                          passage per 5 questions, rotating
//                                          through RC archetypes — built for
//                                          Full Mock Test Mode, §8)
// All return the same generic QuizQuestion shape (quiz_models.dart) and
// share the batching/backoff machinery below. English is the one generator
// that doesn't use flat per-question batches — it groups questions under a
// shared passage (see generateEnglishQuestions) — but still paces itself
// with the same pause/backoff constants.
//
// MODEL: pinned below. Swap this string if the model changes.
// ============================================================================

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quiz_models.dart';
import 'rss_service.dart';

const String kGroqModel = 'qwen/qwen3.8-27b'; // <-- swap here if model changes
const String _kGroqChatUrl =
    'https://api.groq.com/openai/v1/chat/completions';

// Stay comfortably under this model's free-tier 8,000 tokens/minute cap.
// Six questions per batch, with observed ~450-900 output tokens/question
// plus prompt overhead, lands well under that ceiling even on the high end.
const int _kMaxQuestionsPerBatch = 6;
const Duration _kBatchPause = Duration(seconds: 10);

const int _kMaxAttempts = 4;
const List<Duration> _kRetryDelays = [
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

// Rules repeated verbatim in every system prompt below — added after real
// failures observed while testing this model directly: (1) it occasionally
// leaks non-English tokens into English output, and (2) it tends to restate
// the options as text inside the question field, wasting tokens and
// truncating the explanation.
const String _kOutputRules = '''
IMPORTANT RULES:
- Respond entirely in English. Do not include any non-English characters,
  words, or scripts anywhere in your output.
- Put option text ONLY inside the "options" array of the submit tool call.
  Never restate, number, list, or summarize the options inside the
  "question" field — the question field must end at the question itself,
  with no "Options:" text appended to it.
- Always provide exactly 4 options per question.
- Each question must be fully self-contained (no reference to a passage or
  to other questions).
''';

const String _kLegalReasoningSystemPrompt = '''
You are a CLAT (Common Law Admission Test) question setter. Generate fresh
Legal Reasoning multiple-choice questions in the CLAT UG pattern: each
question states a short legal principle, then a short factual scenario, and
asks the candidate to apply the principle to the facts. Invent new
principles and facts in that style — never copy real past-paper text. Vary
difficulty and legal subject area (contract, tort, criminal, constitutional,
family law).

For every question, set the "topic" field to whichever of these the
question's legal subject area is: contract, tort, criminal, constitutional,
family_law.

$_kOutputRules
''';

const String _kLogicalReasoningSystemPrompt = '''
You are a CLAT (Common Law Admission Test) question setter for the Logical
Reasoning section. Generate fresh multiple-choice questions in the CLAT UG
pattern: each question gives a short argument or short passage (2-4
sentences, never longer — this is NOT the Reading Comprehension section),
followed by ONE question about that argument. Invent new arguments every
time — never copy real past-paper text, and never reuse the same scenario
across two questions in the same batch.

Rotate the question across these archetypes, covering a DIFFERENT one on
each question in the batch (never repeat the same archetype twice in a row):
- Assumption: "Which of the following is an assumption the argument above
  depends on?"
- Inference: "Which of the following can be logically inferred from the
  passage above?"
- Strengthen: "Which of the following, if true, would most strengthen the
  argument above?"
- Weaken: "Which of the following, if true, would most seriously weaken the
  argument above?"
- Conclusion / main point: "Which of the following best expresses the main
  conclusion of the argument above?"

State the archetype's question explicitly at the end of the "question"
field (after the argument text), exactly as worded above or close to it, so
the candidate knows what is being asked.

Set the "topic" field to exactly which archetype you used for that
question: assumption, inference, strengthen, weaken, or conclusion.

$_kOutputRules
''';

const String _kQuantSystemPrompt = '''
You are a CLAT (Common Law Admission Test) question setter for the
Quantitative Techniques section. Generate fresh multiple-choice questions in
the CLAT UG pattern: a short passage (2-4 sentences) that states some
numeric facts — e.g. sales figures for a few years, prices of a few items,
a simple ratio or percentage scenario, ages, distances, or a small set of
data points described in PLAIN SENTENCES or a short inline list (never as
an image, chart, graph, or table that needs to be drawn — this app only
displays text, so every number the question needs must appear written out
in the question text itself) — followed by ONE question that requires a
basic (class 10 level) calculation on that data: percentage change,
average, ratio/proportion, simple/compound interest, profit/loss, speed-
distance-time, or straightforward data interpretation (e.g. "which year had
the highest growth"). Invent new numbers and scenarios every time — never
copy real past-paper text, and never reuse the same scenario twice in the
same batch. Vary the type of calculation across the batch.

Make sure the four options are numerically distinct and that exactly one is
the correct result of the calculation — double check the arithmetic before
answering. The "explanation" field must show the actual calculation steps
briefly (e.g. "320/400 x 100 = 80%"), not just restate the answer.

Set the "topic" field to exactly which kind of calculation the question
uses: percentage, ratio, average, interest, profit_loss,
speed_distance_time, or data_interpretation.

$_kOutputRules
''';

const int _kQuestionsPerPassage = 5;

const String _kEnglishSystemPrompt = '''
You are a CLAT (Common Law Admission Test) question setter for the English
Language / Reading Comprehension section. Write ONE original non-fiction
passage of about 450-500 words — vary the subject across calls (law,
science, history, society, economics, culture, biography are all fair
game; it does NOT need to be current-affairs related). Never reproduce or
closely paraphrase a real published text — write entirely original prose in
a clear, exam-appropriate register.

Then write exactly the requested number of multiple-choice questions about
THAT passage, rotating across these archetypes (cover a DIFFERENT one on
each question, never repeat the same archetype twice in a row within the
set):
- Main idea: "Which of the following best captures the central idea of the
  passage?"
- Inference: "Which of the following can be inferred from the passage?"
- Vocabulary-in-context: "As used in the passage, the word '___' most
  nearly means" (pick a real word actually used in your passage).
- Author's tone/attitude: "The author's tone/attitude toward [X] can best
  be described as?"
- Supported/unsupported statement: "Which of the following statements is
  NOT supported by the passage?" (or "is supported by")

Every question must be answerable from the passage alone. Do not put the
passage text in the "question" field — the question field holds only the
question itself (the passage is submitted once, separately).

For every question, set the "topic" field to exactly which archetype you
used: main_idea, inference, vocabulary, tone, or supported_statement.

$_kOutputRules
''';

const String _kGkSystemPromptTemplate = '''
You are a CLAT (Common Law Admission Test) question setter for the GK &
Current Affairs section. Generate fresh multiple-choice questions that match
the real CLAT GK/Current Affairs mix: roughly 70% should be grounded in the
recent news headlines supplied below (ask about what happened, who/what was
involved, or the significance of the event — not just "which headline is
this"), and the remaining 30% should be static general knowledge relevant
to a CLAT candidate (Indian polity and constitution, static legal/landmark
facts, notable national and international organizations, important static
facts of the kind that appear in CLAT GK regardless of the day's news).
These proportions are a guideline, not an exact quota.
Spread the headline-based questions across DIFFERENT headlines below —
never write more than one or two questions on the same story. Do not quote
the headlines verbatim; write original questions inspired by them.

TODAY'S HEADLINES (for grounding the current-affairs questions):
%HEADLINES%

For every question, set the "topic" field to whichever of these fits best:
polity, economy, legal_current_affairs, or static_gk.

$_kOutputRules
''';

class GroqApiException implements Exception {
  final String message;
  GroqApiException(this.message);
  @override
  String toString() => message;
}

class GroqService {
  /// Generates [count] Legal Reasoning MCQs, internally split into batches
  /// of up to [_kMaxQuestionsPerBatch] with a pause between batches to stay
  /// under Groq's free-tier tokens/minute cap. Safe to call with count=10
  /// (today's Legal Reasoning Test) or a much larger count later (a full
  /// mock) without changes at the call site. [onProgress], if given, is
  /// called after each batch completes with (questions generated so far,
  /// total requested) so the UI can show real progress on multi-batch runs.
  static Future<List<QuizQuestion>> generateQuestions({
    required String apiKey,
    int count = 10,
    void Function(int generated, int total)? onProgress,
  }) {
    return _generateInBatches(
      apiKey: apiKey,
      count: count,
      systemPrompt: _kLegalReasoningSystemPrompt,
      userInstruction: (n) =>
          'Generate exactly $n fresh Legal Reasoning MCQs now via the submit_mcqs tool.',
      onProgress: onProgress,
    );
  }

  /// Generates [count] GK / Current Affairs MCQs grounded in [headlines]
  /// (pass `RssService.fetchAllHeadlines()`'s result — most-recent-first is
  /// fine, this takes the top ~15 itself). Same batching/pacing/backoff as
  /// [generateQuestions].
  static Future<List<QuizQuestion>> generateGkQuestions({
    required String apiKey,
    required List<RssHeadline> headlines,
    int count = 10,
    void Function(int generated, int total)? onProgress,
  }) {
    final top = headlines.take(15).toList();
    final headlinesBlock = top.isEmpty
        ? '(no headlines available today — base all questions on static GK instead)'
        : top
            .asMap()
            .entries
            .map((e) => '${e.key + 1}. [${e.value.source}] ${e.value.title}')
            .join('\n');

    final systemPrompt =
        _kGkSystemPromptTemplate.replaceFirst('%HEADLINES%', headlinesBlock);

    return _generateInBatches(
      apiKey: apiKey,
      count: count,
      systemPrompt: systemPrompt,
      userInstruction: (n) =>
          'Generate exactly $n fresh GK/Current Affairs MCQs now via the submit_mcqs tool, following the 70/30 headline/static-GK mix and spreading across different headlines.',
      onProgress: onProgress,
    );
  }

  /// Generates [count] Logical Reasoning MCQs (short argument + assumption /
  /// inference / strengthen / weaken / conclusion question, rotated across
  /// the batch). Same batching/pacing/backoff as [generateQuestions].
  static Future<List<QuizQuestion>> generateLogicalReasoningQuestions({
    required String apiKey,
    int count = 10,
    void Function(int generated, int total)? onProgress,
  }) {
    return _generateInBatches(
      apiKey: apiKey,
      count: count,
      systemPrompt: _kLogicalReasoningSystemPrompt,
      userInstruction: (n) =>
          'Generate exactly $n fresh Logical Reasoning MCQs now via the submit_mcqs tool, rotating through the assumption/inference/strengthen/weaken/conclusion archetypes.',
      onProgress: onProgress,
    );
  }

  /// Generates [count] Quantitative Techniques MCQs (short numeric passage
  /// + basic-maths question). Same batching/pacing/backoff as
  /// [generateQuestions]. The data the question needs is always spelled out
  /// in the passage text itself — there is no chart/image rendering in this
  /// app, so the model is instructed never to rely on one.
  static Future<List<QuizQuestion>> generateQuantQuestions({
    required String apiKey,
    int count = 10,
    void Function(int generated, int total)? onProgress,
  }) {
    return _generateInBatches(
      apiKey: apiKey,
      count: count,
      systemPrompt: _kQuantSystemPrompt,
      userInstruction: (n) =>
          'Generate exactly $n fresh Quantitative Techniques MCQs now via the submit_mcqs tool. Double-check every calculation before submitting.',
      onProgress: onProgress,
    );
  }

  /// Generates [count] English/RC MCQs, grouped into passages of up to
  /// [_kQuestionsPerPassage] questions each (so count=10 -> 2 passages,
  /// count=14 -> 3 passages of 5/5/4). Each passage is its own request —
  /// generating the passage and its questions together keeps them
  /// consistent — with the same [_kBatchPause]/backoff pacing as the other
  /// generators between passages. Every returned QuizQuestion carries its
  /// passage's text in [QuizQuestion.passage] so the (shared) quiz-taking UI
  /// can show it above the question.
  static Future<List<QuizQuestion>> generateEnglishQuestions({
    required String apiKey,
    int count = 10,
    void Function(int generated, int total)? onProgress,
  }) async {
    final questions = <QuizQuestion>[];
    var remaining = count;
    var isFirstPassage = true;

    while (remaining > 0) {
      final passageSize =
          remaining > _kQuestionsPerPassage ? _kQuestionsPerPassage : remaining;

      if (!isFirstPassage) {
        await Future.delayed(_kBatchPause);
      }
      isFirstPassage = false;

      final passageQuestions = await _generatePassageBatch(
        apiKey: apiKey,
        questionCount: passageSize,
      );
      questions.addAll(passageQuestions);
      remaining -= passageSize;
      onProgress?.call(questions.length, count);
    }

    return questions;
  }

  static Future<List<QuizQuestion>> _generatePassageBatch({
    required String apiKey,
    required int questionCount,
  }) async {
    final userContent =
        'Write one original ~450-500 word passage and exactly $questionCount questions about it now, via the submit_rc_passage tool, rotating through the main-idea/inference/vocabulary/tone/supported-statement archetypes.';

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
                'model': kGroqModel,
                'messages': [
                  {'role': 'system', 'content': _kEnglishSystemPrompt},
                  {'role': 'user', 'content': userContent},
                ],
                'tools': [_submitRcPassageTool(questionCount)],
                'tool_choice': {
                  'type': 'function',
                  'function': {'name': 'submit_rc_passage'},
                },
                // Passage (~450-500 words, ~650-700 tokens) plus
                // questionCount questions.
                'max_tokens': 900 * questionCount + 1200,
              }),
            )
            .timeout(const Duration(seconds: 60));
      } catch (e) {
        if (attempt < _kMaxAttempts) {
          await Future.delayed(_kRetryDelays[attempt - 1]);
          continue;
        }
        throw GroqApiException('Network error — $e');
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw GroqApiException('API key was rejected. Check it in Settings.');
      }

      if (response.statusCode == 429 || response.statusCode == 503) {
        if (attempt < _kMaxAttempts) {
          await Future.delayed(_kRetryDelays[attempt - 1]);
          continue;
        }
        throw GroqApiException(
            'Groq is rate-limiting requests right now. Try again in a minute.');
      }

      if (response.statusCode != 200) {
        throw GroqApiException('Groq returned HTTP ${response.statusCode}.');
      }

      return _parsePassageBatch(response.body);
    }

    throw GroqApiException('Failed after $_kMaxAttempts attempts.');
  }

  static Map<String, dynamic> _submitRcPassageTool(int questionCount) => {
        'type': 'function',
        'function': {
          'name': 'submit_rc_passage',
          'description':
              'Submit one original RC passage and $questionCount questions about it.',
          'parameters': {
            'type': 'object',
            'properties': {
              'passage_title': {'type': 'string'},
              'passage_body': {'type': 'string'},
              'questions': {
                'type': 'array',
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
                    'correct_index': {
                      'type': 'integer',
                      'description': '0-based index into options',
                    },
                    'explanation': {'type': 'string'},
                    'topic': {
                      'type': 'string',
                      'description':
                          'Which RC archetype this question uses: main_idea, inference, vocabulary, tone, or supported_statement.',
                    },
                  },
                  'required': [
                    'question',
                    'options',
                    'correct_index',
                    'explanation',
                    'topic',
                  ],
                },
              },
            },
            'required': ['passage_title', 'passage_body', 'questions'],
          },
        },
      };

  static List<QuizQuestion> _parsePassageBatch(String responseBody) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (_) {
      throw GroqApiException('Could not parse Groq\'s response.');
    }

    List<dynamic> toolCalls;
    try {
      toolCalls = body['choices'][0]['message']['tool_calls'] as List<dynamic>;
    } catch (_) {
      throw GroqApiException('Groq did not call the expected tool.');
    }

    if (toolCalls.isEmpty) {
      throw GroqApiException('Groq\'s response had no tool call in it.');
    }

    Map<String, dynamic> args;
    try {
      final rawArgs = toolCalls[0]['function']['arguments'] as String;
      args = jsonDecode(rawArgs) as Map<String, dynamic>;
    } catch (_) {
      throw GroqApiException('Could not parse Groq\'s tool arguments.');
    }

    final passageBody = args['passage_body'] as String?;
    if (passageBody == null || passageBody.trim().isEmpty) {
      throw GroqApiException('Groq\'s response had no passage text in it.');
    }

    final rawQuestions = args['questions'];
    if (rawQuestions is! List || rawQuestions.isEmpty) {
      throw GroqApiException('Groq\'s response had no questions in it.');
    }

    try {
      return rawQuestions
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>)
              .copyWith(passage: passageBody))
          .toList();
    } catch (e) {
      throw GroqApiException(
          'Question format from Groq didn\'t match what was expected ($e).');
    }
  }

  static Future<List<QuizQuestion>> _generateInBatches({
    required String apiKey,
    required int count,
    required String systemPrompt,
    required String Function(int batchCount) userInstruction,
    void Function(int generated, int total)? onProgress,
  }) async {
    final questions = <QuizQuestion>[];
    var remaining = count;
    var isFirstBatch = true;

    while (remaining > 0) {
      final batchSize = remaining > _kMaxQuestionsPerBatch
          ? _kMaxQuestionsPerBatch
          : remaining;

      if (!isFirstBatch) {
        await Future.delayed(_kBatchPause);
      }
      isFirstBatch = false;

      final batch = await _generateBatch(
        apiKey: apiKey,
        count: batchSize,
        systemPrompt: systemPrompt,
        userContent: userInstruction(batchSize),
      );
      questions.addAll(batch);
      remaining -= batchSize;
      onProgress?.call(questions.length, count);
    }

    return questions;
  }

  static Future<List<QuizQuestion>> _generateBatch({
    required String apiKey,
    required int count,
    required String systemPrompt,
    required String userContent,
  }) async {
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
                'model': kGroqModel,
                'messages': [
                  {'role': 'system', 'content': systemPrompt},
                  {'role': 'user', 'content': userContent},
                ],
                'tools': [_submitMcqsTool(count)],
                'tool_choice': {
                  'type': 'function',
                  'function': {'name': 'submit_mcqs'},
                },
                // Generous ceiling, not a target — actual usage per
                // question has run ~450-900 tokens in testing.
                'max_tokens': 900 * count + 500,
              }),
            )
            .timeout(const Duration(seconds: 60));
      } catch (e) {
        if (attempt < _kMaxAttempts) {
          await Future.delayed(_kRetryDelays[attempt - 1]);
          continue;
        }
        throw GroqApiException('Network error — $e');
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw GroqApiException('API key was rejected. Check it in Settings.');
      }

      if (response.statusCode == 429 || response.statusCode == 503) {
        if (attempt < _kMaxAttempts) {
          await Future.delayed(_kRetryDelays[attempt - 1]);
          continue;
        }
        throw GroqApiException(
            'Groq is rate-limiting requests right now. Try again in a minute.');
      }

      if (response.statusCode != 200) {
        throw GroqApiException('Groq returned HTTP ${response.statusCode}.');
      }

      return _parseBatch(response.body);
    }

    throw GroqApiException('Failed after $_kMaxAttempts attempts.');
  }

  static Map<String, dynamic> _submitMcqsTool(int count) => {
        'type': 'function',
        'function': {
          'name': 'submit_mcqs',
          'description': 'Submit $count generated CLAT MCQs.',
          'parameters': {
            'type': 'object',
            'properties': {
              'questions': {
                'type': 'array',
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
                    'correct_index': {
                      'type': 'integer',
                      'description': '0-based index into options',
                    },
                    'explanation': {'type': 'string'},
                    'topic': {
                      'type': 'string',
                      'description':
                          'The topic/sub-area bucket for this question, from the allowed list given in the system prompt.',
                    },
                  },
                  'required': [
                    'question',
                    'options',
                    'correct_index',
                    'explanation',
                    'topic',
                  ],
                },
              },
            },
            'required': ['questions'],
          },
        },
      };

  static List<QuizQuestion> _parseBatch(String responseBody) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(responseBody) as Map<String, dynamic>;
    } catch (_) {
      throw GroqApiException('Could not parse Groq\'s response.');
    }

    List<dynamic> toolCalls;
    try {
      toolCalls = body['choices'][0]['message']['tool_calls'] as List<dynamic>;
    } catch (_) {
      throw GroqApiException('Groq did not call the expected tool.');
    }

    if (toolCalls.isEmpty) {
      throw GroqApiException('Groq\'s response had no tool call in it.');
    }

    Map<String, dynamic> args;
    try {
      final rawArgs = toolCalls[0]['function']['arguments'] as String;
      args = jsonDecode(rawArgs) as Map<String, dynamic>;
    } catch (_) {
      throw GroqApiException('Could not parse Groq\'s tool arguments.');
    }

    final rawQuestions = args['questions'];
    if (rawQuestions is! List || rawQuestions.isEmpty) {
      throw GroqApiException('Groq\'s response had no questions in it.');
    }

    try {
      return rawQuestions
          .map((q) => QuizQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw GroqApiException(
          'Question format from Groq didn\'t match what was expected ($e).');
    }
  }
}
