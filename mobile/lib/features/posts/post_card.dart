import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/media_api.dart';
import '../../app/theme.dart';
import '../../logic/bulk_publish_time.dart';
import '../../models/models.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../state/now_provider.dart';
import '../../widgets/app_tag.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/platform_style.dart';

// Requested at twice the displayed size so thumbnails stay sharp on dense screens.
const double _thumbSize = 64;
const int _thumbRequestSize = 128;
const double _iconSize = 36;

class PostCard extends ConsumerStatefulWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.channelId,
    required this.accounts,
    required this.now,
    this.onSelectChange,
    this.selected = false,
  });

  final Post post;
  final String channelId;
  final List<SocialAccount> accounts;

  /// Current time, for the "in 12 min" label of queued posts.
  final DateTime now;

  /// When provided, the row shows a checkbox for bulk actions.
  final ValueChanged<bool>? onSelectChange;
  final bool selected;

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _toggling = false;

  Future<void> _toggle(SocialAccount account) async {
    setState(() => _toggling = true);
    try {
      await ref
          .read(publishingActionsProvider((channelId: widget.channelId, postId: widget.post.id)))
          .togglePublished(account.id);
    } catch (error) {
      if (mounted) {
        await showErrorDialog(
          context,
          title: 'Publish failed',
          message: errorMessage(error, 'Could not update publish status'),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _toggling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final selected = widget.selected;
    final targets = post.targets ?? const <PostTargetSummary>[];
    final enabledAccounts = widget.accounts.where((account) => account.enabled).toList();
    // Queued posts are published by the bulk posting queue only.
    final queuedAt = post.bulkPublishScheduledAt;
    final queued = queuedAt != null;
    final caption = post.caption;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? AppColors.selectedBackground : AppColors.surface,
        border: Border.all(color: selected ? AppColors.primary : AppColors.rowBorder),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.onSelectChange != null)
                // Kept outside the tap target so toggling the checkbox never opens the post.
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _wrapQueuedHint(
                    queued,
                    Checkbox(
                      semanticLabel: 'Select ${post.title}',
                      value: selected && !queued,
                      onChanged: queued ? null : (value) => widget.onSelectChange!(value ?? false),
                    ),
                  ),
                ),
              Expanded(
                // One accessible button named after the whole row (title, caption, queue status).
                child: MergeSemantics(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(kRadius),
                    onTap: () => context.push('/channels/${widget.channelId}/posts/${post.id}'),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(widget.onSelectChange != null ? 4 : 12, 12, 12, 12),
                      child: Row(
                        children: [
                          PostThumb(url: post.media?.url, title: post.title),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  post.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (caption != null && caption.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      caption,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppText.secondary,
                                    ),
                                  ),
                                if (queuedAt != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: AppTag(
                                      'Queued for posting at ${formatQueuedAt(queuedAt, widget.now)}',
                                      tone: TagTone.processing,
                                      icon: Icons.schedule,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (enabledAccounts.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(widget.onSelectChange != null ? 48 : 12, 0, 12, 12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final account in enabledAccounts)
                    AccountToggle(
                      account: account,
                      posted: targets.any(
                        (target) => target.socialAccountId == account.id && target.status == TargetStatus.published,
                      ),
                      disabled: _toggling,
                      locked: queued,
                      onToggle: () => _toggle(account),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Widget _wrapQueuedHint(bool queued, Widget child) =>
    queued ? Tooltip(message: 'Already queued for bulk posting', child: child) : child;

/// One square button per enabled social account: tap to send the webhook, or mark / unmark it as posted.
class AccountToggle extends StatelessWidget {
  const AccountToggle({
    super.key,
    required this.account,
    required this.posted,
    required this.disabled,
    required this.locked,
    required this.onToggle,
  });

  final SocialAccount account;
  final bool posted;
  final bool disabled;

  /// The post is in the bulk posting queue and cannot be posted individually.
  final bool locked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = platformColor(account.platform);
    final webhook = account.isWebhook;
    final actionLabel = posted
        ? 'Unmark ${account.name}'
        : webhook
        ? 'Send webhook for ${account.name}'
        : 'Mark ${account.name} as posted';
    final tooltip =
        '${account.name} · ${webhook ? 'Webhook' : 'Manual'} · ${posted ? 'Posted' : 'Not posted'}'
        '${locked ? ' · Queued for bulk posting' : ''}';

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        toggled: posted,
        enabled: !disabled && !locked,
        label: actionLabel,
        excludeSemantics: true,
        child: Opacity(
          opacity: locked ? 0.5 : 1,
          child: Material(
            color: posted ? color : AppColors.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kRadius),
              side: BorderSide(color: posted ? color : AppColors.rowBorder),
            ),
            child: InkWell(
              customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadius)),
              onTap: disabled || locked ? null : onToggle,
              child: SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Text(
                      platformGlyph(account.platform),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: posted ? Colors.white : AppColors.secondaryText,
                      ),
                    ),
                    if (posted)
                      Positioned(
                        right: -4,
                        bottom: -4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.check, size: 8, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PostThumb extends StatelessWidget {
  const PostThumb({super.key, this.url, required this.title});

  final String? url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: _thumbSize,
      height: _thumbSize,
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(kRadius)),
      child: const Icon(Icons.image_not_supported_outlined, size: 20, color: AppColors.disabledText),
    );
    final imageUrl = url;
    if (imageUrl == null || imageUrl.isEmpty) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(kRadius),
      child: CachedNetworkImage(
        imageUrl: mediaUrlWithSize(imageUrl, _thumbRequestSize),
        width: _thumbSize,
        height: _thumbSize,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

/// A channel's posts as bordered rows, with optional selection for bulk actions.
class PostList extends ConsumerWidget {
  const PostList({super.key, required this.posts, required this.channelId, this.selectedIds, this.onSelectChange});

  final List<Post> posts;
  final String channelId;
  final Set<String>? selectedIds;
  final void Function(Post post, bool checked)? onSelectChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(socialAccountsProvider(channelId)).value ?? const <SocialAccount>[];
    final now = currentNow(ref);

    if (posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: AppColors.disabledText),
              SizedBox(height: 8),
              Text('No posts yet', style: AppText.secondary),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final post in posts)
          PostCard(
            key: ValueKey(post.id),
            post: post,
            channelId: channelId,
            accounts: accounts,
            now: now,
            selected: selectedIds?.contains(post.id) ?? false,
            onSelectChange: onSelectChange == null ? null : (checked) => onSelectChange!(post, checked),
          ),
      ],
    );
  }
}
