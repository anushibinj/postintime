import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/models.dart';

/// Draft / Ready control with the explanation of what each means. Read-only when [onChanged] is null.
class PostStatusPicker extends StatelessWidget {
  const PostStatusPicker({super.key, required this.status, this.onChanged});

  final PostStatus status;
  final ValueChanged<PostStatus>? onChanged;

  @override
  Widget build(BuildContext context) {
    final control = SegmentedButton<PostStatus>(
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(value: PostStatus.draft, label: Text('Draft')),
        ButtonSegment(value: PostStatus.ready, label: Text('Ready')),
      ],
      selected: {status},
      onSelectionChanged: (selection) => onChanged?.call(selection.first),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status', style: AppText.secondary),
        const SizedBox(height: 8),
        // Read-only mode keeps the normal look but ignores taps.
        onChanged == null ? IgnorePointer(child: control) : control,
        const SizedBox(height: 8),
        Text(
          status == PostStatus.draft
              ? 'Keep working on this post. Drafts are not treated as ready to publish.'
              : 'This post is ready. You can add publishing targets and mark them published.',
          style: AppText.secondary,
        ),
      ],
    );
  }
}
