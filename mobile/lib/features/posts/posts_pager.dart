import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../logic/post_list_params.dart';

/// Pager for the post list. Pages are zero-based, like the API.
class PostsPager extends StatelessWidget {
  const PostsPager({
    super.key,
    required this.page,
    required this.size,
    required this.totalItems,
    required this.onChange,
  });

  final int page;
  final int size;
  final int totalItems;
  final void Function(int page, int size) onChange;

  @override
  Widget build(BuildContext context) {
    if (totalItems <= 0) {
      return const SizedBox.shrink();
    }
    final totalPages = math.max(1, (totalItems / size).ceil());
    final first = page * size + 1;
    final last = math.min((page + 1) * size, totalItems);
    final sizes = {...pageSizeOptions, size}.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          Text('$first-$last of $totalItems posts', style: AppText.secondary),
          DropdownButton<int>(
            value: size,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: [for (final option in sizes) DropdownMenuItem(value: option, child: Text('$option / page'))],
            onChanged: (value) {
              if (value == null || value == size) {
                return;
              }
              // Stay on the same page when it still exists at the new size.
              final lastPage = math.max(0, (totalItems / value).ceil() - 1);
              onChange(math.min(page, lastPage), value);
            },
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: page > 0 ? () => onChange(page - 1, size) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${page + 1} / $totalPages'),
              IconButton(
                tooltip: 'Next page',
                onPressed: page + 1 < totalPages ? () => onChange(page + 1, size) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
