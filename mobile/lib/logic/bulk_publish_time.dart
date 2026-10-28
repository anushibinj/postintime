import 'package:intl/intl.dart';

import '../models/models.dart';

const int _minuteMs = 60000;

bool _isSameDay(DateTime a, DateTime b) {
  final x = a.toLocal();
  final y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

String formatRelativeMinutes(DateTime target, DateTime now) {
  final minutes = (target.difference(now).inMicroseconds / (_minuteMs * 1000)).ceil();
  if (minutes <= 0) {
    return 'any moment now';
  }
  if (minutes < 60) {
    return 'in $minutes min';
  }
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? 'in $hours h' : 'in $hours h $rest min';
}

/// "3:45 PM (in 12 min)", with the date added when it is not today.
String formatQueuedAt(DateTime target, DateTime now) {
  final local = target.toLocal();
  final clock = _isSameDay(target, now)
      ? DateFormat('h:mm a', 'en_US').format(local)
      : DateFormat('MMM d, h:mm a', 'en_US').format(local);
  return '$clock (${formatRelativeMinutes(target, now)})';
}

/// The latest queued slot, or the start of the latest bulk post that already went out.
DateTime? queueTail(List<BulkPublishJob> jobs) {
  DateTime? tail;
  for (final job in jobs) {
    for (final item in job.items) {
      // A post being published right now counts from when it started (processedAt).
      final at = item.status == BulkPublishItemStatus.pending ? item.scheduledAt : item.processedAt;
      if (at != null && (tail == null || at.isAfter(tail))) {
        tail = at;
      }
    }
  }
  return tail;
}

/// When the first post of a new batch goes live (mirrors BulkPublishService on the backend).
DateTime firstSlot(DateTime? tail, int intervalMinutes, DateTime now) {
  final next = tail == null ? now : tail.add(Duration(minutes: intervalMinutes));
  return next.isAfter(now) ? next : now;
}
