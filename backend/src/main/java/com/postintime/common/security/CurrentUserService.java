package com.postintime.common.security;

import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;

import java.util.UUID;

@Component
public class CurrentUserService {

    public UserPrincipal getCurrentUser() {
        Authentication authentication = SecurityContextHolder.getContext().getAuthentication();
        if (authentication == null || !(authentication.getPrincipal() instanceof UserPrincipal principal)) {
            throw new com.postintime.common.error.AccessDeniedException("Not authenticated");
        }
        return principal;
    }

    public UUID getCurrentUserId() {
        return getCurrentUser().getId();
    }
}
