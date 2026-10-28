import 'package:flutter/material.dart';

import '../app/theme.dart';

enum AsyncButtonKind { filled, outlined, text }

/// A button that shows a spinner and ignores taps while its async [onPressed] is running.
class AsyncButton extends StatefulWidget {
  const AsyncButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.kind = AsyncButtonKind.filled,
    this.danger = false,
    this.compact = false,
  });

  final Future<void> Function()? onPressed;
  final String label;
  final IconData? icon;
  final AsyncButtonKind kind;
  final bool danger;
  final bool compact;

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _busy = false;

  Future<void> _run() async {
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed == null || _busy ? null : _run;
    final icon = _busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : (widget.icon == null ? null : Icon(widget.icon, size: 18));
    final label = Text(widget.label);
    final visual = widget.compact ? VisualDensity.compact : null;
    final danger = widget.danger ? AppColors.danger : null;

    switch (widget.kind) {
      case AsyncButtonKind.filled:
        final style = FilledButton.styleFrom(backgroundColor: danger, visualDensity: visual);
        return icon == null
            ? FilledButton(style: style, onPressed: onPressed, child: label)
            : FilledButton.icon(style: style, onPressed: onPressed, icon: icon, label: label);
      case AsyncButtonKind.outlined:
        final style = OutlinedButton.styleFrom(
          foregroundColor: danger,
          visualDensity: visual,
          side: danger == null ? null : const BorderSide(color: AppColors.danger),
        );
        return icon == null
            ? OutlinedButton(style: style, onPressed: onPressed, child: label)
            : OutlinedButton.icon(style: style, onPressed: onPressed, icon: icon, label: label);
      case AsyncButtonKind.text:
        final style = TextButton.styleFrom(foregroundColor: danger, visualDensity: visual);
        return icon == null
            ? TextButton(style: style, onPressed: onPressed, child: label)
            : TextButton.icon(style: style, onPressed: onPressed, icon: icon, label: label);
    }
  }
}
