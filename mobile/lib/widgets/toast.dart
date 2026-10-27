import 'dart:async';

import 'package:flutter/material.dart';

import '../app/navigator_keys.dart';
import '../app/theme.dart';

/// Short messages at the top of the screen, like Ant Design's global `message`.
///
/// They sit in the root navigator's overlay, above sheets and dialogs, and let touches through, so
/// they never hide a button.
class Toast {
  const Toast._();

  static OverlayEntry? _current;

  static void success(String message) => _show(message, AppColors.success, Icons.check_circle);
  static void error(String message) => _show(message, AppColors.danger, Icons.error);
  static void warning(String message) => _show(message, AppColors.warning, Icons.warning_amber_rounded);
  static void info(String message) => _show(message, AppColors.primary, Icons.info);

  static void _show(String message, Color color, IconData icon) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      return;
    }
    _dismiss();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastView(
        key: ValueKey(message),
        message: message,
        color: color,
        icon: icon,
        onDone: () {
          if (_current == entry) {
            _current = null;
          }
          entry.remove();
          entry.dispose();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
  }

  static void _dismiss() {
    final current = _current;
    _current = null;
    if (current != null && current.mounted) {
      current.remove();
      current.dispose();
    }
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({super.key, required this.message, required this.color, required this.icon, required this.onDone});

  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onDone;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> {
  static const _visibleFor = Duration(seconds: 3);
  static const _fade = Duration(milliseconds: 200);

  bool _shown = false;
  Timer? _hideTimer;
  Timer? _removeTimer;

  @override
  void initState() {
    super.initState();
    // Fade in on the next frame, hide after a few seconds, then remove once the fade-out is done.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _shown = true);
      }
    });
    _hideTimer = Timer(_visibleFor, () {
      if (!mounted) {
        return;
      }
      setState(() => _shown = false);
      _removeTimer = Timer(_fade, widget.onDone);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _removeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 12,
      left: 16,
      right: 16,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: _shown ? 1 : 0,
          duration: _fade,
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.white,
              elevation: 6,
              shadowColor: Colors.black45,
              borderRadius: BorderRadius.circular(kRadius),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: widget.color, size: 20),
                      const SizedBox(width: 10),
                      Flexible(child: Text(widget.message)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
