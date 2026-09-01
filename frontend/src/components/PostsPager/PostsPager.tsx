import { Pagination } from 'antd';
import { PAGE_SIZE_OPTIONS } from '../../hooks/postListParams';

export function PostsPager({
  page,
  size,
  totalItems,
  onChange,
}: {
  page: number;
  size: number;
  totalItems: number;
  onChange: (page: number, size: number) => void;
}) {
  if (totalItems <= 0) {
    return null;
  }

  return (
    <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 16 }}>
      <Pagination
        current={page + 1}
        pageSize={size}
        total={totalItems}
        showSizeChanger
        pageSizeOptions={PAGE_SIZE_OPTIONS}
        showTotal={(total, range) => `${range[0]}-${range[1]} of ${total} posts`}
        onChange={(current, pageSize) => onChange(current - 1, pageSize)}
      />
    </div>
  );
}

export default PostsPager;
