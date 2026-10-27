import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../models/models.dart';
import '../../state/actions.dart';
import '../../state/data_providers.dart';
import '../../widgets/error_view.dart';
import '../../widgets/toast.dart';
import 'media_uploader.dart';
import 'post_status_picker.dart';

/// Create a post, or edit the one with [postId].
class PostFormPage extends ConsumerStatefulWidget {
  const PostFormPage({super.key, required this.channelId, this.postId});

  final String channelId;
  final String? postId;

  @override
  ConsumerState<PostFormPage> createState() => _PostFormPageState();
}

class _PostFormPageState extends ConsumerState<PostFormPage> {
  final _title = TextEditingController();
  final _caption = TextEditingController();
  PostStatus _status = PostStatus.draft;
  MediaInfo? _media;
  bool _saving = false;
  bool _loaded = false;

  bool get _isEdit => widget.postId != null;

  @override
  void initState() {
    super.initState();
    _title.addListener(_rebuild);
    _caption.addListener(_rebuild);
    if (_isEdit) {
      // Fill the form once the post being edited has loaded (never while building).
      ref.listenManual(postProvider((channelId: widget.channelId, postId: widget.postId!)), (previous, next) {
        final post = next.value;
        if (post != null) {
          _load(post);
        }
      }, fireImmediately: true);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _caption.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  /// Fills the form from the post being edited, once.
  void _load(Post post) {
    if (_loaded) {
      return;
    }
    _loaded = true;
    _title.text = post.title;
    _caption.text = post.caption ?? '';
    _status = post.status;
    _media = post.media;
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    // Dismiss the keyboard before the page goes away, so no focused field outlives its route.
    FocusManager.instance.primaryFocus?.unfocus();
    final title = _title.text.trim();
    if (title.isEmpty) {
      Toast.warning('Add a title before saving');
      return;
    }
    setState(() => _saving = true);
    final actions = ref.read(postActionsProvider(widget.channelId));
    try {
      if (_isEdit) {
        await actions.update(
          widget.postId!,
          title: title,
          caption: _caption.text,
          status: _status,
          mediaId: _media?.id,
        );
        Toast.success('Post updated');
        if (mounted) {
          context.canPop() ? context.pop() : context.go('/channels/${widget.channelId}/posts/${widget.postId}');
        }
      } else {
        final post = await actions.create(title: title, caption: _caption.text, status: _status, mediaId: _media?.id);
        Toast.success('Post created');
        if (mounted) {
          // Close the form, then open the new post over the channel page it was started from.
          final router = GoRouter.of(context);
          if (router.canPop()) {
            router.pop();
          }
          router.push('/channels/${widget.channelId}/posts/${post.id}');
        }
      }
    } catch (_) {
      Toast.error('Failed to save post');
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _goBack() => context.canPop() ? context.pop() : context.go('/channels/${widget.channelId}');

  @override
  Widget build(BuildContext context) {
    final existing = _isEdit ? ref.watch(postProvider((channelId: widget.channelId, postId: widget.postId!))) : null;
    final canSave = _title.text.trim().isNotEmpty && !_saving;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel', onPressed: _goBack),
        title: Text(_isEdit ? 'Edit post' : 'New post'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: canSave ? _save : null,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'Save changes' : 'Create post'),
            ),
          ),
        ],
      ),
      body: existing != null && existing.hasError && !_loaded
          ? ErrorView(
              message: 'Could not load this post',
              onRetry: () => ref.invalidate(postProvider((channelId: widget.channelId, postId: widget.postId!))),
            )
          : existing != null && !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  _isEdit
                      ? 'Update the image, caption, and status.'
                      : 'Add media and write the caption you will publish.',
                  style: AppText.secondary,
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Image', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        MediaUploader(value: _media, onChanged: (media) => setState(() => _media = media)),
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
                        TextField(
                          controller: _title,
                          maxLength: 200,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          decoration: const InputDecoration(hintText: 'What is this post about?'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Caption', style: AppText.secondary),
                            Text('${_caption.text.length} characters', style: AppText.secondary),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _caption,
                          minLines: 8,
                          maxLines: 16,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            hintText: 'Write the caption you will copy to social accounts...',
                          ),
                        ),
                        const SizedBox(height: 24),
                        PostStatusPicker(status: _status, onChanged: (value) => setState(() => _status = value)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
