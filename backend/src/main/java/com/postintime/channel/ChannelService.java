package com.postintime.channel;

import com.postintime.common.error.BusinessException;
import com.postintime.common.error.ResourceNotFoundException;
import com.postintime.common.security.CurrentUserService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class ChannelService {

    private final ChannelRepository channelRepository;
    private final CurrentUserService currentUserService;

    public ChannelService(ChannelRepository channelRepository, CurrentUserService currentUserService) {
        this.channelRepository = channelRepository;
        this.currentUserService = currentUserService;
    }

    @Transactional(readOnly = true)
    public List<ChannelResponse> listChannels() {
        UUID userId = currentUserService.getCurrentUserId();
        return channelRepository.findByUserIdOrderByNameAsc(userId).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public ChannelResponse getChannel(UUID channelId) {
        return toResponse(getOwnedChannel(channelId));
    }

    @Transactional
    public ChannelResponse createChannel(CreateChannelRequest request) {
        UUID userId = currentUserService.getCurrentUserId();
        String slug = request.slug().toLowerCase();
        if (channelRepository.existsByUserIdAndSlug(userId, slug)) {
            throw new BusinessException("VALIDATION_ERROR", "Channel slug already exists.");
        }
        Channel channel = new Channel();
        channel.setUser(currentUserService.getCurrentUser().getUser());
        channel.setName(request.name());
        channel.setSlug(slug);
        channel.setDescription(request.description());
        return toResponse(channelRepository.save(channel));
    }

    @Transactional
    public ChannelResponse updateChannel(UUID channelId, UpdateChannelRequest request) {
        Channel channel = getOwnedChannel(channelId);
        if (request.name() != null) {
            channel.setName(request.name());
        }
        if (request.slug() != null) {
            String slug = request.slug().toLowerCase();
            if (!slug.equals(channel.getSlug())
                    && channelRepository.existsByUserIdAndSlug(channel.getUser().getId(), slug)) {
                throw new BusinessException("VALIDATION_ERROR", "Channel slug already exists.");
            }
            channel.setSlug(slug);
        }
        if (request.description() != null) {
            channel.setDescription(request.description());
        }
        if (request.enabled() != null) {
            channel.setEnabled(request.enabled());
        }
        return toResponse(channelRepository.save(channel));
    }

    @Transactional
    public void deleteChannel(UUID channelId) {
        Channel channel = getOwnedChannel(channelId);
        channelRepository.delete(channel);
    }

    public Channel getOwnedChannel(UUID channelId) {
        UUID userId = currentUserService.getCurrentUserId();
        return channelRepository.findByIdAndUserId(channelId, userId)
                .orElseThrow(() -> new ResourceNotFoundException("Channel not found."));
    }

    public void ensureChannelEnabled(Channel channel) {
        if (!channel.isEnabled()) {
            throw new BusinessException("CHANNEL_DISABLED", "Channel is disabled.");
        }
    }

    private ChannelResponse toResponse(Channel channel) {
        return new ChannelResponse(
                channel.getId(),
                channel.getName(),
                channel.getSlug(),
                channel.getDescription(),
                channel.isEnabled(),
                channelRepository.countPostsByChannelId(channel.getId()),
                channelRepository.countSocialAccountsByChannelId(channel.getId()),
                channel.getCreatedAt(),
                channel.getUpdatedAt()
        );
    }
}
