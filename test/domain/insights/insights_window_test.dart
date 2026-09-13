import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_planner/domain/insights/insights_window.dart';

void main() {
  group('resolveWeeks', () {
    final now = DateTime(2026, 9, 13);

    test('eightWeeks always resolves to 8, regardless of data', () {
      expect(resolveWeeks(InsightsWindow.eightWeeks, [], now), 8);
    });

    test('sixMonths resolves to 26 weeks', () {
      expect(resolveWeeks(InsightsWindow.sixMonths, [], now), 26);
    });

    test('oneYear resolves to 52 weeks', () {
      expect(resolveWeeks(InsightsWindow.oneYear, [], now), 52);
    });

    test('all with no data clamps to the 8-week floor', () {
      expect(resolveWeeks(InsightsWindow.all, [], now), 8);
    });

    test('all with a short history clamps to the 8-week floor', () {
      final dates = [now.subtract(const Duration(days: 10))];

      expect(resolveWeeks(InsightsWindow.all, dates, now), 8);
    });

    test('all spans from the earliest date to now, rounded up to whole weeks', () {
      final dates = [
        now.subtract(const Duration(days: 140)), // exactly 20 weeks
        now.subtract(const Duration(days: 30)),
      ];

      expect(resolveWeeks(InsightsWindow.all, dates, now), 20);
    });

    test('all with a very long history clamps to the 156-week ceiling', () {
      final dates = [now.subtract(const Duration(days: 365 * 5))];

      expect(resolveWeeks(InsightsWindow.all, dates, now), 156);
    });
  });

  group('bucketingFor', () {
    test('is weekly at or below 26 weeks', () {
      expect(bucketingFor(8), Bucketing.weekly);
      expect(bucketingFor(26), Bucketing.weekly);
    });

    test('is four-weekly beyond 26 weeks', () {
      expect(bucketingFor(27), Bucketing.fourWeekly);
      expect(bucketingFor(156), Bucketing.fourWeekly);
    });
  });
}
