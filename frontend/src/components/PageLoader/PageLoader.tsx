import { Spin } from 'antd';

export function PageLoader() {
  return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 120, width: '100%' }}>
      <Spin size="large" />
    </div>
  );
}

export default PageLoader;
