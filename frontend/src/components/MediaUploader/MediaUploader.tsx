import { Button, Upload, message } from 'antd';
import { ImagePlus, Trash2 } from 'lucide-react';
import { uploadMedia } from '../../api/media';
import type { MediaInfo } from '../../types';

interface MediaUploaderProps {
  value?: MediaInfo | null;
  onChange?: (media: MediaInfo | null) => void;
}

export function MediaUploader({ value, onChange }: MediaUploaderProps) {
  return (
    <div>
      {value?.url ? (
        <div style={{ position: 'relative' }}>
          <img
            src={value.url}
            alt="Preview"
            style={{
              width: '100%',
              maxHeight: 420,
              objectFit: 'contain',
              background: '#fafafa',
              borderRadius: 12,
              border: '1px solid #f0f0f0',
              display: 'block',
            }}
          />
          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <Upload
              accept="image/*"
              showUploadList={false}
              customRequest={async ({ file, onSuccess, onError }) => {
                try {
                  const media = await uploadMedia(file as File);
                  onChange?.(media);
                  onSuccess?.(media);
                  message.success('Image replaced');
                } catch {
                  onError?.(new Error('Upload failed'));
                  message.error('Upload failed');
                }
              }}
            >
              <Button>Replace image</Button>
            </Upload>
            <Button danger icon={<Trash2 size={16} />} onClick={() => onChange?.(null)}>
              Remove
            </Button>
          </div>
        </div>
      ) : (
        <Upload.Dragger
          accept="image/*"
          showUploadList={false}
          style={{ padding: '48px 16px', borderRadius: 12 }}
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
          <p className="ant-upload-drag-icon" style={{ marginBottom: 8 }}>
            <ImagePlus size={40} color="#1677ff" />
          </p>
          <p style={{ fontSize: 16, fontWeight: 500, marginBottom: 4 }}>Add an image</p>
          <p style={{ color: '#8c8c8c', margin: 0 }}>Drag and drop, or click to browse</p>
        </Upload.Dragger>
      )}
    </div>
  );
}
