import 'package:flutter/material.dart';

import '../app/theme.dart';

/// A bordered panel whose body expands when the header is tapped, like Ant Design's `Collapse`.
/// Collapsed by default; [extra] sits in the header without toggling the panel.
class CollapsePanel extends StatefulWidget {
  const CollapsePanel({super.key, required this.header, required this.body, this.extra});

  final Widget header;
  final Widget body;
  final Widget? extra;

  @override
  State<CollapsePanel> createState() => _CollapsePanelState();
}

class _CollapsePanelState extends State<CollapsePanel> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.dashedBorder),
        borderRadius: BorderRadius.circular(kRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFFAFAFA),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _expanded = !_expanded),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                      child: Row(
                        children: [
                          Expanded(child: widget.header),
                          const SizedBox(width: 4),
                          AnimatedRotation(
                            turns: _expanded ? 0.25 : 0,
                            duration: const Duration(milliseconds: 150),
                            child: const Icon(Icons.chevron_right, size: 20, color: AppColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.extra != null) Padding(padding: const EdgeInsets.only(right: 8), child: widget.extra),
              ],
            ),
          ),
          if (_expanded) ...[
            const Divider(),
            Padding(padding: const EdgeInsets.all(12), child: widget.body),
          ],
        ],
      ),
    );
  }
}
