import '../models/models.dart';
import 'api_client.dart';

/// Filters for the channel post list; value equality lets them key a provider family.
class PostFilters {
  const PostFilters({this.page, this.size, this.search, this.status, this.sort});

  final int? page;
  final int? size;
  final String? search;
  final PostStatus? status;
  final String? sort;

  Map<String, dynamic> toQuery() => {
    if (page != null) 'page': page.toString(),
    if (size != null) 'size': size.toString(),
    if (search != null && search!.isNotEmpty) 'search': search,
    if (status != null) 'status': status!.name,
    if (sort != null && sort!.isNotEmpty) 'sort': sort,
  };

  @override
  bool operator ==(Object other) =>
      other is PostFilters &&
      other.page == page &&
      other.size == size &&
      other.search == search &&
      other.status == status &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(page, size, search, status, sort);
}

/// The backend accepts at most this many IDs per bulk delete request.
const int bulkDeleteLimit = 100;

class PostsApi {
  PostsApi(this._client);

  final ApiClient _client;

  Future<PageResponse<Post>> fetchPosts(String channelId, [PostFilters filters = const PostFilters()]) async {
    final json =
        await _client.get('/api/v1/channels/$channelId/posts', query: filters.toQuery()) as Map<String, dynamic>;
    return PageResponse.fromJson(json, Post.fromJson);
  }

  Future<Post> fetchPost(String channelId, String postId) async {
    final json = await _client.get('/api/v1/channels/$channelId/posts/$postId') as Map<String, dynamic>;
    return Post.fromJson(json);
  }

  Future<Post> createPost(
    String channelId, {
    required String title,
    String? caption,
    String? mediaId,
    required PostStatus status,
  }) async {
    final json = await _client.post(
      '/api/v1/channels/$channelId/posts',
      body: {'title': title, 'caption': ?caption, 'mediaId': ?mediaId, 'status': status.name},
    ) as Map<String, dynamic>;
    return Post.fromJson(json);
  }

  Future<Post> updatePost(
    String channelId,
    String postId, {
    String? title,
    String? caption,
    String? mediaId,
    PostStatus? status,
  }) async {
    final json = await _client.patch(
      '/api/v1/channels/$channelId/posts/$postId',
      body: {'title': ?title, 'caption': ?caption, 'mediaId': ?mediaId, if (status != null) 'status': status.name},
    ) as Map<String, dynamic>;
    return Post.fromJson(json);
  }

  Future<void> deletePost(String channelId, String postId) async {
    await _client.delete('/api/v1/channels/$channelId/posts/$postId');
  }

  /// Deletes the posts in batches of [bulkDeleteLimit] IDs and resolves to how many the server removed.
  Future<int> bulkDeletePosts(String channelId, List<String> postIds) async {
    var deleted = 0;
    for (var start = 0; start < postIds.length; start += bulkDeleteLimit) {
      final chunk = postIds.skip(start).take(bulkDeleteLimit).toList();
      final json = await _client.post(
        '/api/v1/channels/$channelId/posts/bulk-delete',
        body: {'postIds': chunk},
      ) as Map<String, dynamic>;
      deleted += json['deletedCount'] as int;
    }
    return deleted;
  }
}
