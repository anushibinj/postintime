package com.postintime.common.api;

public record ApiErrorDetail(
        String field,
        String code,
        String message
) {
}
