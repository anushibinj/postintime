// Mirrors BulkPublishService on the backend. 0 posts back to back; the sheet still opens on 5.
import 'dart:math' as math;

const int bulkIntervalMin = 0;
const int bulkIntervalMax = 30;
const int bulkIntervalStep = 5;
const int bulkIntervalDefault = 5;

/// Snaps any value onto the allowed 0..30 minute grid.
int normalizeInterval(num value) {
  if (value.isNaN || value.isInfinite) {
    return bulkIntervalDefault;
  }
  // JavaScript's Math.round rounds halves up; Dart's num.round rounds them away from zero.
  final snapped = (value / bulkIntervalStep + 0.5).floor() * bulkIntervalStep;
  return math.min(bulkIntervalMax, math.max(bulkIntervalMin, snapped));
}

/// Every slider step with its label, e.g. `{0: '0m', 5: '5m', ...}`.
Map<int, String> intervalMarks() {
  return {for (var value = bulkIntervalMin; value <= bulkIntervalMax; value += bulkIntervalStep) value: '${value}m'};
}
