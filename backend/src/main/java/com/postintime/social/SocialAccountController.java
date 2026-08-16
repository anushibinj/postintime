package com.postintime.social;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/v1/channels/{channelId}/social-accounts")
public class SocialAccountController {

    private final SocialAccountService socialAccountService;

    public SocialAccountController(SocialAccountService socialAccountService) {
        this.socialAccountService = socialAccountService;
    }

    @GetMapping
    public List<SocialAccountResponse> listAccounts(@PathVariable UUID channelId) {
        return socialAccountService.listAccounts(channelId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public SocialAccountResponse createAccount(@PathVariable UUID channelId,
                                               @Valid @RequestBody CreateSocialAccountRequest request) {
        return socialAccountService.createAccount(channelId, request);
    }

    @PatchMapping("/{accountId}")
    public SocialAccountResponse updateAccount(@PathVariable UUID channelId,
                                               @PathVariable UUID accountId,
                                               @Valid @RequestBody UpdateSocialAccountRequest request) {
        return socialAccountService.updateAccount(channelId, accountId, request);
    }

    @DeleteMapping("/{accountId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteAccount(@PathVariable UUID channelId, @PathVariable UUID accountId) {
        socialAccountService.deleteAccount(channelId, accountId);
    }

    @PostMapping("/{accountId}/enable")
    public SocialAccountResponse enableAccount(@PathVariable UUID channelId,
                                               @PathVariable UUID accountId) {
        return socialAccountService.enableAccount(channelId, accountId);
    }

    @PostMapping("/{accountId}/disable")
    public SocialAccountResponse disableAccount(@PathVariable UUID channelId,
                                                @PathVariable UUID accountId) {
        return socialAccountService.disableAccount(channelId, accountId);
    }
}
