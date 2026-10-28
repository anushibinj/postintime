import 'package:flutter_test/flutter_test.dart';
import 'package:postintime/logic/bulk_publish_time.dart';
import 'package:postintime/models/models.dart';

final now = DateTime(2026, 10, 23, 15, 0, 0);
DateTime minutes(num value) => now.add(Duration(milliseconds: (value * 60000).round()));

BulkPublishJob job(List<({BulkPublishItemStatus status, DateTime? scheduledAt, DateTime? processedAt})> items) {
  return BulkPublishJob(
    id: 'job',
    channelId: 'channel',
    intervalMinutes: 5,
    status: BulkPublishJobStatus.running,
    totalItems: items.length,
    processedItems: 0,
    failedItems: 0,
    socialAccountIds: const ['account'],
    createdAt: now,
    updatedAt: now,
    items: [
      for (var i = 0; i < items.length; i++)
        BulkPublishItem(
          id: 'item-$i',
          postId: 'post-$i',
          postTitle: 'Post $i',
          position: i,
          status: items[i].status,
          scheduledAt: items[i].scheduledAt ?? now,
          processedAt: items[i].processedAt,
        ),
    ],
  );
}

void main() {
  group('bulk publish time', () {
    test('describes how long until a post goes live', () {
      expect(formatRelativeMinutes(minutes(-1), now), 'any moment now');
      expect(formatRelativeMinutes(minutes(12), now), 'in 12 min');
      expect(formatRelativeMinutes(minutes(11.2), now), 'in 12 min');
      expect(formatRelativeMinutes(minutes(60), now), 'in 1 h');
      expect(formatRelativeMinutes(minutes(95), now), 'in 1 h 35 min');
    });

    test('formats the clock time, adding the date when it is not today', () {
      expect(formatQueuedAt(minutes(45), now), '3:45 PM (in 45 min)');
      expect(formatQueuedAt(minutes(24 * 60), now), 'Oct 24, 3:00 PM (in 24 h)');
    });

    test('finds the queue tail from queued slots and posts that already went out', () {
      expect(queueTail([]), isNull);
      expect(
        queueTail([
          job([
            (status: BulkPublishItemStatus.published, scheduledAt: null, processedAt: minutes(-3)),
            (status: BulkPublishItemStatus.pending, scheduledAt: minutes(20), processedAt: null),
            (status: BulkPublishItemStatus.cancelled, scheduledAt: minutes(40), processedAt: null),
          ]),
        ]),
        minutes(20),
      );
    });

    test('starts a new batch one interval after the tail, or right away when idle', () {
      expect(firstSlot(null, 10, now), now);
      expect(firstSlot(minutes(-30), 10, now), now);
      expect(firstSlot(minutes(-3), 10, now), minutes(7));
      expect(firstSlot(minutes(20), 5, now), minutes(25));
    });
  });
}
