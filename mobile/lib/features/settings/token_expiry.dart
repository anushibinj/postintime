import 'package:intl/intl.dart';

class ExpiryOption {
  const ExpiryOption(this.value, this.label);

  final String value;
  final String label;
}

const List<ExpiryOption> expiryOptions = [
  ExpiryOption('never', 'Never expires'),
  ExpiryOption('7', '7 days'),
  ExpiryOption('30', '30 days'),
  ExpiryOption('90', '90 days'),
  ExpiryOption('365', '1 year'),
];

/// The expiry timestamp for a preset, or null for "never expires".
DateTime? expiryFromPreset(String preset, {DateTime? now}) {
  if (preset == 'never') {
    return null;
  }
  final days = int.parse(preset);
  return (now ?? DateTime.now()).add(Duration(days: days));
}

String formatExpiry(DateTime? expiresAt) {
  if (expiresAt == null) {
    return 'Never expires';
  }
  return 'Expires ${DateFormat('MMM d, yyyy', 'en_US').format(expiresAt.toLocal())}';
}
