import 'package:flutter/scheduler.dart';

/// Opt-in measurements for controlled acceptance builds. No codes/tokens/payloads.
class FeedbackProbe {
  FeedbackProbe._();
  static const enabled = bool.fromEnvironment('CAPTURE_FEEDBACK_METRICS');
  static Stopwatch? _watch;
  static String _source = '';
  static final List<Map<String, Object>> samples = [];

  static void begin(String source) {
    if (!enabled) return;
    _source = source;
    _watch = Stopwatch()..start();
  }

  static void rendered(String outcome) {
    if (!enabled || _watch == null) return;
    final watch = _watch!;
    final source = _source;
    _watch = null;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      watch.stop();
      samples.add({
        'input': source,
        'outcome': outcome,
        'durationMs': watch.elapsedMicroseconds / 1000,
      });
    });
  }

  static void reset() {
    _watch = null;
    samples.clear();
  }
}
