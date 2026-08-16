package com.postintime.social;

import com.postintime.channel.Channel;
import com.postintime.channel.ChannelService;
import com.postintime.common.error.BusinessException;
import com.postintime.common.error.ResourceNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
public class SocialAccountService {

    private final SocialAccountRepository socialAccountRepository;
    private final ChannelService channelService;

    public SocialAccountService(SocialAccountRepository socialAccountRepository,
                                ChannelService channelService) {
        this.socialAccountRepository = socialAccountRepository;
        this.channelService = channelService;
    }

    @Transactional(readOnly = true)
    public List<SocialAccountResponse> listAccounts(UUID channelId) {
        channelService.getOwnedChannel(channelId);
        return socialAccountRepository.findByChannelIdOrderByNameAsc(channelId).stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional
    public SocialAccountResponse createAccount(UUID channelId, CreateSocialAccountRequest request) {
        Channel channel = channelService.getOwnedChannel(channelId);
        channelService.ensureChannelEnabled(channel);
        SocialAccount account = new SocialAccount();
        account.setChannel(channel);
        account.setPlatform(parsePlatform(request.platform()));
        account.setName(request.name());
        account.setProfileUrl(request.profileUrl());
        account.setPostingMode(parsePostingMode(request.postingMode()));
        return toResponse(socialAccountRepository.save(account));
    }

    @Transactional
    public SocialAccountResponse updateAccount(UUID channelId, UUID accountId,
                                               UpdateSocialAccountRequest request) {
        SocialAccount account = getOwnedAccount(channelId, accountId);
        if (request.platform() != null) {
            account.setPlatform(parsePlatform(request.platform()));
        }
        if (request.name() != null) {
            account.setName(request.name());
        }
        if (request.profileUrl() != null) {
            account.setProfileUrl(request.profileUrl());
        }
        if (request.postingMode() != null) {
            account.setPostingMode(parsePostingMode(request.postingMode()));
        }
        if (request.enabled() != null) {
            account.setEnabled(request.enabled());
        }
        return toResponse(socialAccountRepository.save(account));
    }

    @Transactional
    public void deleteAccount(UUID channelId, UUID accountId) {
        socialAccountRepository.delete(getOwnedAccount(channelId, accountId));
    }

    @Transactional
    public SocialAccountResponse enableAccount(UUID channelId, UUID accountId) {
        SocialAccount account = getOwnedAccount(channelId, accountId);
        account.setEnabled(true);
        return toResponse(socialAccountRepository.save(account));
    }

    @Transactional
    public SocialAccountResponse disableAccount(UUID channelId, UUID accountId) {
        SocialAccount account = getOwnedAccount(channelId, accountId);
        account.setEnabled(false);
        return toResponse(socialAccountRepository.save(account));
    }

    public SocialAccount getOwnedAccount(UUID channelId, UUID accountId) {
        channelService.getOwnedChannel(channelId);
        return socialAccountRepository.findByIdAndChannelId(accountId, channelId)
                .orElseThrow(() -> new ResourceNotFoundException("Social account not found."));
    }

    public void ensureAccountEnabled(SocialAccount account) {
        if (!account.isEnabled()) {
            throw new BusinessException("ACCOUNT_DISABLED", "Social account is disabled.");
        }
    }

    private SocialAccountResponse toResponse(SocialAccount account) {
        return new SocialAccountResponse(
                account.getId(),
                account.getPlatform().name().toLowerCase(),
                account.getName(),
                account.getProfileUrl(),
                account.getPostingMode().name().toLowerCase(),
                account.isEnabled(),
                account.getCreatedAt(),
                account.getUpdatedAt()
        );
    }

    private Platform parsePlatform(String platform) {
        try {
            return Platform.valueOf(platform.toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new BusinessException("VALIDATION_ERROR", "Invalid platform: " + platform);
        }
    }

    private PostingMode parsePostingMode(String mode) {
        if (mode == null || mode.isBlank()) {
            return PostingMode.MANUAL;
        }
        return PostingMode.valueOf(mode.toUpperCase());
    }
}
