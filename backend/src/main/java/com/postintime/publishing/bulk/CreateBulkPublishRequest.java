package com.postintime.publishing.bulk;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;
import java.util.UUID;

/**
 * @param postIds          posts to publish, in publishing order
 * @param intervalMinutes  minutes between posts; 5 to 30 in steps of 5, defaults to 5
 * @param socialAccountIds enabled webhook accounts of the channel to post to; defaults to all of them
 */
public record CreateBulkPublishRequest(
        @NotEmpty @Size(max = 100) List<@NotNull UUID> postIds,
        Integer intervalMinutes,
        List<@NotNull UUID> socialAccountIds
) {
}
