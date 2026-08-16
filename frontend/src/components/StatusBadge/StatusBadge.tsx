import { Tag } from 'antd';
import type { TargetStatus } from '../../types';

const STATUS_CONFIG: Record<TargetStatus, { color: string; label: string }> = {
  pending: { color: 'default', label: 'Pending' },
  publishing: { color: 'processing', label: 'Publishing' },
  published: { color: 'success', label: 'Published' },
  failed: { color: 'error', label: 'Failed' },
  skipped: { color: 'warning', label: 'Skipped' },
};

export function StatusBadge({ status }: { status: TargetStatus }) {
  const config = STATUS_CONFIG[status];
  return <Tag color={config.color}>{config.label}</Tag>;
}
