import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../app/theme.dart';
import '../../logic/bulk_publish_time.dart';
import '../../models/models.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../state/now_provider.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/collapse_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/toast.dart';

const int _recentLimit = 20;

const _itemTones = {
  BulkPublishItemStatus.pending: TagTone.neutral,
  BulkPublishItemStatus.publishing: TagTone.processing,
  BulkPublishItemStatus.published: TagTone.success,
  BulkPublishItemStatus.partial: TagTone.warning,
  BulkPublishItemStatus.failed: TagTone.error,
  BulkPublishItemStatus.skipped: TagTone.neutral,
  BulkPublishItemStatus.cancelled: TagTone.neutral,
};

class _QueueEntry {
  const _QueueEntry(this.job, this.item);

  final BulkPublishJob job;
  final BulkPublishItem item;
}

String? _progressKey(List<BulkPublishJob>? jobs) =>
    jobs?.map((job) => '${job.id}:${job.processedItems}').join(',');

/// The channel's bulk posting queue plus the most recent bulk posts that already went out.
class BulkPublishJobs extends ConsumerStatefulWidget {
  const BulkPublishJobs({super.key, required this.channelId});

  final String channelId;

  @override
  ConsumerState<BulkPublishJobs> createState() => _BulkPublishJobsState();
}

class _BulkPublishJobsState extends ConsumerState<BulkPublishJobs> {
  bool _cancellingAll = false;
  String? _removingItemId;

  Future<void> _remove(_QueueEntry entry) async {
    setState(() => _removingItemId = entry.item.id);
    try {
      await ref.read(bulkPublishActionsProvider(widget.channelId)).cancelItem(entry.job.id, entry.item.id);
      Toast.success('Removed "${entry.item.postTitle}" from the queue');
    } catch (error) {
      Toast.error(errorMessage(error, 'Could not remove the post from the queue'));
    } finally {
      if (mounted) {
        setState(() => _removingItemId = null);
      }
    }
  }

  Future<void> _cancelAll(List<BulkPublishJob> jobs) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Cancel all queued posts?',
      content: 'Posts that have not gone live yet will not be posted.',
      okText: 'Cancel all',
      cancelText: 'Keep them',
      danger: true,
    );
    if (!confirmed) {
      return;
    }
    setState(() => _cancellingAll = true);
    try {
      for (final job in jobs.where((job) => job.status == BulkPublishJobStatus.running)) {
        await ref.read(bulkPublishActionsProvider(widget.channelId)).cancelJob(job.id);
      }
      Toast.success('Bulk posting queue cleared');
    } catch (error) {
      Toast.error(errorMessage(error, 'Could not clear the queue'));
    } finally {
      if (mounted) {
        setState(() => _cancellingAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelId = widget.channelId;
    // Refresh the post list (published badges, queued labels) whenever the queue publishes a post.
    ref.listen(bulkJobsProvider(channelId), (previous, next) {
      final before = _progressKey(previous?.value);
      final after = _progressKey(next.value);
      if (before != null && after != null && before != after) {
        ref.invalidate(postsProvider);
      }
    });

    final now = currentNow(ref);
    final jobs = ref.watch(bulkJobsProvider(channelId)).value ?? const <BulkPublishJob>[];
    final entries = [
      for (final job in jobs)
        for (final item in job.items) _QueueEntry(job, item),
    ];
    // Waiting posts plus the one being posted right now (its webhooks can take minutes).
    final queue = entries
        .where((e) => e.item.status == BulkPublishItemStatus.pending || e.item.status == BulkPublishItemStatus.publishing)
        .toList()
      ..sort((a, b) => a.item.scheduledAt.compareTo(b.item.scheduledAt));
    final recent = entries
        .where((e) => e.item.processedAt != null && e.item.status != BulkPublishItemStatus.publishing)
        .toList()
      ..sort((a, b) => b.item.processedAt!.compareTo(a.item.processedAt!));
    final recentShown = recent.take(_recentLimit).toList();

    if (queue.isEmpty && recentShown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (queue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: CollapsePanel(
                header: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Bulk posting queue', style: TextStyle(fontWeight: FontWeight.w600)),
                    AppTag('${queue.length} ${queue.length == 1 ? 'post' : 'posts'}', tone: TagTone.processing),
                    Text(
                      queue.first.item.status == BulkPublishItemStatus.publishing
                          ? 'Posting now'
                          : 'Next ${formatQueuedAt(queue.first.item.scheduledAt, now)}',
                      style: AppText.secondarySmall,
                    ),
                  ],
                ),
                extra: TextButton(
                  onPressed: _cancellingAll ? null : () => _cancelAll(jobs),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: _cancellingAll
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Cancel all'),
                ),
                body: Column(
                  children: [
                    for (var i = 0; i < queue.length; i++)
                      _QueueRow(
                        index: i + 1,
                        entry: queue[i],
                        now: now,
                        removing: _removingItemId == queue[i].item.id,
                        onRemove: () => _remove(queue[i]),
                      ),
                  ],
                ),
              ),
            ),
          if (recentShown.isNotEmpty)
            CollapsePanel(
              header: Text('Recent bulk posts (${recentShown.length})'),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final entry in recentShown) _RecentRow(item: entry.item)],
              ),
            ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.index,
    required this.entry,
    required this.now,
    required this.removing,
    required this.onRemove,
  });

  final int index;
  final _QueueEntry entry;
  final DateTime now;
  final bool removing;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final item = entry.item;
    final postingNow = item.status == BulkPublishItemStatus.publishing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 24, child: Text('$index.', style: AppText.secondary)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.postTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (postingNow)
                      const AppTag('Posting now', tone: TagTone.processing)
                    else
                      Text(
                        formatQueuedAt(item.scheduledAt, now),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    Text('${entry.job.intervalMinutes} min gap', style: AppText.secondarySmall),
                  ],
                ),
              ],
            ),
          ),
          if (removing)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: postingNow ? 'Being posted right now' : 'Remove ${item.postTitle} from the queue',
              icon: const Icon(Icons.close, size: 18),
              onPressed: postingNow ? null : onRemove,
            ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item});

  final BulkPublishItem item;

  @override
  Widget build(BuildContext context) {
    final error = item.errorMessage;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                DateFormat('MMM d, h:mm a', 'en_US').format(item.processedAt!.toLocal()),
                style: AppText.secondarySmall,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(item.postTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              AppTag(item.status.label, tone: _itemTones[item.status]!),
            ],
          ),
          if (error != null && error.isNotEmpty)
            Text(
              error,
              style: TextStyle(
                fontSize: 12,
                color: item.status == BulkPublishItemStatus.skipped ? AppColors.secondaryText : AppColors.danger,
              ),
            ),
        ],
      ),
    );
  }
}
