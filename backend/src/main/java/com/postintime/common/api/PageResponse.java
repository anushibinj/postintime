package com.postintime.common.api;

import java.util.List;

public record PageResponse<T>(
        List<T> items,
        int page,
        int size,
        long totalItems,
        int totalPages,
        boolean hasNext,
        boolean hasPrevious
) {
    public static <T> PageResponse<T> of(List<T> items, int page, int size, long totalItems) {
        int totalPages = size == 0 ? 0 : (int) Math.ceil((double) totalItems / size);
        return new PageResponse<>(
                items,
                page,
                size,
                totalItems,
                totalPages,
                page < totalPages - 1,
                page > 0
        );
    }
}
