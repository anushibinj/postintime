import 'package:flutter/material.dart';

import '../models/models.dart';
import 'app_tag.dart';

const _tones = {
  TargetStatus.pending: TagTone.neutral,
  TargetStatus.publishing: TagTone.processing,
  TargetStatus.published: TagTone.success,
  TargetStatus.failed: TagTone.error,
  TargetStatus.skipped: TagTone.warning,
};

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});

  final TargetStatus status;

  @override
  Widget build(BuildContext context) => AppTag(status.label, tone: _tones[status]!);
}
