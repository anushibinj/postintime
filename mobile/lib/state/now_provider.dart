import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Current time, refreshed every 30 seconds so relative labels ("in 5 min") stay fresh.
final nowProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

/// Convenience for widgets: the latest tick, or the current time before the first one arrives.
DateTime currentNow(WidgetRef ref) => ref.watch(nowProvider).value ?? DateTime.now();
