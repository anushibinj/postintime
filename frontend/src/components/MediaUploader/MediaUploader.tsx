import { Upload, message } from 'antd';
import { Inbox } from 'lucide-react';
import { uploadMedia } from '../../api/media';
import type { MediaInfo } from '../../types';

interface MediaUploaderProps {
  value?: MediaInfo | null;
  onChange?: (media: MediaInfo | null) => void;
}

export function MediaUploader({ value, onChange }: MediaUploaderProps) {
  return (
    <div>
      {value?.url && (
        <img src={value.url} alt="Preview" style={{ maxWidth: '100%', maxHeight: 200, marginBottom: 16, borderRadius: 8 }} />
      )}
      <Upload.Dragger
        accept="image/*"
        showUploadList={false}
        customRequest={async ({ file, onSuccess, onError }) => {
          try {
            const media = await uploadMedia(file as File);
            onChange?.(media);
            onSuccess?.(media);
            message.success('Image uploaded');
          } catch {
            onError?.(new Error('Upload failed'));
            message.error('Upload failed');
          }
        }}
      >
        <p className="ant-upload-drag-icon"><Inbox size={32} /></p>
        <p>Drag image here or click to upload</p>
      </Upload.Dragger>
    </div>
  );
}
