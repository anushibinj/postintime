import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/posts_api.dart';
import '../../app/theme.dart';
import '../../logic/bulk_publish_time.dart';
import '../../models/models.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/error_view.dart';
import '../../widgets/page_loader.dart';
import '../../widgets/toast.dart';
import '../bulk_publish/bulk_publish_jobs.dart';
import '../bulk_publish/bulk_publish_sheet.dart';
import '../posts/post_card.dart';
import '../posts/posts_pager.dart';

class ChannelDetailPage extends ConsumerStatefulWidget {
  const ChannelDetailPage({super.key, required this.channelId, this.initialPage = 0, this.initialSize = 20});

  final String channelId;
  final int initialPage;
  final int initialSize;

  @override
  ConsumerState<ChannelDetailPage> createState() => _ChannelDetailPageState();
}

class _ChannelDetailPageState extends ConsumerState<ChannelDetailPage> {
  late int _page = widget.initialPage;
  late int _size = widget.initialSize;

  /// Selected post titles keyed by id; insertion order is the bulk posting order. The selection
  /// survives paging but not switching channels.
  final Map<String, String> _selected = {};

  @override
  void didUpdateWidget(ChannelDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelId != widget.channelId) {
      _selected.clear();
      _page = widget.initialPage;
      _size = widget.initialSize;
    }
  }

  PostsKey get _postsKey =>
      (channelId: widget.channelId, filters: PostFilters(page: _page, size: _size, sort: 'updatedAt,desc'));

  void _selectPost(Post post, bool checked) {
    setState(() {
      if (checked) {
        _selected[post.id] = post.title;
      } else {
        _selected.remove(post.id);
      }
    });
  }

  void _selectPage(List<Post> selectable, bool checked) {
    setState(() {
      for (final post in selectable) {
        if (checked) {
          _selected[post.id] = post.title;
        } else {
          _selected.remove(post.id);
        }
      }
    });
  }

  void _openBulkSheet() {
    final posts = [for (final entry in _selected.entries) BulkPublishSelection(id: entry.key, title: entry.value)];
    showFormSheet<void>(
      context,
      builder: (_) =>
          _BulkSheetHost(channelId: widget.channelId, posts: posts, onStarted: () => setState(_selected.clear)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final channelId = widget.channelId;
    final channel = ref.watch(channelProvider(channelId));
    final postsAsync = ref.watch(postsProvider(_postsKey));
    final pageData = postsAsync.value;
    final pagePosts = pageData?.items ?? const <Post>[];
    // Posts already in the bulk posting queue cannot be queued again.
    final selectable = pagePosts.where((post) => post.bulkPublishScheduledAt == null).toList();
    final selectedOnPage = selectable.where((post) => _selected.containsKey(post.id)).length;

    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(fallback: '/channels'),
        title: Text(channel.value?.name ?? 'Channel'),
        actions: [
          IconButton(
            tooltip: 'Search posts',
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/channels/$channelId/posts'),
          ),
        ],
      ),
      body: AsyncValueView<Channel>(
        value: channel,
        onRetry: () => ref.invalidate(channelProvider(channelId)),
        data: (channel) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(bulkJobsProvider(channelId));
            ref.invalidate(socialAccountsProvider(channelId));
            ref.invalidate(channelProvider(channelId));
            ref.invalidate(postsProvider(_postsKey));
            await ref.read(postsProvider(_postsKey).future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (channel.description != null && channel.description!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(channel.description!, style: AppText.secondary),
                ),
              Text(
                '${channel.postCount} posts · ${channel.socialAccountCount} social accounts',
                style: AppText.secondary,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/channels/$channelId/social-accounts'),
                  icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                  label: const Text('Manage social accounts'),
                ),
              ),
              const SizedBox(height: 24),
              BulkPublishJobs(channelId: channelId),
              Row(
                children: [
                  Expanded(child: Text('Posts', style: Theme.of(context).textTheme.titleMedium)),
                  FilledButton.icon(
                    onPressed: () => context.push('/channels/$channelId/posts/new'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New Post'),
                  ),
                ],
              ),
              if (pagePosts.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    InkWell(
                      onTap: selectable.isEmpty
                          ? null
                          : () => _selectPage(selectable, selectedOnPage != selectable.length),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            tristate: true,
                            semanticLabel: 'Select page',
                            value: selectable.isNotEmpty && selectedOnPage == selectable.length
                                ? true
                                : (selectedOnPage > 0 ? null : false),
                            onChanged: selectable.isEmpty
                                ? null
                                : (_) => _selectPage(selectable, selectedOnPage != selectable.length),
                          ),
                          const Text('Select page'),
                        ],
                      ),
                    ),
                    if (_selected.isNotEmpty) ...[
                      Text('${_selected.length} selected', style: AppText.secondary),
                      TextButton(
                        onPressed: () => setState(_selected.clear),
                        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        child: const Text('Clear'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _openBulkSheet,
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Bulk post'),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 8),
              if (postsAsync.hasError && pageData == null)
                ErrorView(
                  message: errorMessage(postsAsync.error!, 'Could not load posts'),
                  onRetry: () => ref.invalidate(postsProvider(_postsKey)),
                )
              else if (pageData == null)
                const PageLoader()
              else ...[
                PostList(
                  posts: pagePosts,
                  channelId: channelId,
                  selectedIds: _selected.keys.toSet(),
                  onSelectChange: _selectPost,
                ),
                PostsPager(
                  page: pageData.page,
                  size: pageData.size,
                  totalItems: pageData.totalItems,
                  onChange: (page, size) => setState(() {
                    _page = page;
                    _size = size;
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Feeds the bulk posting sheet with the channel's accounts and queue, and starts the job.
class _BulkSheetHost extends ConsumerStatefulWidget {
  const _BulkSheetHost({required this.channelId, required this.posts, required this.onStarted});

  final String channelId;
  final List<BulkPublishSelection> posts;
  final VoidCallback onStarted;

  @override
  ConsumerState<_BulkSheetHost> createState() => _BulkSheetHostState();
}

class _BulkSheetHostState extends ConsumerState<_BulkSheetHost> {
  bool _submitting = false;

  Future<void> _start(int intervalMinutes, List<String> socialAccountIds) async {
    setState(() => _submitting = true);
    final count = widget.posts.length;
    try {
      await ref
          .read(bulkPublishActionsProvider(widget.channelId))
          .create(
            postIds: [for (final post in widget.posts) post.id],
            intervalMinutes: intervalMinutes,
            socialAccountIds: socialAccountIds,
          );
      Toast.success('Added $count ${count == 1 ? 'post' : 'posts'} to the bulk posting queue');
      widget.onStarted();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      Toast.error(errorMessage(error, 'Could not start bulk posting'));
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(socialAccountsProvider(widget.channelId)).value ?? const <SocialAccount>[];
    final jobs = ref.watch(bulkJobsProvider(widget.channelId)).value ?? const <BulkPublishJob>[];
    final queuedCount = jobs.fold<int>(
      0,
      (count, job) =>
          count +
          job.items
              .where(
                (item) =>
                    item.status == BulkPublishItemStatus.pending || item.status == BulkPublishItemStatus.publishing,
              )
              .length,
    );
    return BulkPublishSheet(
      posts: widget.posts,
      accounts: accounts,
      queueTail: queueTail(jobs),
      queuedCount: queuedCount,
      submitting: _submitting,
      onCancel: () => Navigator.of(context).pop(),
      onSubmit: _start,
    );
  }
}
