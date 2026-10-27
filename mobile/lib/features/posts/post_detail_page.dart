import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../app/theme.dart';
import '../../logic/bulk_publish_time.dart';
import '../../models/models.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../state/now_provider.dart';
import '../../widgets/app_alert.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/error_view.dart';
import '../../widgets/toast.dart';
import 'media_uploader.dart';
import 'post_status_picker.dart';
import 'publish_target_panel.dart';

class PostDetailPage extends ConsumerWidget {
  const PostDetailPage({super.key, required this.channelId, required this.postId});

  final String channelId;
  final String postId;

  PostKey get _key => (channelId: channelId, postId: postId);

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(context, title: 'Delete post?', okText: 'Delete', danger: true);
    if (!confirmed) {
      return;
    }
    try {
      await ref.read(postActionsProvider(channelId)).delete(postId);
      if (context.mounted) {
        context.canPop() ? context.pop() : context.go('/channels/$channelId');
      }
    } catch (error) {
      Toast.error(errorMessage(error, 'Failed to delete post'));
    }
  }

  Future<void> _addTargets(BuildContext context, WidgetRef ref, List<SocialAccount> candidates) async {
    await showFormSheet<void>(
      context,
      builder: (_) => _AddTargetsSheet(channelId: channelId, postId: postId, candidates: candidates),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = ref.watch(postProvider(_key));
    final targets = ref.watch(targetsProvider(_key)).value ?? const <PostTarget>[];
    final accounts = ref.watch(socialAccountsProvider(channelId)).value ?? const <SocialAccount>[];
    final now = currentNow(ref);

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(fallback: '/channels/$channelId'),
        title: const Text('View post'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: post.hasValue ? () => context.push('/channels/$channelId/posts/$postId/edit') : null,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: post.hasValue ? () => _delete(context, ref) : null,
          ),
        ],
      ),
      body: AsyncValueView<Post>(
        value: post,
        onRetry: () => ref.invalidate(postProvider(_key)),
        data: (post) {
          final queuedAt = post.bulkPublishScheduledAt;
          final summary = post.publicationSummary;
          final untargeted = accounts
              .where((account) => account.enabled && !targets.any((target) => target.socialAccount.id == account.id))
              .toList();
          final caption = post.caption ?? '';

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(targetsProvider(_key));
              ref.invalidate(socialAccountsProvider(channelId));
              ref.invalidate(postProvider(_key));
              await ref.read(postProvider(_key).future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Review the image, caption, and publishing status.', style: AppText.secondary),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Image', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        if (post.media != null && post.media!.url.isNotEmpty)
                          PostImage(url: post.media!.url, label: post.title)
                        else
                          const _NoImage(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Title', style: AppText.secondary),
                        const SizedBox(height: 8),
                        SelectableText(
                          post.title,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Caption', style: AppText.secondary),
                            Text('${caption.length} characters', style: AppText.secondary),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 120),
                          child: SelectableText(
                            caption.isEmpty ? 'No caption' : caption,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                        const SizedBox(height: 24),
                        PostStatusPicker(status: post.status),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text('Publishing', style: Theme.of(context).textTheme.titleMedium)),
                            if (untargeted.isNotEmpty)
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                onPressed: () => _addTargets(context, ref, untargeted),
                                child: const Text('Add Targets'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (queuedAt != null) ...[
                          AppAlert(
                            type: AlertType.info,
                            title: 'Queued for bulk posting at ${formatQueuedAt(queuedAt, now)}',
                            description: 'The bulk posting queue will publish this post. Remove it from the queue '
                                'on the channel page to post it individually.',
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (summary != null && summary.total > 0) ...[
                          Text('${summary.published} / ${summary.total} published', style: AppText.secondary),
                          const SizedBox(height: 12),
                        ],
                        if (targets.isEmpty)
                          const Text(
                            'No publishing targets yet. Add social accounts as targets.',
                            style: AppText.secondary,
                          )
                        else
                          for (final target in targets)
                            PublishTargetPanel(
                              key: ValueKey(target.id),
                              target: target,
                              post: post,
                              channelId: channelId,
                              postId: postId,
                              locked: queuedAt != null,
                            ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NoImage extends StatelessWidget {
  const _NoImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dashedBorder),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined, size: 40, color: AppColors.secondaryText),
          SizedBox(height: 8),
          Text('No image', style: AppText.secondary),
        ],
      ),
    );
  }
}

/// Pick which enabled social accounts become publishing targets of the post.
class _AddTargetsSheet extends ConsumerStatefulWidget {
  const _AddTargetsSheet({required this.channelId, required this.postId, required this.candidates});

  final String channelId;
  final String postId;
  final List<SocialAccount> candidates;

  @override
  ConsumerState<_AddTargetsSheet> createState() => _AddTargetsSheetState();
}

class _AddTargetsSheetState extends ConsumerState<_AddTargetsSheet> {
  final Set<String> _selected = {};
  bool _saving = false;

  Future<void> _save() async {
    if (_selected.isEmpty) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(publishingActionsProvider((channelId: widget.channelId, postId: widget.postId)))
          .createTargets(_selected.toList());
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      Toast.success('Targets added');
    } catch (error) {
      Toast.error(errorMessage(error, 'Could not add targets'));
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'Add Publishing Targets',
      okText: 'OK',
      onOk: _save,
      okEnabled: _selected.isNotEmpty,
      loading: _saving,
      child: Column(
        children: [
          for (final account in widget.candidates)
            CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('${account.name} (${account.platform.name})'),
              value: _selected.contains(account.id),
              onChanged: (checked) => setState(() {
                if (checked ?? false) {
                  _selected.add(account.id);
                } else {
                  _selected.remove(account.id);
                }
              }),
            ),
        ],
      ),
    );
  }
}
