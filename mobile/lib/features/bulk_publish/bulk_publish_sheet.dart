import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../logic/bulk_publish_interval.dart';
import '../../logic/bulk_publish_time.dart';
import '../../models/models.dart';
import '../../state/now_provider.dart';
import '../../widgets/app_alert.dart';

class BulkPublishSelection {
  const BulkPublishSelection({required this.id, required this.title});

  final String id;
  final String title;
}

/// Pick the interval and accounts for bulk posting the selected posts.
class BulkPublishSheet extends ConsumerStatefulWidget {
  const BulkPublishSheet({
    super.key,
    required this.posts,
    required this.accounts,
    required this.queueTail,
    required this.queuedCount,
    required this.submitting,
    required this.onCancel,
    required this.onSubmit,
  });

  final List<BulkPublishSelection> posts;
  final List<SocialAccount> accounts;

  /// Latest queued slot (or latest bulk post) in this channel; new posts are queued after it.
  final DateTime? queueTail;

  /// Posts already waiting in the channel's queue.
  final int queuedCount;
  final bool submitting;
  final VoidCallback onCancel;
  final void Function(int intervalMinutes, List<String> socialAccountIds) onSubmit;

  @override
  ConsumerState<BulkPublishSheet> createState() => _BulkPublishSheetState();
}

class _BulkPublishSheetState extends ConsumerState<BulkPublishSheet> {
  int _interval = bulkIntervalDefault;
  // Accounts the user unticked; every other webhook account is picked, including ones that load later.
  final Set<String> _excludedIds = {};

  @override
  Widget build(BuildContext context) {
    final now = currentNow(ref);
    final posts = widget.posts;
    final enabled = widget.accounts.where((account) => account.enabled).toList();
    final webhookAccounts = enabled.where((account) => account.postingMode == PostingMode.webhook).toList();
    final manualAccounts = enabled.where((account) => account.postingMode == PostingMode.manual).toList();
    final pickedIds = webhookAccounts
        .where((account) => !_excludedIds.contains(account.id))
        .map((account) => account.id)
        .toList();
    final first = firstSlot(widget.queueTail, _interval, now);
    final last = first.add(Duration(minutes: _interval * (posts.length - 1).clamp(0, 1 << 30)));
    final startsNow = !first.isAfter(now);
    final plural = posts.length == 1 ? 'post' : 'posts';
    final theFirst = posts.length > 1 ? 'first post' : 'post';

    final summary = StringBuffer();
    if (widget.queuedCount > 0) {
      summary.write(
        '${widget.queuedCount} ${widget.queuedCount == 1 ? 'post is' : 'posts are'} already queued; '
        'these join the end of the queue. ',
      );
    }
    summary.write(
      startsNow ? 'The $theFirst goes live right away' : 'The $theFirst goes live at ${formatQueuedAt(first, now)}',
    );
    summary.write(
      posts.length > 1
          ? ', then one every $_interval minutes. The last post goes live at ${formatQueuedAt(last, now)}.'
          : '.',
    );

    final canStart = pickedIds.isNotEmpty && posts.isNotEmpty && !widget.submitting;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bulk post ${posts.length} $plural', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Interval between posts', style: TextStyle(fontWeight: FontWeight.w600)),
            // The track is inset by the overlay radius, which is pinned here so the labels below can
            // sit exactly under the slider's stops.
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                overlayShape: const RoundSliderOverlayShape(overlayRadius: _sliderInset),
                trackShape: const RoundedRectSliderTrackShape(),
                thumbShape: const RoundSliderThumbShape(),
              ),
              child: Semantics(
                label: 'Interval between posts in minutes',
                child: Slider(
                  min: bulkIntervalMin.toDouble(),
                  max: bulkIntervalMax.toDouble(),
                  divisions: (bulkIntervalMax - bulkIntervalMin) ~/ bulkIntervalStep,
                  value: _interval.toDouble(),
                  label: '$_interval min',
                  onChanged: (value) => setState(() => _interval = normalizeInterval(value)),
                ),
              ),
            ),
            _IntervalMarks(selected: _interval),
            const SizedBox(height: 16),
            Text(summary.toString(), style: AppText.secondary),
            const SizedBox(height: 16),
            if (webhookAccounts.isEmpty)
              const AppAlert(
                type: AlertType.error,
                title: 'No webhook social accounts',
                description:
                    "Bulk posting calls each account's webhook. Enable or add a webhook social account "
                    'for this channel first.',
              )
            else
              _AccountPicker(
                webhookAccounts: webhookAccounts,
                manualAccounts: manualAccounts,
                pickedIds: pickedIds,
                onChanged: (excluded) => setState(() {
                  _excludedIds
                    ..clear()
                    ..addAll(excluded);
                }),
              ),
            const SizedBox(height: 16),
            const Text('Order', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: posts.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 28, child: Text('${index + 1}.', style: AppText.secondary)),
                      Expanded(child: Text(posts[index].title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Accounts are called one after another. If a post fails, the failure is logged and the batch moves '
              'on to the next post. Posting runs on the server, so you can leave this page.',
              style: AppText.secondarySmall,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: widget.submitting ? null : widget.onCancel, child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canStart ? () => widget.onSubmit(_interval, pickedIds) : null,
                  child: widget.submitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Start bulk posting'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// How far the slider's track is inset from its edges.
const double _sliderInset = 24;

/// The `5m … 30m` labels, each centred under its stop on the slider.
class _IntervalMarks extends StatelessWidget {
  const _IntervalMarks({required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context) {
    final marks = intervalMarks().entries.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final step = (constraints.maxWidth - 2 * _sliderInset) / (marks.length - 1);
        return SizedBox(
          height: 18,
          child: Stack(
            children: [
              for (var i = 0; i < marks.length; i++)
                Positioned(
                  left: _sliderInset + i * step - 20,
                  width: 40,
                  child: Text(
                    marks[i].value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: marks[i].key == selected ? AppColors.primary : AppColors.secondaryText,
                      fontWeight: marks[i].key == selected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountPicker extends StatelessWidget {
  const _AccountPicker({
    required this.webhookAccounts,
    required this.manualAccounts,
    required this.pickedIds,
    required this.onChanged,
  });

  final List<SocialAccount> webhookAccounts;
  final List<SocialAccount> manualAccounts;
  final List<String> pickedIds;

  /// Called with the ids that are now excluded.
  final void Function(Set<String> excludedIds) onChanged;

  @override
  Widget build(BuildContext context) {
    final allIds = webhookAccounts.map((account) => account.id).toSet();
    final picked = pickedIds.toSet();
    final allPicked = picked.length == webhookAccounts.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Post to', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            if (webhookAccounts.length > 1)
              InkWell(
                onTap: () => onChanged(allPicked ? allIds : <String>{}),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      tristate: true,
                      semanticLabel: 'All accounts',
                      value: allPicked ? true : (picked.isEmpty ? false : null),
                      onChanged: (_) => onChanged(allPicked ? allIds : <String>{}),
                    ),
                    const Text('All accounts'),
                  ],
                ),
              ),
          ],
        ),
        for (final account in webhookAccounts)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(account.name),
            value: picked.contains(account.id),
            onChanged: (value) {
              final excluded = allIds.difference(picked);
              if (value ?? false) {
                excluded.remove(account.id);
              } else {
                excluded.add(account.id);
              }
              onChanged(excluded);
            },
          ),
        if (pickedIds.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Pick at least one social account to start bulk posting.',
              style: TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
        if (manualAccounts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Manual accounts (${manualAccounts.map((account) => account.name).join(', ')}) are skipped.',
              style: AppText.secondarySmall,
            ),
          ),
      ],
    );
  }
}
