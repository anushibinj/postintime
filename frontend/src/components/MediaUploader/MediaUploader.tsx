import { useState } from 'react';
import { Button, Spin, Upload, message } from 'antd';
import { ImagePlus, Trash2 } from 'lucide-react';
import { uploadMedia } from '../../api/media';
import type { MediaInfo } from '../../types';

interface MediaUploaderProps {
  value?: MediaInfo | null;
  onChange?: (media: MediaInfo | null) => void;
}

export function MediaUploader({ value, onChange }: MediaUploaderProps) {
  const [uploading, setUploading] = useState(false);

  const handleUpload = async (
    file: File,
    successMessage: string,
    onSuccess?: (body: MediaInfo) => void,
    onError?: (error: Error) => void,
  ) => {
    setUploading(true);
    try {
      const media = await uploadMedia(file);
      onChange?.(media);
      onSuccess?.(media);
      message.success(successMessage);
    } catch {
      const error = new Error('Upload failed');
      onError?.(error);
      message.error('Upload failed');
    } finally {
      setUploading(false);
    }
  };

  return (
    <div style={{ position: 'relative' }}>
      {value?.url ? (
        <div>
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
                opacity: uploading ? 0.45 : 1,
              }}
            />
            {uploading && (
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  borderRadius: 12,
                }}
              >
                <Spin tip="Uploading…" size="large" />
              </div>
            )}
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
            <Upload
              accept="image/*"
              showUploadList={false}
              disabled={uploading}
              customRequest={({ file, onSuccess, onError }) => {
                void handleUpload(
                  file as File,
                  'Image replaced',
                  onSuccess as ((body: MediaInfo) => void) | undefined,
                  onError,
                );
              }}
            >
              <Button loading={uploading} disabled={uploading}>
                Replace image
              </Button>
            </Upload>
            <Button
              danger
              icon={<Trash2 size={16} />}
              disabled={uploading}
              onClick={() => onChange?.(null)}
            >
              Remove
            </Button>
          </div>
        </div>
      ) : (
        <Spin spinning={uploading} tip="Uploading…">
          <Upload.Dragger
            accept="image/*"
            showUploadList={false}
            disabled={uploading}
            style={{ padding: '48px 16px', borderRadius: 12 }}
            customRequest={({ file, onSuccess, onError }) => {
              void handleUpload(
                file as File,
                'Image uploaded',
                onSuccess as ((body: MediaInfo) => void) | undefined,
                onError,
              );
            }}
          >
            <p className="ant-upload-drag-icon" style={{ marginBottom: 8 }}>
              <ImagePlus size={40} color="#1677ff" />
            </p>
            <p style={{ fontSize: 16, fontWeight: 500, marginBottom: 4 }}>Add an image</p>
            <p style={{ color: '#8c8c8c', margin: 0 }}>
              {uploading ? 'Uploading…' : 'Drag and drop, or click to browse'}
            </p>
          </Upload.Dragger>
        </Spin>
      )}
    </div>
  );
}

export default MediaUploader;
