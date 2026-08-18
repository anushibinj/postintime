package com.postintime.apitoken;

import com.postintime.common.error.BusinessException;
import com.postintime.common.error.ResourceNotFoundException;
import com.postintime.common.security.CurrentUserService;
import com.postintime.user.User;
import com.postintime.user.UserRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Service
public class ApiTokenService {

    private final ApiTokenRepository apiTokenRepository;
    private final CurrentUserService currentUserService;
    private final UserRepository userRepository;

    public ApiTokenService(ApiTokenRepository apiTokenRepository,
                           CurrentUserService currentUserService,
                           UserRepository userRepository) {
        this.apiTokenRepository = apiTokenRepository;
        this.currentUserService = currentUserService;
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public List<ApiTokenResponse> listTokens() {
        UUID userId = currentUserService.getCurrentUserId();
        return apiTokenRepository.findByUserIdOrderByCreatedAtDesc(userId).stream()
                .map(ApiTokenResponse::withoutSecret)
                .toList();
    }

    @Transactional
    public ApiTokenResponse createToken(CreateApiTokenRequest request) {
        Instant expiresAt = validateExpiry(request.expiresAt());
        User user = userRepository.findById(currentUserService.getCurrentUserId())
                .orElseThrow(() -> new ResourceNotFoundException("User not found."));
        String rawToken = ApiTokenHasher.generateToken();
        ApiToken apiToken = new ApiToken();
        apiToken.setUser(user);
        apiToken.setName(request.name().trim());
        applySecret(apiToken, rawToken);
        apiToken.setExpiresAt(expiresAt);
        return ApiTokenResponse.withSecret(apiTokenRepository.save(apiToken), rawToken);
    }

    @Transactional
    public ApiTokenResponse updateToken(UUID tokenId, UpdateApiTokenRequest request) {
        ApiToken apiToken = getOwnedToken(tokenId);
        if (request.name() != null && !request.name().isBlank()) {
            apiToken.setName(request.name().trim());
        }
        if (Boolean.TRUE.equals(request.neverExpires())) {
            apiToken.setExpiresAt(null);
        } else if (request.expiresAt() != null) {
            apiToken.setExpiresAt(validateExpiry(request.expiresAt()));
        }
        return ApiTokenResponse.withoutSecret(apiTokenRepository.save(apiToken));
    }

    @Transactional
    public ApiTokenResponse refreshToken(UUID tokenId, RefreshApiTokenRequest request) {
        ApiToken apiToken = getOwnedToken(tokenId);
        if (request != null && Boolean.TRUE.equals(request.neverExpires())) {
            apiToken.setExpiresAt(null);
        } else if (request != null && request.expiresAt() != null) {
            apiToken.setExpiresAt(validateExpiry(request.expiresAt()));
        }
        String rawToken = ApiTokenHasher.generateToken();
        applySecret(apiToken, rawToken);
        return ApiTokenResponse.withSecret(apiTokenRepository.save(apiToken), rawToken);
    }

    @Transactional
    public void deleteToken(UUID tokenId) {
        ApiToken apiToken = getOwnedToken(tokenId);
        apiTokenRepository.delete(apiToken);
    }

    @Transactional
    public Optional<User> authenticate(String rawToken) {
        if (rawToken == null || !rawToken.startsWith(ApiTokenHasher.TOKEN_PREFIX)) {
            return Optional.empty();
        }
        return apiTokenRepository.findByTokenHash(ApiTokenHasher.hash(rawToken))
                .filter(token -> !token.isExpired())
                .filter(token -> token.getUser().isEnabled())
                .map(token -> {
                    token.setLastUsedAt(Instant.now());
                    return token.getUser();
                });
    }

    private ApiToken getOwnedToken(UUID tokenId) {
        return apiTokenRepository.findByIdAndUserId(tokenId, currentUserService.getCurrentUserId())
                .orElseThrow(() -> new ResourceNotFoundException("API token not found."));
    }

    private Instant validateExpiry(Instant expiresAt) {
        if (expiresAt == null) {
            return null;
        }
        if (!expiresAt.isAfter(Instant.now())) {
            throw new BusinessException("INVALID_STATE", "Expiry must be in the future, or omitted for no expiry.");
        }
        return expiresAt;
    }

    private void applySecret(ApiToken apiToken, String rawToken) {
        apiToken.setTokenPrefix(ApiTokenHasher.displayPrefix(rawToken));
        apiToken.setTokenHash(ApiTokenHasher.hash(rawToken));
    }
}
