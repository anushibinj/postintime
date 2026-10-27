import 'package:flutter/material.dart';

enum AlertType { info, error }

/// A bordered notice with an icon, like Ant Design's `Alert`.
class AppAlert extends StatelessWidget {
  const AppAlert({super.key, required this.type, required this.title, this.description});

  final AlertType type;
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final isError = type == AlertType.error;
    final background = isError ? const Color(0xFFFFF2F0) : const Color(0xFFE6F4FF);
    final border = isError ? const Color(0xFFFFCCC7) : const Color(0xFF91CAFF);
    final accent = isError ? const Color(0xFFFF4D4F) : const Color(0xFF1677FF);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(isError ? Icons.cancel : Icons.info, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Text(description!, style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
