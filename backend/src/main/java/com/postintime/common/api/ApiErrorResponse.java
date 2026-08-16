package com.postintime.common.api;

import java.util.List;

public record ApiErrorResponse(
        String timestamp,
        int status,
        String code,
        String message,
        List<ApiErrorDetail> details,
        String requestId
) {
}
