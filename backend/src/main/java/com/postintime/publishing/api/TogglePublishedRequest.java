package com.postintime.publishing.api;

import jakarta.validation.constraints.NotNull;

import java.util.UUID;

public record TogglePublishedRequest(
        @NotNull UUID socialAccountId
) {
}
