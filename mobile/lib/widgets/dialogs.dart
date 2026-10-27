import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Asks the user to confirm an action; resolves to true only when they accept.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  String? content,
  String okText = 'OK',
  String cancelText = 'Cancel',
  bool danger = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: content == null ? null : Text(content),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(cancelText)),
        FilledButton(
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(okText),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A blocking error with a selectable message, for failures the user has to read (e.g. a webhook response).
Future<void> showErrorDialog(BuildContext context, {required String title, required String message}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.error, color: AppColors.danger),
      title: Text(title),
      content: SingleChildScrollView(child: SelectableText(message)),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
    ),
  );
}

/// Shows [builder] in a bottom sheet that grows with its content and lifts above the keyboard.
Future<T?> showFormSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    builder: builder,
  );
}

/// The frame shared by all form sheets: a title, scrollable [child] and Cancel / confirm buttons.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.okText,
    required this.onOk,
    this.loading = false,
    this.okEnabled = true,
    this.cancelText = 'Cancel',
  });

  final String title;
  final Widget child;
  final String okText;
  final VoidCallback onOk;
  final bool loading;
  final bool okEnabled;
  final String cancelText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            child,
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: loading ? null : () => Navigator.of(context).pop(), child: Text(cancelText)),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: loading || !okEnabled
                      ? null
                      : () {
                          // Close the keyboard first, so a sheet that pops itself leaves no focused field behind.
                          FocusManager.instance.primaryFocus?.unfocus();
                          onOk();
                        },
                  child: loading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(okText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
