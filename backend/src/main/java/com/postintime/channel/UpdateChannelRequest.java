package com.postintime.channel;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.Size;

public record UpdateChannelRequest(
        @Size(max = 100) String name,
        @Size(max = 120) String slug,
        @Size(max = 2000) String description,
        Boolean enabled,
        Boolean autopublishEnabled,
        @Min(0) @Max(100) Integer autopublishThreshold
) {
}
