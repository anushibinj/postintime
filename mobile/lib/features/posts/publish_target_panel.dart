import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../app/theme.dart';
import '../../core/external_links.dart';
import '../../models/models.dart';
import '../../state/actions.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/toast.dart';

/// One publishing target of a post: its status, and the action to publish it.
class PublishTargetPanel extends ConsumerStatefulWidget {
  const PublishTargetPanel({
    super.key,
    required this.target,
    required this.post,
    required this.channelId,
    required this.postId,
    this.locked = false,
  });

  final PostTarget target;
  final Post post;
  final String channelId;
  final String postId;

  /// The post is in the bulk posting queue, so it cannot be published individually.
  final bool locked;

  @override
  ConsumerState<PublishTargetPanel> createState() => _PublishTargetPanelState();
}

class _PublishTargetPanelState extends ConsumerState<PublishTargetPanel> {
  bool _publishing = false;

  PublishingActions get _actions =>
      ref.read(publishingActionsProvider((channelId: widget.channelId, postId: widget.postId)));

  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      final result = await _actions.publish(widget.target.id);
      if (mounted) {
        setState(() => _publishing = false);
      }
      if (result.publishingMode == PostingMode.webhook) {
        Toast.success('Webhook published');
        return;
      }
      if (mounted) {
        await showFormSheet<void>(
          context,
          builder: (_) => ManualPublishSheet(
            target: widget.target,
            post: widget.post,
            onMarkPublished: () => _actions.markPublished(widget.target.id),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        await showErrorDialog(context, title: 'Publish failed', message: errorMessage(error, 'Publish failed'));
      }
    } finally {
      if (mounted) {
        setState(() => _publishing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
    final publishedAt = target.publishedAt;
    final canPublish = target.status == TargetStatus.pending && !widget.locked;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(target.socialAccount.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      StatusBadge(target.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    publishedAt != null
                        ? DateFormat('MMM d, yyyy h:mm a', 'en_US').format(publishedAt.toLocal())
                        : target.socialAccount.platform.name,
                    style: AppText.secondarySmall,
                  ),
                ],
              ),
            ),
            if (canPublish)
              _publishing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(tooltip: 'Publish', icon: const Icon(Icons.send_outlined), onPressed: _publish),
          ],
        ),
      ),
    );
  }
}

/// What to do to post manually: copy the caption, save the image, open the destination, then confirm.
class ManualPublishSheet extends StatefulWidget {
  const ManualPublishSheet({super.key, required this.target, required this.post, required this.onMarkPublished});

  final PostTarget target;
  final Post post;
  final Future<void> Function() onMarkPublished;

  @override
  State<ManualPublishSheet> createState() => _ManualPublishSheetState();
}

class _ManualPublishSheetState extends State<ManualPublishSheet> {
  bool _marking = false;

  Future<void> _copyCaption() async {
    await Clipboard.setData(ClipboardData(text: widget.post.caption ?? ''));
    Toast.success('Caption copied');
  }

  Future<void> _markPublished() async {
    setState(() => _marking = true);
    try {
      await widget.onMarkPublished();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      Toast.success('Marked as published');
    } catch (error) {
      Toast.error(errorMessage(error, 'Could not mark as published'));
      if (mounted) {
        setState(() => _marking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.target.socialAccount;
    final mediaUrl = widget.post.media?.url;
    final profileUrl = account.profileUrl;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Publish to ${account.name}', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          const Text('Caption', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(kRadius)),
            child: SelectableText(widget.post.caption ?? ''),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _copyCaption,
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Caption'),
            ),
          ),
          if (mediaUrl != null && mediaUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Media', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(kRadius),
              child: Image.network(mediaUrl, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => openExternal(mediaUrl),
                icon: const Icon(Icons.download, size: 16),
                label: const Text('Download Image'),
              ),
            ),
          ],
          if (profileUrl != null && profileUrl.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('Destination', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(profileUrl),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => openExternal(profileUrl),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text('Open ${account.platform.name}'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _marking ? null : _markPublished,
            icon: _marking
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check, size: 18),
            label: const Text('Mark as Published'),
          ),
        ],
      ),
    );
  }
}
