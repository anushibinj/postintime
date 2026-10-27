import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../api/posts_api.dart';
import '../../models/models.dart';
import '../../state/data_providers.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/error_view.dart';
import '../../widgets/page_loader.dart';
import 'post_card.dart';
import 'posts_pager.dart';

/// Search and filter a channel's posts.
class PostListPage extends ConsumerStatefulWidget {
  const PostListPage({super.key, required this.channelId, this.initialPage = 0, this.initialSize = 20});

  final String channelId;
  final int initialPage;
  final int initialSize;

  @override
  ConsumerState<PostListPage> createState() => _PostListPageState();
}

class _PostListPageState extends ConsumerState<PostListPage> {
  final _searchController = TextEditingController();
  late int _page = widget.initialPage;
  late int _size = widget.initialSize;
  String _search = '';
  PostStatus? _status;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setFilters({String? search, PostStatus? status, bool clearStatus = false}) {
    setState(() {
      if (search != null) _search = search.trim();
      if (status != null) _status = status;
      if (clearStatus) _status = null;
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final channelId = widget.channelId;
    final key = (
      channelId: channelId,
      filters: PostFilters(page: _page, size: _size, search: _search, status: _status),
    );
    final posts = ref.watch(postsProvider(key));
    final data = posts.value;

    return Scaffold(
      appBar: AppBar(
        leading: AppBackButton(fallback: '/channels/$channelId'),
        title: const Text('Posts'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => context.push('/channels/$channelId/posts/new'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Post'),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(postsProvider(key));
          await ref.read(postsProvider(key).future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => _setFilters(search: value),
              decoration: InputDecoration(
                hintText: 'Search posts...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _setFilters(search: '');
                        },
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<PostStatus?>(
                emptySelectionAllowed: false,
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: null, label: Text('All')),
                  ButtonSegment(value: PostStatus.draft, label: Text('Draft')),
                  ButtonSegment(value: PostStatus.ready, label: Text('Ready')),
                ],
                selected: {_status},
                onSelectionChanged: (selection) {
                  final next = selection.first;
                  next == null ? _setFilters(clearStatus: true) : _setFilters(status: next);
                },
              ),
            ),
            const SizedBox(height: 16),
            if (posts.hasError && data == null)
              ErrorView(
                message: errorMessage(posts.error!, 'Could not load posts'),
                onRetry: () => ref.invalidate(postsProvider(key)),
              )
            else if (data == null)
              const PageLoader()
            else ...[
              PostList(posts: data.items, channelId: channelId),
              PostsPager(
                page: data.page,
                size: data.size,
                totalItems: data.totalItems,
                onChange: (page, size) => setState(() {
                  _page = page;
                  _size = size;
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
