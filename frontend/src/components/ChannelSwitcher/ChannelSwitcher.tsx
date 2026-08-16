import { Select } from 'antd';
import { useNavigate, useParams } from 'react-router-dom';
import { useChannels } from '../../hooks/useChannels';
import { useChannelContext } from '../../app/providers/ChannelProvider';

export function ChannelSwitcher() {
  const navigate = useNavigate();
  const { channelId } = useParams();
  const { data: channels = [] } = useChannels();
  const { selectedChannelId, setSelectedChannelId } = useChannelContext();

  const activeId = channelId || selectedChannelId || channels[0]?.id;

  return (
    <Select
      style={{ minWidth: 200 }}
      value={activeId}
      placeholder="Select channel"
      onChange={(id) => {
        setSelectedChannelId(id);
        navigate(`/channels/${id}/posts`);
      }}
      options={[
        ...channels.map((c) => ({ value: c.id, label: c.name })),
        { value: '__manage__', label: '──────────' },
        { value: '__manage_channels__', label: 'Manage Channels' },
      ]}
      onSelect={(value) => {
        if (value === '__manage_channels__') {
          navigate('/channels');
        }
      }}
    />
  );
}
