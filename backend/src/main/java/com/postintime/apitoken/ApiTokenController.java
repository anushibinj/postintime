package com.postintime.apitoken;

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
@RequestMapping("/api/v1/api-tokens")
public class ApiTokenController {

    private final ApiTokenService apiTokenService;

    public ApiTokenController(ApiTokenService apiTokenService) {
        this.apiTokenService = apiTokenService;
    }

    @GetMapping
    public List<ApiTokenResponse> listTokens() {
        return apiTokenService.listTokens();
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiTokenResponse createToken(@Valid @RequestBody CreateApiTokenRequest request) {
        return apiTokenService.createToken(request);
    }

    @PatchMapping("/{tokenId}")
    public ApiTokenResponse updateToken(@PathVariable UUID tokenId,
                                        @Valid @RequestBody UpdateApiTokenRequest request) {
        return apiTokenService.updateToken(tokenId, request);
    }

    @PostMapping("/{tokenId}/refresh")
    public ApiTokenResponse refreshToken(@PathVariable UUID tokenId,
                                         @RequestBody(required = false) RefreshApiTokenRequest request) {
        return apiTokenService.refreshToken(tokenId, request);
    }

    @DeleteMapping("/{tokenId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void deleteToken(@PathVariable UUID tokenId) {
        apiTokenService.deleteToken(tokenId);
    }
}
