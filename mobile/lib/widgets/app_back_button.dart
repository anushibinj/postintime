import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Pops the current page, or goes to [fallback] when the page was opened directly (a deep link).
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, required this.fallback});

  final String fallback;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.canPop() ? context.pop() : context.go(fallback),
    );
  }
}
