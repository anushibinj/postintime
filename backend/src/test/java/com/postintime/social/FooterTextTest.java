package com.postintime.social;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class FooterTextTest {

    @Test
    void normalizeDefaultsToEmptyAndCollapsesLineEndings() {
        assertThat(FooterText.normalize(null)).isEmpty();
        assertThat(FooterText.normalize("  a\r\nb\rc  ")).isEqualTo("a\nb\nc");
    }

    @Test
    void everySupportedPlatformUsesLf() {
        for (Platform platform : Platform.values()) {
            assertThat(FooterText.newlineFor(platform)).isEqualTo("\n");
        }
    }

    @Test
    void appendsFooterAfterABlankLine() {
        assertThat(FooterText.appendTo("Hello", "Follow me\nonX", Platform.LINKEDIN))
                .isEqualTo("Hello\n\nFollow me\nonX");
    }

    @Test
    void leavesCaptionUntouchedWithoutFooter() {
        assertThat(FooterText.appendTo("Hello", "", Platform.WHATSAPP)).isEqualTo("Hello");
        assertThat(FooterText.appendTo(null, null, Platform.WHATSAPP)).isEmpty();
        assertThat(FooterText.appendTo("", "Footer", Platform.X)).isEqualTo("Footer");
    }
}
