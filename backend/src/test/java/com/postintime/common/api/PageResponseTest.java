package com.postintime.common.api;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;

class PageResponseTest {

    @Test
    void ofComputesTotalPagesAndNavigationFlags() {
        PageResponse<String> first = PageResponse.of(List.of("a", "b"), 0, 2, 5);
        assertThat(first.totalPages()).isEqualTo(3);
        assertThat(first.hasNext()).isTrue();
        assertThat(first.hasPrevious()).isFalse();

        PageResponse<String> last = PageResponse.of(List.of("e"), 2, 2, 5);
        assertThat(last.hasNext()).isFalse();
        assertThat(last.hasPrevious()).isTrue();
    }
}
