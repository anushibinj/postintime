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
        applyPostingSettings(
                account,
                request.postingMode(),
                request.webhookUrl(),
                request.webhookAuthType(),
                request.webhookUsername(),
                request.webhookPassword(),
                true
        );
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
        if (request.enabled() != null) {
            account.setEnabled(request.enabled());
        }
        if (request.postingMode() != null
                || request.webhookUrl() != null
                || request.webhookAuthType() != null
                || request.webhookUsername() != null
                || request.webhookPassword() != null) {
            applyPostingSettings(
                    account,
                    request.postingMode() != null ? request.postingMode() : account.getPostingMode().name(),
                    request.webhookUrl() != null ? request.webhookUrl() : account.getWebhookUrl(),
                    request.webhookAuthType() != null
                            ? request.webhookAuthType()
                            : account.getWebhookAuthType().name(),
                    request.webhookUsername() != null ? request.webhookUsername() : account.getWebhookUsername(),
                    request.webhookPassword(),
                    false
            );
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

    private void applyPostingSettings(SocialAccount account,
                                      String postingModeValue,
                                      String webhookUrl,
                                      String webhookAuthTypeValue,
                                      String webhookUsername,
                                      String webhookPassword,
                                      boolean creating) {
        PostingMode postingMode = parsePostingMode(postingModeValue);
        account.setPostingMode(postingMode);
        if (postingMode == PostingMode.MANUAL) {
            account.setWebhookUrl(null);
            account.setWebhookAuthType(WebhookAuthType.NONE);
            account.setWebhookUsername(null);
            account.setWebhookPassword(null);
            return;
        }

        String url = webhookUrl == null ? null : webhookUrl.trim();
        if (url == null || url.isBlank()) {
            throw new BusinessException("VALIDATION_ERROR", "Webhook URL is required for webhook posting.");
        }
        if (!url.startsWith("http://") && !url.startsWith("https://")) {
            throw new BusinessException("VALIDATION_ERROR", "Webhook URL must start with http:// or https://.");
        }
        account.setWebhookUrl(url);

        WebhookAuthType authType = parseWebhookAuthType(webhookAuthTypeValue);
        account.setWebhookAuthType(authType);
        if (authType == WebhookAuthType.NONE) {
            account.setWebhookUsername(null);
            account.setWebhookPassword(null);
            return;
        }

        String username = webhookUsername == null ? null : webhookUsername.trim();
        if (username == null || username.isBlank()) {
            throw new BusinessException("VALIDATION_ERROR", "Basic auth username is required.");
        }
        account.setWebhookUsername(username);
        if (webhookPassword != null && !webhookPassword.isBlank()) {
            account.setWebhookPassword(webhookPassword);
        } else if (creating || account.getWebhookPassword() == null || account.getWebhookPassword().isBlank()) {
            throw new BusinessException("VALIDATION_ERROR", "Basic auth password is required.");
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
                account.getWebhookUrl(),
                account.getWebhookAuthType().name().toLowerCase(),
                account.getWebhookUsername(),
                account.getWebhookPassword() != null && !account.getWebhookPassword().isBlank(),
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
        try {
            String value = mode.toUpperCase();
            if ("API".equals(value)) {
                return PostingMode.WEBHOOK;
            }
            return PostingMode.valueOf(value);
        } catch (IllegalArgumentException ex) {
            throw new BusinessException("VALIDATION_ERROR", "Invalid posting mode. Use manual or webhook.");
        }
    }

    private WebhookAuthType parseWebhookAuthType(String type) {
        if (type == null || type.isBlank()) {
            return WebhookAuthType.NONE;
        }
        try {
            return WebhookAuthType.valueOf(type.toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new BusinessException("VALIDATION_ERROR", "Invalid webhook auth type. Use none or basic.");
        }
    }
}
