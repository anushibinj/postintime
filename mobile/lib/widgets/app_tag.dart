import 'package:flutter/material.dart';

enum TagTone { neutral, processing, success, warning, error, green }

/// A small coloured label, like Ant Design's `Tag`.
class AppTag extends StatelessWidget {
  const AppTag(this.label, {super.key, this.tone = TagTone.neutral, this.icon});

  final String label;
  final TagTone tone;
  final IconData? icon;

  static const _palette = {
    TagTone.neutral: (Color(0xFFFAFAFA), Color(0xFFD9D9D9), Color(0xDD000000)),
    TagTone.processing: (Color(0xFFE6F4FF), Color(0xFF91CAFF), Color(0xFF1677FF)),
    TagTone.success: (Color(0xFFF6FFED), Color(0xFFB7EB8F), Color(0xFF52C41A)),
    TagTone.green: (Color(0xFFF6FFED), Color(0xFFB7EB8F), Color(0xFF52C41A)),
    TagTone.warning: (Color(0xFFFFFBE6), Color(0xFFFFE58F), Color(0xFFFAAD14)),
    TagTone.error: (Color(0xFFFFF2F0), Color(0xFFFFCCC7), Color(0xFFFF4D4F)),
  };

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground) = _palette[tone]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: foreground), const SizedBox(width: 4)],
          Flexible(
            child: Text(label, style: TextStyle(fontSize: 12, height: 1.6, color: foreground)),
          ),
        ],
      ),
    );
  }
}
