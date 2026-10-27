import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../app/theme.dart';
import 'page_loader.dart';

/// Renders an [AsyncValue]: a spinner while loading, a retry prompt on failure, [data] otherwise.
/// A dead session shows nothing, since the router is already sending the user to sign in.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Keep showing the previous data while a refresh is in flight.
    if (value.hasValue && !value.hasError) {
      return data(value.requireValue);
    }
    if (value.hasError) {
      final error = value.error!;
      if (error is ApiException && error.isSessionExpired) {
        return const SizedBox.shrink();
      }
      return ErrorView(message: errorMessage(error, 'Could not load this page'), onRetry: onRetry);
    }
    return const PageLoader();
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
