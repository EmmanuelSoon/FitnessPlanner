/// Formats a whole-second duration as a clock string, e.g. "4:52". Shared by
/// every place that displays a pace (seconds per km) or a held duration
/// (seconds) the same way, so they can't drift out of sync with each other.
String formatClock(int totalSeconds) {
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
