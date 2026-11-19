// ============================================================================
// RSS SERVICE
// Fetches today's headlines from the feeds validated in CLAT App spec §13.2,
// plus two added for broader daily-editorial coverage (Nov 2026):
//   - Indian Express — Explained (indianexpress.com/section/explained/feed/):
//     confirmed working, standard WordPress feed.
//   - LiveLaw — Top Stories (livelaw.in/category/mobile-notification/
//     google_feeds.xml): LiveLaw's own /feed/ and /rss.xml endpoints still
//     don't work (500 / 404, same as originally found), but this category
//     feed is LiveLaw's actual top-stories/breaking-news feed under a
//     different URL pattern, and it validated cleanly — Supreme Court/High
//     Court rulings tagged Top Stories, Constitutional Law, Criminal Law
//     etc. PRS Legislative Research and PIB were checked too: PRS has no
//     discoverable RSS feed, and PIB's only working feeds are Hindi-language
//     (ModId params all resolved to Devanagari content) — both skipped
//     rather than wired in half-working.
//
// Dart has no built-in XML parser, so this uses the `xml` package
// (pub.dev) — added to pubspec.yaml.
// ============================================================================

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;

class RssHeadline {
  final String title;
  final String link;
  final String? description;
  final String source;
  final DateTime? pubDate;

  const RssHeadline({
    required this.title,
    required this.link,
    required this.source,
    this.description,
    this.pubDate,
  });
}

class RssFeed {
  final String name;
  final String url;
  const RssFeed(this.name, this.url);
}

const List<RssFeed> _kFeeds = [
  RssFeed('The Hindu — National',
      'https://www.thehindu.com/news/national/feeder/default.rss'),
  RssFeed('The Hindu — Editorial',
      'https://www.thehindu.com/opinion/editorial/feeder/default.rss'),
  RssFeed('Bar & Bench', 'https://www.barandbench.com/feed'),
  RssFeed('Indian Express — Explained',
      'https://indianexpress.com/section/explained/feed/'),
  RssFeed('LiveLaw — Top Stories',
      'https://www.livelaw.in/category/mobile-notification/google_feeds.xml'),
];

class RssServiceException implements Exception {
  final String message;
  RssServiceException(this.message);
  @override
  String toString() => message;
}

class RssService {
  /// Fetches all configured feeds in parallel, skipping any that fail
  /// rather than failing the whole call — matches spec §6's "combine
  /// multiple sources" design, since no single feed is required to work.
  /// Throws only if every feed fails.
  static Future<List<RssHeadline>> fetchAllHeadlines() async {
    final results = await Future.wait(
      _kFeeds.map((feed) => _fetchFeed(feed).catchError((_) => <RssHeadline>[])),
    );

    final all = results.expand((list) => list).toList();
    if (all.isEmpty) {
      throw RssServiceException(
          'Could not reach any news source. Check your internet connection.');
    }

    // Most recent first, so the Sarvam prompt sees today's news first.
    all.sort((a, b) {
      if (a.pubDate == null && b.pubDate == null) return 0;
      if (a.pubDate == null) return 1;
      if (b.pubDate == null) return -1;
      return b.pubDate!.compareTo(a.pubDate!);
    });

    return all;
  }

  static Future<List<RssHeadline>> _fetchFeed(RssFeed feed) async {
    final response = await http
        .get(Uri.parse(feed.url),
            headers: {'User-Agent': 'Mozilla/5.0 (compatible; ClatPacer/1.0)'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      return [];
    }

    xml.XmlDocument doc;
    try {
      doc = xml.XmlDocument.parse(response.body);
    } catch (_) {
      return [];
    }

    final items = doc.findAllElements('item');
    final headlines = <RssHeadline>[];
    for (final item in items) {
      final title = item.findElements('title').firstOrNull?.innerText.trim();
      if (title == null || title.isEmpty) continue;
      final link = item.findElements('link').firstOrNull?.innerText.trim() ?? '';
      final descRaw =
          item.findElements('description').firstOrNull?.innerText.trim();
      final pubDateRaw =
          item.findElements('pubDate').firstOrNull?.innerText.trim();

      DateTime? pubDate;
      if (pubDateRaw != null) {
        try {
          pubDate = _parseRfc822(pubDateRaw);
        } catch (_) {
          pubDate = null;
        }
      }

      headlines.add(RssHeadline(
        title: title,
        link: link,
        source: feed.name,
        description: (descRaw != null && descRaw.isNotEmpty) ? descRaw : null,
        pubDate: pubDate,
      ));
    }
    return headlines;
  }

  /// Minimal RFC 822 date parser (RSS pubDate format, e.g.
  /// "Wed, 28 Oct 2026 17:21:58 +0530"). http package / intl aren't pulled
  /// in just for this — DateTime.parse doesn't handle the weekday prefix
  /// or named-ish offset format reliably, so this strips to what it needs.
  static DateTime _parseRfc822(String raw) {
    // Drop leading "Wed, " if present.
    final commaIndex = raw.indexOf(',');
    final cleaned = (commaIndex != -1 ? raw.substring(commaIndex + 1) : raw).trim();
    // "28 Oct 2026 17:21:58 +0530"
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length < 5) throw FormatException('Unexpected date format: $raw');

    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    final day = int.parse(parts[0]);
    final month = months[parts[1]] ?? (throw FormatException('Bad month: $raw'));
    final year = int.parse(parts[2]);
    final timeParts = parts[3].split(':').map(int.parse).toList();
    final offsetRaw = parts[4]; // e.g. "+0530"

    var utc = DateTime.utc(year, month, day, timeParts[0], timeParts[1],
        timeParts.length > 2 ? timeParts[2] : 0);

    if (offsetRaw.length == 5 && (offsetRaw.startsWith('+') || offsetRaw.startsWith('-'))) {
      final sign = offsetRaw.startsWith('-') ? -1 : 1;
      final offHours = int.parse(offsetRaw.substring(1, 3));
      final offMinutes = int.parse(offsetRaw.substring(3, 5));
      utc = utc.subtract(Duration(hours: sign * offHours, minutes: sign * offMinutes));
    }

    return utc;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
