package com.postintime.publishing.api;

import jakarta.validation.constraints.NotEmpty;

import java.util.List;
import java.util.UUID;

public record CreateTargetsRequest(@NotEmpty List<UUID> socialAccountIds) {
}
