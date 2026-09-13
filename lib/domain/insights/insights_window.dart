/// How far back an Insights chart or ledger looks. [all] has no fixed
/// length — it's resolved against the user's actual history by
/// [resolveWeeks].
enum InsightsWindow { eightWeeks, sixMonths, oneYear, all }

/// How many weeks a chart bucket covers. Beyond 26 weeks a weekly bar
/// chart has too many bars to read, so longer windows roll up into
/// four-week buckets instead. This is a domain decision, not a chart
/// concern, so every consumer of a window agrees on where the switch
/// happens.
enum Bucketing { weekly, fourWeekly }

const int _kMinWeeks = 8;
const int _kMaxWeeks = 156;

/// Resolves [window] to a concrete week count. The fixed windows are
/// literal; [InsightsWindow.all] spans from the earliest of [dates] to
/// [now], rounded up to whole weeks and clamped to `[8, 156]` — the floor
/// keeps a brand-new account from rendering a near-empty chart, and the
/// ceiling keeps years of history from producing an unbounded scan.
int resolveWeeks(InsightsWindow window, List<DateTime> dates, DateTime now) {
  switch (window) {
    case InsightsWindow.eightWeeks:
      return 8;
    case InsightsWindow.sixMonths:
      return 26;
    case InsightsWindow.oneYear:
      return 52;
    case InsightsWindow.all:
      if (dates.isEmpty) return _kMinWeeks;
      final earliest = dates.reduce((a, b) => a.isBefore(b) ? a : b);
      final days = now.difference(earliest).inDays;
      final weeks = (days / 7).ceil();
      return weeks.clamp(_kMinWeeks, _kMaxWeeks);
  }
}

/// The bucketing a chart covering [weeks] should use.
Bucketing bucketingFor(int weeks) => weeks <= 26 ? Bucketing.weekly : Bucketing.fourWeekly;
