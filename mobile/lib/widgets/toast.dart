import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Lets toasts show without a BuildContext, like Ant Design's global `message`.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class Toast {
  const Toast._();

  static void success(String message) => _show(message, AppColors.success, Icons.check_circle);
  static void error(String message) => _show(message, AppColors.danger, Icons.error);
  static void warning(String message) => _show(message, AppColors.warning, Icons.warning_amber_rounded);
  static void info(String message) => _show(message, AppColors.primary, Icons.info);

  static void _show(String message, Color color, IconData icon) {
    final messenger = scaffoldMessengerKey.currentState;
    if (messenger == null) {
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
